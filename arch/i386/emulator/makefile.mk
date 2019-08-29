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

.PHONY: emulator
emulator: $(HDIMG).fs


## TODO $(HDIMG): $(LOADER_ELF) $(KERNEL_ELF) $(BOOTBLOCK_EXT2_ELF) | $(DESTDIR)

$(HDIMG).fs: $(HDIMG).losetup
	sudo mkfs.ext2 $$(cat $<)
	touch $@

$(HDIMG).losetup: $(HDIMG).part
	sudo losetup $(PLOSETUP) --show -f $(@:.losetup=) >$@

$(HDIMG).part: $(HDIMG)
	echo $(PFDISK) | tr ' ' '\n' | /usr/sbin/fdisk $< >/dev/null
	mkdir -p $@
	touch $@

$(HDIMG): | $(DESTDIR)
	dd if=/dev/zero of=$@ bs=1 seek=$(HDSIZE) count=0 status=none
