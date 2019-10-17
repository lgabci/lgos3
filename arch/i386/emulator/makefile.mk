# emulator makefile
MKIMGSH := $(SRCDIR)/mkimg.sh

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

PSEQ = while read a b;\
  do seq $$((a + $(PSTART))) $$(($${b:-a} + $(PSTART)));\
done

PQEMU = -machine pc -cpu 486 -boot order=c -m size=2 \
-drive file=$<,if=ide,index=0,media=disk,format=raw -nic none

.PHONY: emulator
emulator: qemu

.PHONY: qemu
qemu: $(HDIMG)
	qemu-system-$(ARCH) $(PQEMU)

$(HDIMG): $(BOOTBLOCK_MBR_BIN) $(BOOTBLOCK_EXT2_BIN) $(LOADER_BIN) | $(DESTDIR)
	$(MKIMGSH) $@ $^
