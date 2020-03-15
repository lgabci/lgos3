#!/bin/bash
# LGOS disk image generator script

# exit on error and error on undefined variables
set -eu -o pipefail

# test arguments
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

# umounts devices, deletes temp files, etc.
function cleanfv() {
  err=$?
  trap '' EXIT INT TERM

  rm -rf "$OUTDIR/$BOOTDIR/"

  if [ -n "${loopdev-}" ]; then
    if findmnt "$loopdev" >/dev/null; then
      udisksctl unmount --block-device "$loopdev" --no-user-interaction >/dev/null || true
    fi
    udisksctl loop-delete --block-device "$loopdev" --no-user-interaction
  fi

  if [ $err -ne 0 ]; then
    exit $err
  fi
}
trap cleanfv EXIT INT TERM

# create file system
function createfs() {
  # create partition image file
  rm -f "$IMG"
  dd if=/dev/zero of="$IMG" bs="$SIZE" count=0 seek=1 status=none

  # create file system
  case "$TYPE" in
    ext2)
      mkdir -p "$OUTDIR/$BOOTDIR/$BOOTDIR/"
      /sbin/mkfs.ext2 -d "$OUTDIR/boot" -q "$IMG"
      ;;
    fat)
      /sbin/mkfs.vfat "$IMG" >/dev/null
      ;;
  esac
}

# mount file system
function mountfs() {
  loopdev=$(udisksctl loop-setup --file "$IMG" --no-user-interaction)
  loopdev=${loopdev##* }
  loopdev=${loopdev%%.*}
  mountdir=$(udisksctl mount --block-device "$loopdev" --no-user-interaction)
  mountdir=${mountdir##* }
  mountdir=${mountdir%%.*}
}

# copy loader and kernel to image
function copyfiles() {
  mkdir -p "$mountdir/$BOOTDIR/"
  cp "$LDR" "$mountdir/$BOOTDIR/"
  cp "$KERN" "$mountdir/$BOOTDIR/"
}

# create block list of a file
function createbl() {
  /usr/sbin/filefrag -b$SECSIZE -e -s "$mountdir/$BOOTDIR/$(basename $LDR)" | \
  awk -F '[ :.]+' \
    '{
       gsub(/^ +/, "");
       if ($1 ~ /^[0-9]+$/) {
         print $4 + '"$PSTART"'" " $5 + '"$PSTART"'
       }
     }' | \
  while read a b; do
    seq $a $b | xargs printf '%08x'
  done | \
  tac -rs .. | \
  xxd -r -p | \
  case "$TYPE" in
    ext2)
      dd of="$IMG" bs=$SECSIZE seek=1 conv=notrunc status=none
      ;;
    fat)
      exit 1 ## TODO
      ;;
  esac
}

# add bootblock to filesystem
function bootblock() {
  case "$TYPE" in
    ext2)
      dd if="$BB" of="$IMG" conv=notrunc status=none
      ;;
    fat)
      ## TODO
      ;;
  esac
}

# set blocklist block number
function bootblockblknum() {
  ldrblk=$(i686-elf-objdump -t "${BB%.bin}.elf" |
    awk '{if ($NF == "ldrblk") {print $1; exit}}')
  if [ -z "$ldrblk" ]; then
    echo "Error: ldrblk not found in ${BB%.bin}.elf" >&2
    exit 1
  fi

  case "$TYPE" in
    ext2)
      BLPOS=$((PSTART + 1))
      ;;
    fat)
      exit 1 ## TODO
      ;;
  esac

  printf '%08x' $BLPOS | tac -rs .. | xxd -r -p | \
    dd of="$IMG" bs=1 seek=$((0x$ldrblk)) conv=notrunc status=none
}

# put partition image in hd image, add MBR code to the image
function mbr() {
  if [ -n "$MBR" ]; then
    dd if="$IMG" of="$IMG-mbr" bs=$SECSIZE seek=$PSTART conv=sparse status=none
    dd if="$MBR" of="$IMG-mbr" conv=notrunc status=none
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
}

case "$TYPE" in
  fat|ext2)
    ;;
  *)
    echo "Error: Unknown filesystem: $TYPE" >&2
    exit 1;
    ;;
esac

createfs
mountfs
copyfiles
createbl
bootblock
bootblockblknum
cleanfv
mbr
