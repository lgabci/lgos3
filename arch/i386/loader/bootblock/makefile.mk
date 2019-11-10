# i386 boot loader makefile

.PHONY: bootblock
bootblock: $(BOOTBLOCK_MBR_BIN) $(BOOTBLOCK_EXT2_BIN) $(BOOTBLOCK_FAT_BIN)

BOOTBLOCK_MBR_BIN := $(DESTDIR)/bootblock_mbr.bin
BOOTBLOCK_EXT2_BIN := $(DESTDIR)/bootblock_ext2.bin
BOOTBLOCK_FAT_BIN := $(DESTDIR)/bootblock_fat.bin

BOOTBLOCK_MBR_ELF := $(BOOTBLOCK_MBR_BIN:.bin=.elf)
BOOTBLOCK_EXT2_ELF := $(BOOTBLOCK_EXT2_BIN:.bin=.elf)
BOOTBLOCK_FAT_ELF := $(BOOTBLOCK_FAT_BIN:.bin=.elf)

$(BOOTBLOCK_MBR_BIN): $(BOOTBLOCK_MBR_ELF)
$(BOOTBLOCK_EXT2_BIN): $(BOOTBLOCK_EXT2_ELF)
$(BOOTBLOCK_FAT_BIN): $(BOOTBLOCK_FAT_ELF)

BOOTBLOCK_MBR_O := bootblock_mbr.o
$(call addpref,BOOTBLOCK_MBR_O)
$(BOOTBLOCK_MBR_ELF): $(BOOTBLOCK_MBR_O)

BOOTBLOCK_EXT2_O := bootblock_ext2.o
$(call addpref,BOOTBLOCK_EXT2_O)
$(BOOTBLOCK_EXT2_ELF): $(BOOTBLOCK_EXT2_O)

BOOTBLOCK_FAT_O := bootblock_fat.o
$(call addpref,BOOTBLOCK_FAT_O)
$(BOOTBLOCK_FAT_ELF): $(BOOTBLOCK_FAT_O)

#$(DESTDIR)/bootblock_mbr.o: $(SRCDIR)/bootblock_mbr.s | $(DESTDIR)
#$(DESTDIR)/bootblock_ext2.o: $(SRCDIR)/bootblock_ext2.s | $(DESTDIR)
#$(DESTDIR)/bootblock_fat.o: $(SRCDIR)/bootblock_fat.s | $(DESTDIR)
