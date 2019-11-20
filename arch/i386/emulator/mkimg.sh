#!/bin/bash

set -e

function exitfv() {
  if findmnt --source $LOOPDEV >/dev/null 2>&1; then
    udisksctl unmount --block-device $LOOPDEV >/dev/null
  fi
  if [ -n "$LOOPDEV" ] && /usr/sbin/losetup $LOOPDEV >/dev/null 2>&1; then
    udisksctl loop-delete --block-device $LOOPDEV
  fi
  if [ -n "$TMPDIR" ]; then
     rm -r $TMPDIR
  fi
  if [ -n "$TMPA" ]; then
     rm $TMPA
  fi
  if [ -n "$TMPB" ]; then
     rm $TMPB
  fi
}

if [ $# -ne 5 ]; then
    echo usage >&2
    echo $(basename $0) hdimg mbr.bin boot.bin loader.bin kernel.elf >&2
    exit 1
fi

FILEFRAG=/usr/sbin/filefrag

trap exitfv EXIT

HDIMG=$1
MBRBIN=$2
BOOTBIN=$3
LOADERBIN=$4
KERNELELF=$5

HDCYLS=1023
HDHEADS=16
HDSECS=63
HDSECSIZE=512
HDSIZE=$((HDCYLS * HDHEADS * HDSECS))

# partition start and size in sectors
PSTART=2048
PSIZE=20480
PSTARTB=$((PSTART * HDSECSIZE))
PSIZEB=$((PSIZE * HDSECSIZE))

HDDEV=hda0
HDPATH=boot
LDRCFG=loader.cfg

# root for filesystem
TMPDIR=$(mktemp -d)
mkdir -p $TMPDIR/$HDPATH
cp $LOADERBIN $KERNELELF $TMPDIR/$HDPATH

TMPA=$(mktemp)
TMPB=$(mktemp)

$OBJDUMP -t ${LOADERBIN%.*}.elf >$TMPA
POS=$($AWK '$1 ~ /^[0-9a-fA-F]+$/ && $(NF) == "ldrcfgpath" {print $1}' $TMPA)
POS=$((0x$POS))
printf "%s\x00" $HDDEV:/$HDPATH/$LDRCFG | $DD of=$TMPDIR/$HDPATH/$(basename $LOADERBIN) bs=1 seek=$POS conv=notrunc iflag=fullblock 2>/dev/null

# create filesystem
$DD if=/dev/zero of=$HDIMG.ext2 bs=$HDSECSIZE seek=$PSIZE count=0 2>/dev/null
/usr/sbin/mkfs.ext2 -F -d $TMPDIR $HDIMG.ext2 >/dev/null 2>&1

# copy boot sector
$DD if=$BOOTBIN of=$HDIMG.ext2 conv=notrunc 2>/dev/null

# create HD image, with MBR code and MBR
cp $MBRBIN $HDIMG
$DD if=/dev/zero of=$HDIMG bs=$HDSECSIZE seek=$HDSIZE count=0 2>/dev/null
echo "n;p;1;$PSTART;+$PSIZE;a;w" | tr ';' '\n' | /usr/sbin/fdisk $HDIMG >/dev/null

# copy ext2 partition into Hd image
$DD if=$HDIMG.ext2 of=$HDIMG bs=512 seek=$PSTART conv=sparse,notrunc iflag=fullblock 2>/dev/null
rm $HDIMG.ext2

# mount new filesystem
LOOPDEV=$(udisksctl loop-setup --file $HDIMG --offset $PSTARTB --size $PSIZEB)
LOOPDEV=$(echo $LOOPDEV | sed -e 's/.* //;s/\.//')
MOUNTDIR=$(udisksctl mount --block-device $LOOPDEV)
MOUNTDIR=$(echo $MOUNTDIR | sed -e 's/.* //;s/\.//')

# create blocklist and write into the filesystem after boot sector
$FILEFRAG -b$HDSECSIZE -e $MOUNTDIR/boot/${LOADERBIN##*/} >$TMPA
$AWK 'BEGIN {
       FS="[:. ]+"
     }
     {
       sub("^[:. ]+", "", $0)
       if ($1 ~ /^[0-9]+$/) {
         for (i = $4 + '$PSTART'; i <= $5 + '$PSTART'; i ++) {
           printf("\\\\x%02x\\\\x%02x\\\\x%02x\\\\x%02x\n", and(i, 255), and(rshift(i, 8), 255), and(rshift(i, 16), 255), and(rshift(i, 24), 255))
         }
       }
     }' $TMPA >$TMPB
while read a; do
  echo -n -e "$a"
done <$TMPB >$TMPA
FSIZE=$(stat --printf="%s" $TMPA)
if [ -z "$FSIZE" ] || [ $FSIZE -gt $HDSECSIZE ]; then
  echo Boot loader  binary is too big. >&2
  exit 1
fi
$DD if=$TMPA of=$HDIMG bs=512 seek=$((PSTART + 1)) conv=notrunc iflag=fullblock 2>/dev/null

# write bootlist address into boot sector code
$OBJDUMP -t ${BOOTBIN%.*}.elf >$TMPA
POS=$($AWK '$1 ~ /^[0-9a-fA-F]+$/ && $(NF) == "ldrblk" {print $1}' $TMPA)
POS=$((0x$POS))
PSTARTV=$(printf "\\\\x%02x\\\\x%02x\\\\x%02x\\\\x%02x" $(((PSTART + 1) % 256)) $(((PSTART + 1) / 256 % 256)) $(((PSTART + 1) / 256 / 256 % 256)) $(((PSTART + 1) / 256 / 256 / 256 % 256)))
echo -n -e $PSTARTV | $DD of=$HDIMG bs=1 seek=$((PSTARTB + POS)) conv=notrunc iflag=fullblock 2>/dev/null
