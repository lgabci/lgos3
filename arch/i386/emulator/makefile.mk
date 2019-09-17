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

FDISK := /usr/sbin/fdisk
PFDISK := o n p 1 $(PSTART) +$(PSIZE) w

MKFSEXT2 := /usr/sbin/mkfs.ext2

PQEMU = -machine pc -cpu 486 -boot order=c -m size=2 \
-drive file=$<,if=ide,index=0,media=disk,format=raw -nic none

.PHONY: emulator
emulator: qemu

.PHONY: qemu
qemu: $(HDIMG)
	qemu-system-$(ARCH) $(PQEMU)

## BOOTBLOCK_FAT_ELF
$(HDIMG): $(BOOTBLOCK_MBR_ELF) $(BOOTBLOCK_EXT2_ELF) $(LOADER_ELF) | $(DESTDIR)
	dd if=/dev/zero of=$@.ext2 bs=1 seek=$(PSIZEB) count=0 2>/dev/null
	$(MKFSEXT2) $@.ext2 >/dev/null
	echo CREATE BOOT ## TODO
	echo COPY boot loader and kernel ## TODO
	dd if=/dev/zero of=$@ bs=1 seek=$(HDSIZEB) count=0 2>/dev/null
	echo $(PFDISK) | tr ' ' '\n' | $(FDISK) $@ >/dev/null
	echo CREATE MBR ## TODO
	dd if=$@.ext2 of=$@ conv=sparse,notrunc iflag=fullblock 2>/dev/null
	rm $@.ext2
