# emulator makefile
HDIMG := $(DESTDIR)/qemu_img_hdd_ldr_ext2.img

HDCYLS := 1023
HDHEADS := 16
HDSECS := 63
HDSECSIZE := 512

HDSIZEB := $$(($(HDCYLS) * $(HDHEADS) * $(HDSECS) * $(HDSECSIZE)))

# partition start and size in sectors
PSTART := 2048
PSIZE := 20480
PSTARTB := $$(($(PSTART) * $(HDSECSIZE)))
PSIZEB := $$(($(PSIZE) * $(HDSECSIZE)))

TR := tr ';' '\n'

FDISK := /usr/sbin/fdisk
PFDISK := "n;p;1;$(PSTART);+$(PSIZE);a;w"

MKFSEXT2 := /usr/sbin/mkfs.ext2

DEBUGFS := /sbin/debugfs
PDEBUGFS = "mkdir /boot;cd /boot;write $(word 3,$^) $(notdir $(word 3,$^));\
stat /boot/$(notdir $(word 3,$^))"

PQEMU = -machine pc -cpu 486 -boot order=c -m size=2 \
-drive file=$<,if=ide,index=0,media=disk,format=raw -nic none

.PHONY: emulator
emulator: qemu

.PHONY: qemu
qemu: $(HDIMG)
	qemu-system-$(ARCH) $(PQEMU)

## BOOTBLOCK_FAT_ELF
$(HDIMG): $(BOOTBLOCK_MBR_BIN) $(BOOTBLOCK_EXT2_BIN) $(LOADER_BIN) | $(DESTDIR)
	dd if=/dev/zero of=$@.ext2 bs=1 seek=$(PSIZEB) count=0 2>/dev/null
	$(MKFSEXT2) -F $@.ext2 >/dev/null
	dd if=$(word 2,$^) of=$@.ext2 conv=notrunc 2>/dev/null
	echo $(PDEBUGFS) | $(TR) | $(DEBUGFS) -wf - $@.ext2
	##
	cp $< $@
	dd if=/dev/zero of=$@ bs=1 seek=$(HDSIZEB) count=0 2>/dev/null
	echo $(PFDISK) | $(TR) | $(FDISK) $@ >/dev/null
	dd if=$@.ext2 of=$@ bs=512 seek=$(PSTART) conv=sparse,notrunc \
iflag=fullblock 2>/dev/null
	rm $@.ext2
