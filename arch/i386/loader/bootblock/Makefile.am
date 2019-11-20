AM_CFLAGS += -m16
AM_CCASFLAGS = -Wa,-I -Wa,$(srcdir)

noinst_PROGRAMS = bootblock_mbr.elf bootblock_ext2.elf bootblock_fat.elf
noinst_PROGRAMS += bootblock_mbr.bin bootblock_ext2.bin bootblock_fat.bin

bootblock_mbr_elf_SOURCES = bootblock_mbr.s init.s disk.s misc.s video.s
bootblock_mbr_elf_LDFLAGS = $(AM_LDFLAGS) -T $(srcdir)/bootblock_mbr.ld

bootblock_ext2_elf_SOURCES = bootblock_ext2.s init.s disk.s misc.s video.s load.s
bootblock_ext2_elf_LDFLAGS = $(AM_LDFLAGS) -T $(srcdir)/bootblock_ext2.ld

bootblock_fat_elf_SOURCES = bootblock_fat.s init.s disk.s misc.s video.s load.s
bootblock_fat_elf_LDFLAGS = $(AM_LDFLAGS) -T $(srcdir)/bootblock_fat.ld

bootblock_mbr_bin_SOURCES =
bootblock_mbr_bin_DEPENDENCIES = bootblock_mbr.elf
bootblock_mbr_bin_LINK = $(OBJCOPY) -O binary $< $@

bootblock_ext2_bin_SOURCES =
bootblock_ext2_bin_DEPENDENCIES = bootblock_ext2.elf
bootblock_ext2_bin_LINK = $(OBJCOPY) -O binary $< $@

bootblock_fat_bin_SOURCES =
bootblock_fat_bin_DEPENDENCIES = bootblock_fat.elf
bootblock_fat_bin_LINK = $(OBJCOPY) -O binary $< $@

init.$(OBJEXT): bootblock.inc
load.$(OBJEXT): bootblock.inc
bootblock_mbr.$(OBJEXT): bootblock.inc
