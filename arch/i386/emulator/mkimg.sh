#!/bin/sh
# LGOS disk image generator script

set -eu
if [ $# -ne 8 ]; then
  echo "$(basename $0) img mbr boot loader kernel size type outdir" >&2
  echo "usage" >&2
  echo "  img:    image file" >&2
  echo "  mbr:    mbr code, if empty then making floppy image" >&2
  echo "  boot:   boot block code" >&2
  echo "  loader: boot loader binary" >&2
  echo "  kernel: kernel elf" >&2
  echo "  size:   partition size" >&2
  echo "  type:   partition type (fat, ext2)" >&2
  echo "  outdir: path of output" >&2
  exit 1
fi

unset DELFILES

IMG="$1"
MBR="$2"
BB="$3"
LDR="$4"
KERN="$5"
SIZE="$6"
TYPE="$7"
OUTDIR="$8"

SECSIZE=512     # block size on disk
PSTART=2048     # start of partition
BOOTDIR="boot"  # boot directory on disk

umountfv() {
  err=$?
  trap '' EXIT INT TERM ERR

  for f in "${DELFILES[@]}"; do
    rm -rf "$f"
  done

  if [ -n "${loopdev-}" ]; then
    if findmnt "$loopdev" >/dev/null; then
      udisksctl unmount --block-device "$loopdev" --no-user-interaction >/dev/null || true
    fi
    udisksctl loop-delete --block-device "$loopdev" --no-user-interaction
  fi
  exit $err
}
trap umountfv EXIT INT TERM ERR

case "$TYPE" in
  fat|ext2)
    ;;
  *)
    exit 1;
    ;;
esac

# create image file
rm -f "$IMG"
dd if=/dev/zero of="$IMG" bs="$SIZE" count=0 seek=1 status=none

# create file system
case "$TYPE" in
  ext2)
    DELFILES+=("$OUTDIR/$BOOTDIR/")
    mkdir -p "$OUTDIR/$BOOTDIR/$BOOTDIR/"
    /sbin/mkfs.ext2 -d "$OUTDIR/boot" -q "$IMG"
    ;;
  fat)
    /sbin/mkfs.vfat "$IMG" >/dev/null
    ;;
esac

# mount file system
loopdev=$(udisksctl loop-setup --file "$IMG" --no-user-interaction)
loopdev=${loopdev##* }
loopdev=${loopdev%%.*}
mountdir=$(udisksctl mount --block-device "$loopdev" --no-user-interaction)
mountdir=${mountdir##* }
mountdir=${mountdir%%.*}

# copy loader and kernel to image
mkdir -p "$mountdir/$BOOTDIR/"
cp "$LDR" "$mountdir/$BOOTDIR/"
cp "$KERN" "$mountdir/$BOOTDIR/"

# create loader file blocklist for bootblock
DELFILES+=("$IMG.frag")
/usr/sbin/filefrag -b$SECSIZE -e -s "$mountdir/$BOOTDIR/$(basename $LDR)" >"$IMG.frag"
DELFILES+=("$IMG.bl")
awk -F '[ :.]+' \
    '{
       gsub(/^ +/, "");
       if ($1 ~ /^[0-9]+$/) {
         print $4 " " $5
       }
     }' "$IMG.frag" | \
  while read a b; do
    seq $a $b | xargs printf '%08x'
  done | tac -rs .. | xxd -r -p >"$IMG.bl"

# copy blocklist to image file
case "$TYPE" in
  ext2)
    dd if="$IMG.bl" of="$IMG" bs=$SECSIZE seek=1 conv=notrunc status=none
    BLPOS=$((PSTART + 1))
    ;;
  fat)
    exit 1 ##
    ;;
esac

# set blocklist block number
ldrblk=$(i686-elf-objdump -t "${BB%.bin}.elf" | grep ldrblk)
ldrblk=$(echo "$ldrblk" | awk '{print $1}')
printf '%08x' $BLPOS | tac -rs .. | xxd -r -p | \
  dd of="$IMG" bs=1 seek=$((0x$ldrblk)) conv=notrunc status=none

# umount filesystem
umountfv

# add bootblock to filesystem
case "$TYPE" in
  ext2)
    dd if="$BB" of="$IMG" conv=notrunc status=none
    ;;
  fat)
    ##
    ;;
esac

# add MBR code to the image
if [ -n "$MBR" ]; then
  dd if="$IMG" of="$IMG-mbr" bs=$SECSIZE seek=$PSTART conv=sparse status=none
  mv "$IMG-mbr" "$IMG"

  case "$TYPE" in
    ext2)
      ptype=L
      ;;
    fat)
      ptype=0x0c
      ;;
  esac

  echo "$PSTART,$SIZE,$ptype,*" | \
    /usr/sbin/sfdisk "$IMG" --no-reread --no-tell-kernel -q --label dos \
    --wipe-partitions never 2>/dev/null
fi
