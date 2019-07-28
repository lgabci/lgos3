# i386 boot loader makefile

.PHONY: bootblock
bootblock: $(DESTDIR)/bootblock_mbr.elf $(DESTDIR)/bootblock_ext2.elf \
  $(DESTDIR)/bootblock_fat.elf

-include $(DESTDIR)/bootblock_mbr.elf.d $(DESTDIR)/bootblock_ext2.elf.d \
  $(DESTDIR)/bootblock_fat.elf.d

$(DESTDIR)/bootblock_mbr.elf: $(SRCDIR)/bootblock_mbr.s | $(DESTDIR)
	$(AS) $(ASFLAGS) -o $@ $<

$(DESTDIR)/bootblock_ext2.elf: $(SRCDIR)/bootblock_ext2.s | $(DESTDIR)
	$(AS) $(ASFLAGS) -o $@ $<

$(DESTDIR)/bootblock_fat.elf: $(SRCDIR)/bootblock_fat.s | $(DESTDIR)
	$(AS) $(ASFLAGS) -o $@ $<
