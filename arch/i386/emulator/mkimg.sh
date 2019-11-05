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

if [ $# -ne 4 ]; then
    echo usage >&2
    echo $(basename $0) hdimg mbr.bin boot.bin loader.bin >&2
    exit 1
fi

FILEFRAG=/usr/sbin/filefrag

trap exitfv EXIT

HDIMG="$1"
MBRBIN="$2"
BOOTBIN="$3"
LOADERBIN="$4"

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

# root for filesystem
TMPDIR=$(mktemp -d)
mkdir $TMPDIR/boot
cp $LOADERBIN $TMPDIR/boot

# create filesystem
dd if=/dev/zero of=$HDIMG.ext2 bs=$HDSECSIZE seek=$PSIZE count=0 2>/dev/null
/usr/sbin/mkfs.ext2 -F -d $TMPDIR $HDIMG.ext2 >/dev/null 2>&1

# copy boot sector
dd if=$BOOTBIN of=$HDIMG.ext2 conv=notrunc 2>/dev/null

# create HD image, with MBR code and MBR
cp $MBRBIN $HDIMG
dd if=/dev/zero of=$HDIMG bs=$HDSECSIZE seek=$HDSIZE count=0 2>/dev/null
echo "n;p;1;$PSTART;+$PSIZE;a;w" | tr ';' '\n' | /usr/sbin/fdisk $HDIMG >/dev/null

# copy ext2 partition into Hd image
dd if=$HDIMG.ext2 of=$HDIMG bs=512 seek=$PSTART conv=sparse,notrunc iflag=fullblock 2>/dev/null
rm $HDIMG.ext2

# mount new filesystem
LOOPDEV=$(udisksctl loop-setup --file $HDIMG --offset $PSTARTB --size $PSIZEB)
LOOPDEV=$(echo $LOOPDEV | sed -e 's/.* //;s/\.//')
MOUNTDIR=$(udisksctl mount --block-device $LOOPDEV)
MOUNTDIR=$(echo $MOUNTDIR | sed -e 's/.* //;s/\.//')

# create blocklist and write into the filesystem after boot sector
TMPA=$(mktemp)
TMPB=$(mktemp)
$FILEFRAG -b$HDSECSIZE -e $MOUNTDIR/boot/${LOADERBIN##*/} >$TMPA
awk 'BEGIN {
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
dd if=$TMPA of=$HDIMG bs=512 seek=$((PSTART + 1)) conv=notrunc iflag=fullblock 2>/dev/null


# write bootlist address into boot sector code
i686-elf-objdump -t ${BOOTBIN%.*}.elf >$TMPA
awk '$1 ~ /^[0-9a-fA-F]+$/ && $(NF) == "ldrblk" {printf "%u", "0x"$1}' $TMPA
