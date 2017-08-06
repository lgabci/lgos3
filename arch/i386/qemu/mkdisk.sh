#!/bin/bash
# LGOS3 i386 qemu disk image creator script
set -o errexit
set -o pipefail
set -o posix

function ddelf {
# copy the contents of an ELF file into another file
# args:	1. input file (ELF file)
#	2. output file
#	3. start position in output file, byte
#	4. maximum length of input (error occured if overreach)
  elf="$1"
  out="$2"
  outpos=$3
  maxlen=$4

  unset minoofs
## put i686-elf-... executables in PATH
  /home/gabci/bin/i686-elf-objdump -p "$elf" | awk -f elf.awk | sort -nr |
  while read iofs oofs sz; do
    minoofs=${minoofs:-$oofs}
    if [ $((oofs - minoofs + sz)) -gt $maxlen ]; then
      echo "ddelf: write over ($elf: $((oofs - minoofs + sz)) > $maxlen)" >&2
      exit 1
    fi
    dd if="$elf" of="$out" bs=1 count=$sz skip=$iofs \
      seek=$((outpos + oofs)) conv=notrunc status=noxfer 2>/dev/null
  done
}

function getelfaddr {
# get global variable address from ELF file
# args:	1. input file (ELF file)
#	2. variable name    
  elf="$1"
  var=$2

  /home/gabci/bin/i686-elf-objdump -t "$elf" | \
    awk --non-decimal-data '{if ($1 ~ "^[0-9a-f]+$" && $(NF) == "'$var'") {printf "%d %d\n", "0x"$1, "0x"$(NF - 1)}}'
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
LDRELF=loader.elf
LDRCFGPATH=loadercfgpath			# cfg file name var in loader
LDRBLK=loader.blk
LDRBBDIR=../loader/bootblock			# loader bootblock directory
LDRCFG=loader.cfg				# loader cfg file

GRUBDIR=boot/grub
GRUBMENU=menu.lst

KRNLDIRIMG=kernel				# kernel directory in image
KRNLDIR=../kernel				# kernel directory here
KRNL=init.elf					##
#KRNL=init.bin					##
KRNLPRMS="test kernel  parameters"		##

ORIGUSER=$SUDO_USER				# caller of script
ORIGUSER=${ORIGUSER:=$(logname)}
ORIGUSER=${ORIGUSER:=$(who am i | cut -f 1 -d ' ')}
if [ -z "$ORIGUSER" ]; then
  echo "Can not detect user name" >&2
  exit 1
fi

case $IMGTYPE in
  fd)
    DRIVE=0					# BIOS disk ID
    CYL=80					# count of cylinders
    HEAD=2					# count of heads
    SEC=18					# count of sectors/track
    PART=""					# use whole disk
    PARTSTART=0
    PARTSIZE=$((CYL * HEAD * SEC))		# partition size in sectors
    DEVSTR=fd${ABC:DRIVE:1}			# device string
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
    DEVSTR=hd${ABC:((DRIVE - 0x80)):1}$PART
    echo "cyls=$CYL,heads=$HEAD,secs=$SEC" >"$IMGFILE.geom"
    chown $ORIGUSER:$ORIGUSER "$IMGFILE.geom"
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
chown $ORIGUSER:$ORIGUSER "$IMGFILE"			# give ownership

# create partition
if [ -n "$PART" ]; then
  if ! fmsg=$(echo -e "o\nn\np\n$PART\n$PARTSTART\n+$PARTSIZE\nt\n$PARTTYPE\na\nw\n" | \
    fdisk -H $HEAD -S $SEC "$IMGFILE"); then	# fdisk: create partition
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
esac

TMPFILE=$(mktemp)

MOUNTPOINT=$(mktemp -d)
mount $LOOPDEV $MOUNTPOINT

# install boot loader
case $BOOTLDR in
  own)						# install own loader
    mkdir -p $MOUNTPOINT/$LDRDIRIMG

    if [ -n "$PART" ]; then			# install MBR
      mbrfile="$LDRBBDIR/bootblock_mbr.elf"
      ddelf "$mbrfile" "$IMGFILE" 0 $SECSIZE
    fi

    bootfile="$LDRBBDIR/bootblock_$FSTYPE.elf"	# boot file and block num pos
## put i686-elf-... executables in PATH
    bootfpos=$((0x$(/home/gabci/bin/i686-elf-objdump -t "$bootfile" | \
      awk '{if ($1 ~ "^[0-9a-f]+$" && $NF == "ldrblk") {print $1}}')))

    ddelf "$bootfile" "$LOOPDEV" 0 $SECSIZE

						# copy loader binary
    cp "$LDRDIR/$LDRBIN" "$MOUNTPOINT/$LDRDIRIMG/$LDRBIN"
						# create blocklist file
    value="$(filefrag -b$SECSIZE -e -s "$MOUNTPOINT/$LDRDIRIMG/$LDRBIN" | \
      awk -f filefrag.awk BLKSIZE=$SECSIZE RELPOS=$PARTSTART)"
    printf "$value" >$MOUNTPOINT/$LDRDIRIMG/$LDRBLK
						# block of blocklist file
    value="$(filefrag -b$SECSIZE -e -s $MOUNTPOINT/$LDRDIRIMG/$LDRBLK | \
      awk -f filefrag.awk BLKSIZE=4 RELPOS=$PARTSTART)"
    printf "$value" | dd of="$LOOPDEV" bs=1 seek=$bootfpos conv=notrunc \
      status=noxfer 2>/dev/null

    cfgpathaddr="$(getelfaddr "$LDRDIR/$LDRELF" $LDRCFGPATH)"
    cfgpathlen=${cfgpathaddr#* }
    cfgpathaddr=${cfgpathaddr% *}
    cfgpath="/$LDRDIRIMG/$LDRCFG"
    cfgpath="${cfgpath////$PATHSEP}"
    printf "%s\0" "$DEVSTR:$cfgpath" |\
      dd of="$MOUNTPOINT/$LDRDIRIMG/$LDRBIN" bs=1 seek=$cfgpathaddr \
        conv=notrunc status=noxfer 2>/dev/null

    krnlpath="/$KRNLDIRIMG/$KRNL"
    krnlpath="${krnlpath////$PATHSEP}"
    echo "$DEVSTR:$krnlpath $KRNLPRMS" >$MOUNTPOINT/$LDRDIRIMG/$LDRCFG
    ;;
  grub)						# install GRUB
    mkdir -p $MOUNTPOINT/$GRUBDIR
    cp grub/stage[12] $MOUNTPOINT/$GRUBDIR/

    umount $LOOPDEV
    case $IMGTYPE in
      fd)
        sudo -u $ORIGUSER qemu-system-i386 -m 2 \
          -drive file=grub/grub_inst_fd.img,index=0,if=floppy,format=raw \
          -drive file="$IMGFILE",index=1,if=floppy,format=raw \
          -boot a -net none -serial none -parallel none -display none
        ;;
      hd*)
        sudo -u $ORIGUSER qemu-system-i386 -m 2 \
          -drive file=grub/grub_inst_hd.img,index=0,if=floppy,format=raw \
          -drive file="$IMGFILE",if=ide,bus=0,unit=0,cyls=\
$CYL,heads=$HEAD,secs=$SEC,trans=lba,format=raw -boot a \
          -net none -serial none -parallel none -display none
        ;;
    esac
    mount $LOOPDEV $MOUNTPOINT

    cat >$MOUNTPOINT/$GRUBDIR/$GRUBMENU <<-EOF
	default 1
	timeout 10

	title LGOS 3
	kernel /$KRNLDIRIMG/$KRNL $KRNLPRMS
	EOF
    ;;
  *)						# unknown loader
    echo "Bad boot loader type: $BOOTLDR" >&2
    exit 1
    ;;
esac

# copy kernel
mkdir -p $MOUNTPOINT/$KRNLDIRIMG/
cp $KRNLDIR/$KRNL $MOUNTPOINT/$KRNLDIRIMG/$KRNL
