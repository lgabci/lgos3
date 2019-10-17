#!/bin/bash

set -e

if [ $# -ne 4 ]; then
    echo usage >&2
    echo $(basename $0) hdimg mbr.bin boot.bin loader.bin >&2
    exit 1
fi

HDIMG="$1"
MBRBIN="$2"
BOOTBIN="$3"
LOADERBIN="$4"

HDCYLS=1023
HDHEADS=16
HDSECS=63
HDSECSIZE=512

HDSIZEB=$((HDCYLS * HDHEADS * HDSECS * HDSECSIZE))

# partition start and size in sectors
PSTART=2048
PSIZE=20480
PSTARTB=$((PSTART * HDSECSIZE))
PSIZEB=$((PSIZE * HDSECSIZE))

dd if=/dev/zero of=$HDIMG.ext2 bs=1 seek=$PSIZEB count=0 2>/dev/null
/usr/sbin/mkfs.ext2 -F $HDIMG.ext2 >/dev/null 2>&1
dd if=$BOOTBIN of=$HDIMG.ext2 conv=notrunc 2>/dev/null
cp $MBRBIN $HDIMG
dd if=/dev/zero of=$HDIMG bs=1 seek=$HDSIZEB count=0 2>/dev/null
echo "n;p;1;$PSTART;+$PSIZE;a;w" | tr ';' '\n' | /usr/sbin/fdisk $HDIMG >/dev/null
dd if=$HDIMG.ext2 of=$HDIMG bs=512 seek=$PSTART conv=sparse,notrunc iflag=fullblock 2>/dev/null
rm $HDIMG.ext2
LOOPDEV=$(udisksctl loop-setup --file $HDIMG --offset $PSTARTB --size $PSIZEB | sed -e 's/.* //;s/\.//')
MOUNTDIR=$(udisksctl mount --block-device $LOOPDEV | sed -e 's/.* //;s/\.//')

#mkdir -p $MOUNTDIR/boot/
#cp $LOADERBIN $MOUNTDIR/boot/
#/sbin/filefrag -b512 -e /

if findmnt --source $LOOPDEV >/dev/null 2>&1; then
  udisksctl unmount --block-device $LOOPDEV >/dev/null
fi
if /usr/sbin/losetup $LOOPDEV >/dev/null 2>&1; then
  udisksctl loop-delete --block-device $LOOPDEV
fi
