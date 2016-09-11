#!/bin/bash
# LGOS3 i386 qemu disk image creator script
set -e
set -o pipefail

function getmap() {
# get variable address from a map file
# args:	1. mapfile
#	2. variable name
  mapfile=$1
  var=$2

  hexaddr=$(awk '{ if ($1 ~ "^0x" && $2 == "'$var'") print $1}' $mapfile) # '
  if [ -n "$hexaddr" ]; then
    echo $((hexaddr))
  else
    echo "$var not found in $mapfile" >&2
    exit 1
  fi
}

function writebin {
# write binary value of a number
# args:	1. number
#	2. length in bytes
#	3. file
#	4. position in file
  val=$1
  len=$2
  fname=$3
  fpos=$4

  for ((j=0; j<$len; j ++)); do
    byte=$((val % 256))
    val=$((val / 256))
    printf "\x$(printf %x $byte)"
  done | dd of=$fname bs=1 seek=$fpos conv=notrunc status=noxfer 2>/dev/null
  unset j
}

function ddfile {
# dd a file into another file (copy only if there's a difference)
# args:	1. input file
#	2. output file
#	3. length in bytes
#	4. start position in output file, byte
#	5. start position in input file, byte
  infile=$1
  outfile=$2
  len=$3
  outpos=$4
  inpos=$5

  args="bs=1"
  if [ -n "$inpos" ]; then			# starting pos in input file
    args="$args skip=$inpos"
  fi
  if [ -n "$outpos" ]; then			# starting pos in output file
    args="$args seek=$outpos"
  fi
  if [ -n "$len" ]; then			# length in bytes
    args="$args count=$len"
  fi
						# copy if differs or len = 0
  dd if=$infile of=$outfile $args conv=notrunc status=noxfer 2>/dev/null
}

function exitfv() {				# exit function
  exitcode=$?

  if [ -n "$TMPFILE" ]; then
    rm $TMPFILE
  fi

  if [ -n "$MOUNTPOINT" ]; then
    if findmnt $MOUNTPOINT >/dev/null; then
      umount $MOUNTPOINT
    fi
    if [ -e $MOUNTPOINT ]; then
      rm -r $MOUNTPOINT
    fi
  fi

  if [ -n "$LOOPDEV" ]; then
    losetup -d $LOOPDEV
  fi

  if [ $exitcode -ne 0 ]; then
    rm -f $IMGFILE $IMGFILE.geom
  fi
}

if [ $# -lt 4 -o $# -gt 4 ]; then		# check arguments
  echo "create qemu image" >&2
  echo "usage:" >&2
  echo "$(basename $0) img type fstype bootldr" >&2
  echo "    img:     image file" >&2
  echo "    type:    image type (fd/hd/bighd)" >&2
  echo "    fstype:  filesystem type (ext2/fat)" >&2
  echo "    bootldr: boot loader (own/grub)" >&2
  exit 1
fi

ABC=abcdefghij					# for HDx and FDx letters

IMGFILE=$1					# image file
IMGTYPE=$2					# image type
FSTYPE=$3					# filesystem type
BOOTLDR=$4					# boot loader type

SECSIZE=512					# size of disk block in bytes
RECSIZE=8					# size of an LBA record

LDRDIRIMG=boot/loader				# loader directory in image
LDRDIR=../loader/loader				# loader directory
LDRBIN=loader.bin
LDRBBDIR=../loader/bootblock			# loader bootblock directory
BBLKBIN=bootblock.bin
LDRBLK=loader.blk				# loader.bin blocklist file
LDRCFG=loader.cfg				# loader config file

GRUBDIR=boot/grub
GRUBMENU=menu.lst

KRNDIRIMG=kernel				# kernel directory in image
KRNDIR=../kernel				# kernel directory here
KERNEL=init.elf					##
#KERNEL=init.bin					##
KERNELPARAMS="alma korte 1"			##

O_USER=$(who am i | cut -f 1 -d ' ')		# caller of script

case $IMGTYPE in
  fd)
    DRIVE=0					# BIOS disk ID
    CYL=80					# count of cylinders
    HEAD=2					# count of heads
    SEC=18					# count of sectors/track
    PART=""					# use whole disk
    PARTSTART=0
    PARTSIZE=$((CYL * HEAD * SEC))		# partition size in sectors
    DEVICESTR=fd${ABC:DRIVE:1}			# device string
    rm -f $IMGFILE.geom				# no geom file for floppy
    ;;
  hd|bighd)
    DRIVE=0x80
    if [ $IMGTYPE == bighd ]; then
      CYL=10240
    else
      CYL=521
    fi
    HEAD=16
    SEC=63
    PART=1					# use partition 1
    PARTSTART=2048
    if [ $IMGTYPE == bighd ]; then
      PARTSIZE=8388608
    else
      PARTSIZE=40960
    fi
    DEVICESTR=hd${ABC:((DRIVE - 0x80)):1}$PART
    echo "cyls=$CYL,heads=$HEAD,secs=$SEC" >"$IMGFILE.geom"
    chown $O_USER:$O_USER "$IMGFILE.geom"
    ;;
  *)
    echo "Bad image type: $IMGTYPE" >&2
    exit 1
    ;;
esac

case $FSTYPE in
  ext2)						# ext2
    PATHSEP=/
    PARTTYPE=0x83
    ;;
  fat)
    PATHSEP='\'
    case $IMGTYPE in
      fd)					# floppy: FAT12
        PARTTYPE=0x01
        ;;
      *)					# FAT16 <32M
        PARTTYPE=0x04
        ;;
    esac
    ;;
  *)
    echo "Bad fs type: $FSTYPE" >&2
    exit 1
    ;;
esac

DISKSIZE=$((CYL * HEAD * SEC))			# disk size in sectors

trap exitfv EXIT				# set trap for exit

# create image file
dd if=/dev/zero of="$IMGFILE" bs=$SECSIZE count=0 seek=$DISKSIZE \
  status=noxfer 2>/dev/null
chown $O_USER:$O_USER "$IMGFILE"			# give ownership

# create partition
if [ -n "$PART" ]; then
  if ! fmsg=$(echo -e "o\nn\np\n$PART\n$PARTSTART\n+$PARTSIZE\nt\n$PARTTYPE\na\nw\n" | \
    fdisk "$IMGFILE"); then			# fdisk: create partition
    echo "$fmsg"
    exit 1					# can not create partition
  fi
fi

# create device files
LOOPDEV=$(losetup -o $((PARTSTART * SECSIZE)) \
  --sizelimit $((PARTSIZE * SECSIZE)) --show -f "$IMGFILE")

# create filesystem
case $FSTYPE in
  ext2)
    mkfs.ext2 -F -L LGOS3 $LOOPDEV >/dev/null
    ;;
  fat)
    mkfs.vfat -n LGOS3 $LOOPDEV >/dev/null
    ;;
  *)
    echo "Bad fs type: $FSTYPE" >&2
    exit 1
    ;;
esac

TMPFILE=$(mktemp)

MOUNTPOINT=$(mktemp -d)
mount $LOOPDEV $MOUNTPOINT

# install boot loader
case $BOOTLDR in
  own)						# install own loader
    mkdir -p $MOUNTPOINT/$LDRDIRIMG
    cp $LDRDIR/$LDRBIN $MOUNTPOINT/$LDRDIRIMG/$LDRBIN

    if [ -n "$PART" ]; then			# install MBR
      lmbrmapfile=$LDRBBDIR/${BBLKBIN%.*}_mbr.map
      mbrstart=$(getmap $lmbrmapfile mbrdatastart)
      mbrend=$(getmap $lmbrmapfile mbrdataend)
      ddfile $LDRBBDIR/${BBLKBIN%.*}_mbr.bin $IMGFILE $mbrstart	# up to part t.
      ddfile $LDRBBDIR/${BBLKBIN%.*}_mbr.bin $IMGFILE "" $mbrend $mbrend # sign
    fi

    lmapfile=$LDRBBDIR/${BBLKBIN%.*}.map
    nextbbaddr=$(getmap $lmapfile nextbb)	# end of boot data
    case $FSTYPE in				# install boot block
      ext2)					# ext2 has 1K space
        ddfile $LDRBBDIR/$BBLKBIN $LOOPDEV
        writebin $((PARTSTART + 1)) $RECSIZE $LOOPDEV $nextbbaddr
        bootblockdev=$LOOPDEV			# place of boot block
        ;;
      fat)					# FAT has only 512 byte space
        cp $LDRBBDIR/$BBLKBIN $MOUNTPOINT/$LDRDIRIMG/$BBLKBIN

        filefrag -b$SECSIZE -e -s $MOUNTPOINT/$LDRDIRIMG/$BBLKBIN | \
          awk -f filefrag.awk RELPOS=$PARTSTART FORMAT=1 >$TMPFILE
        if [ $(wc -l $TMPFILE | awk '{print $1}') -ne 2 ]; then
          echo "$LDRBBDIR/$BBLKBIN is not 2 * 512 bytes long"
          exit 1
        fi
        firstbb=$(awk 'NR == 1' $TMPFILE)
        nextbb=$(awk 'NR == 2' $TMPFILE)

        writebin $nextbb $RECSIZE $MOUNTPOINT/$LDRDIRIMG/$BBLKBIN $nextbbaddr

        lfatmapfile=$LDRBBDIR/${BBLKBIN%.*}_fat.map
        bootstart=$(getmap $lfatmapfile bootdatastart)	# start of boot data
        bootend=$(getmap $lfatmapfile bootcodestart)	# end of boot data
        firstbbaddr=$(getmap $lfatmapfile firstbb)	# first block of bin

        ddfile $LDRBBDIR/${BBLKBIN%.*}_fat.bin $LOOPDEV $bootstart
        ddfile $LDRBBDIR/${BBLKBIN%.*}_fat.bin $LOOPDEV "" $bootend $bootend
        writebin $firstbb $RECSIZE $LOOPDEV $firstbbaddr

        bootblockdev=$MOUNTPOINT/$LDRDIRIMG/$BBLKBIN	# place of boot block
        ;;
      *)
        echo "Bad fs type: $FSTYPE" >&2
        exit 1
        ;;
    esac

							# create blocklist file
    filefrag -b$SECSIZE -e -s $MOUNTPOINT/$LDRDIRIMG/$LDRBIN | \
      awk -f filefrag.awk SECSIZE=$SECSIZE RELPOS=$PARTSTART | \
        while read a; do
          printf "$a"
        done >$MOUNTPOINT/$LDRDIRIMG/$LDRBLK

			# write its own block numbers into blocklist file
    filefrag -b$SECSIZE -e -s $MOUNTPOINT/$LDRDIRIMG/$LDRBLK | \
      awk -f filefrag.awk RELPOS=$PARTSTART FORMAT=1 | \
        {
          read a				# write firstb into bootblock
          firstbaddr=$(getmap $lmapfile firstb)
          writebin $a $RECSIZE $bootblockdev $firstbaddr

          seekpos=$((SECSIZE - RECSIZE))
          while read a; do
            writebin $a $RECSIZE $MOUNTPOINT/$LDRDIRIMG/$LDRBLK $seekpos
            seekpos=$((seekpos + SECSIZE))
          done
        }

    loadercfgpathaddr=$(getmap $lmapfile loadercfgpath)
    cfgpath=/$LDRDIRIMG/$LDRCFG
    { echo -n "$DEVICESTR:${cfgpath////$PATHSEP}"; echo -e -n "\x00"; } | \
      dd of=$bootblockdev bs=1 seek=$loadercfgpathaddr conv=notrunc status=noxfer 2>/dev/null
    kernelpath=/$KRNDIRIMG/$KERNEL
    echo "$DEVICESTR:${kernelpath////$PATHSEP} $KERNELPARAMS" \
      >$MOUNTPOINT/$LDRDIRIMG/$LDRCFG

    start=$(getmap $LDRDIR/${LDRBIN%.*}.map start)	# start in loader.bin
    ldraddraddr=$(getmap $lmapfile ldraddr)
    writebin $start 2 $bootblockdev $ldraddraddr
    ;;
  grub)						# install GRUB
    mkdir -p $MOUNTPOINT/$GRUBDIR
    cp grub/stage[12] $MOUNTPOINT/$GRUBDIR/

    umount $LOOPDEV
    case $IMGTYPE in
      fd)
        sudo -u gabci qemu-system-i386 -m 2 -fda grub/grub_inst_fd.img \
          -fdb "$IMGFILE" -boot a \
          -net none -serial none -parallel none -display none
        ;;
      hd*)
        sudo -u gabci qemu-system-i386 -m 2 \
          -fda grub/grub_inst_hd.img \
          -drive file="$IMGFILE",if=ide,bus=0,unit=0,cyls=\
$CYL,heads=$HEAD,secs=$SEC,trans=lba -boot a \
          -net none -serial none -parallel none -display none
        ;;
    esac
    mount $LOOPDEV $MOUNTPOINT

    cat >$MOUNTPOINT/$GRUBDIR/$GRUBMENU <<-EOF
	default 1
	timeout 10

	title LGOS 3
	kernel /$KRNDIRIMG/$KERNEL
	EOF
    ;;
  *)						# unknown loader
    echo "Bad boot loader type: $BOOTLDR" >&2
    exit 1
    ;;
esac

# copy kernel
mkdir -p $MOUNTPOINT/$KRNDIRIMG/
cp $KRNDIR/$KERNEL $MOUNTPOINT/$KRNDIRIMG/$KERNEL
sync			##
