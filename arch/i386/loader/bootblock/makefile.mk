# i386 boot loader makefile
BOOTBLOCK_MBR_BIN := $(DESTDIR)/bootblock_mbr.bin
BOOTBLOCK_EXT2_BIN := $(DESTDIR)/bootblock_ext2.bin
BOOTBLOCK_FAT_BIN := $(DESTDIR)/bootblock_fat.bin
BOOTBLOCK_MBR_ELF := $(BOOTBLOCK_MBR_BIN:.bin=.elf)
BOOTBLOCK_EXT2_ELF := $(BOOTBLOCK_EXT2_BIN:.bin=.elf)
BOOTBLOCK_FAT_ELF := $(BOOTBLOCK_FAT_BIN:.bin=.elf)

-include $(BOOTBLOCK_MBR_ELF).$(DEXT) $(BOOTBLOCK_EXT2_ELF).$(DEXT) \
  $(BOOTBLOCK_FAT_ELF).$(DEXT)

.PHONY: bootblock
bootblock: $(BOOTBLOCK_MBR_BIN) $(BOOTBLOCK_EXT2_BIN) $(BOOTBLOCK_FAT_BIN)

$(BOOTBLOCK_MBR_BIN): $(BOOTBLOCK_MBR_ELF)
$(BOOTBLOCK_EXT2_BIN): $(BOOTBLOCK_EXT2_ELF)
$(BOOTBLOCK_FAT_BIN): $(BOOTBLOCK_FAT_ELF)

$(BOOTBLOCK_MBR_ELF): $(DESTDIR)/bootblock_mbr.o $(SRCDIR)/bootblock_mbr.ld
$(BOOTBLOCK_EXT2_ELF): $(DESTDIR)/bootblock_ext2.o $(SRCDIR)/bootblock_ext2.ld
$(BOOTBLOCK_FAT_ELF): $(DESTDIR)/bootblock_fat.o $(SRCDIR)/bootblock_fat.ld

$(DESTDIR)/bootblock_mbr.o: $(SRCDIR)/bootblock_mbr.s | $(DESTDIR)
$(DESTDIR)/bootblock_ext2.o: $(SRCDIR)/bootblock_ext2.s | $(DESTDIR)
$(DESTDIR)/bootblock_fat.o: $(SRCDIR)/bootblock_fat.s | $(DESTDIR)
