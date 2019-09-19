# i386 boot loader makefile
BOOTBLOCK_MBR_ELF := $(DESTDIR)/bootblock_mbr.elf
BOOTBLOCK_EXT2_ELF := $(DESTDIR)/bootblock_ext2.elf
BOOTBLOCK_FAT_ELF := $(DESTDIR)/bootblock_fat.elf

-include $(BOOTBLOCK_MBR_ELF).$(DEXT) $(BOOTBLOCK_EXT2_ELF).$(DEXT) \
  $(BOOTBLOCK_FAT_ELF).$(DEXT)

.PHONY: bootblock
bootblock: $(BOOTBLOCK_MBR_ELF) $(BOOTBLOCK_EXT2_ELF) $(BOOTBLOCK_FAT_ELF)

$(BOOTBLOCK_MBR_ELF): $(SRCDIR)/bootblock_mbr.s $(SRCDIR)/bootblock_mbr.ld | $(DESTDIR)
	$(AS) $(ASFLAGS) -o $@ $<

$(DESTDIR)/bootblock_ext2.o: $(SRCDIR)/bootblock_ext2.s | $(DESTDIR)
	$(AS) $(ASFLAGS) -o $@ $<

$(BOOTBLOCK_EXT2_ELF): $(DESTDIR)/bootblock_ext2.o $(SRCDIR)/bootblock_ext2.ld


$(BOOTBLOCK_FAT_ELF): $(SRCDIR)/bootblock_fat.s | $(DESTDIR)
	$(AS) $(ASFLAGS) -o $@ $<
