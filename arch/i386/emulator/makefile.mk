# emulator makefile
MKIMGSH := $(SRCDIR)/mkimg.sh

HDIMG := $(DESTDIR)/qemu_img_hdd_ldr_ext2.img

PQEMU = -machine pc -cpu 486 -boot order=c -m size=2 \
-drive file=$<,if=ide,index=0,media=disk,format=raw -nic none

.PHONY: emulator
emulator: qemu

.PHONY: qemu
qemu: $(HDIMG)
	qemu-system-$(ARCH) $(PQEMU)

$(HDIMG): $(BOOTBLOCK_MBR_BIN) $(BOOTBLOCK_EXT2_BIN) $(LOADER_BIN) $(KERNEL_ELF) | $(DESTDIR)
	$(MKIMGSH) $@ $^
