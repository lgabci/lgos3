# emulator makefile
HDIMG := $(DESTDIR)/qemu_img_hdd_ldr_ext2.img

HDCYLS := 1023
HDHEADS := 16
HDSECS := 63
HDSECSIZE := 512

HDSIZE := $$(($(HDCYLS) * $(HDHEADS) * $(HDSECS) * $(HDSECSIZE)))

.PHONY: emulator
emulator: $(HDIMG).part

## TODO $(HDIMG): $(LOADER_ELF) $(KERNEL_ELF) $(BOOTBLOCK_EXT2_ELF) | $(DESTDIR)

$(HDIMG).part: $(HDIMG)
	echo OSTYPE $(OSTYPE)
ifeq ($(OSTYPE), OpenBSD)
	doas vnconfig vnd0 $<
	doas fdisk -i -c $(HDCYLS) -h $(HDHEADS) -s $(HDSECS) vnd0
	doas fdisk -v vnd0
	doas vnconfig -u vnd0
else
  $(error Unknown OSTYPE: $(OSTYPE))
endif

$(HDIMG): | $(DESTDIR)
	dd if=/dev/zero of=$@ bs=1 seek=$(HDSIZE) count=0
	ls -la $^ $@
