# emulator makefile
HDIMG := $(DESTDIR)/qemu_img_hdd_ldr_ext2.img

HDCYLS := 1023
HDHEADS := 16
HDSECS := 63
HDSECSIZE := 512

HDSIZE := $$(($(HDCYLS) * $(HDHEADS) * $(HDSECS) * $(HDSECSIZE)))

# partition start and size in sectors
PSTART := 2048
PSIZE := 20480

PFDISK := o n p 1 $(PSTART) +$(PSIZE) w
PLOSETUP := -o $$(($(PSTART) * $(HDSECSIZE))) \
--sizelimit $$(($(PSIZE) * $(HDSECSIZE))) --sector-size $(HDSECSIZE)

PQEMU = -machine pc -cpu 486 -boot order=c -m size=2 \
-drive file=$<,if=ide,index=0,media=disk,format=raw -nic none

.PHONY: emulator
emulator: qemu

.PHONY: qemu
qemu: $(HDIMG)
	qemu-system-$(ARCH) $(PQEMU)

## BOOTBLOCK_FAT_ELF
$(HDIMG): $(BOOTBLOCK_MBR_ELF) $(BOOTBLOCK_EXT2_ELF) $(LOADER_ELF) | $(DESTDIR)
	dd if=/dev/zero of=$@ bs=1 seek=$(HDSIZE) count=0 status=none
	echo $(PFDISK) | tr ' ' '\n' | /usr/sbin/fdisk $@ >/dev/null
	echo CREATE MBR ## TODO
	sudo losetup $(PLOSETUP) --show -f $@ >$@.losetup
	sudo mkfs.ext2 $$(cat $@.losetup) >/dev/null
	echo CREATE BOOT ## TODO
	mkdir -p $@.mount
	sudo mount $$(cat $@.losetup) $@.mount
	sudo mkdir -p $@.mount/loader
	sudo chown $$USER:$$USER $@.mount/loader
	cp $(word 3,$^) $@.mount/loader/
	sudo umount $$(cat $@.losetup)
	sudo losetup -d $$(cat $@.losetup)
	rmdir $@.mount
	rm $@.losetup
