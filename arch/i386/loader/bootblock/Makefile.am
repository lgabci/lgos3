AM_CFLAGS += -m16
AM_CCASFLAGS = -I $(srcdir)

bin_PROGRAMS = bootblock_mbr.elf bootblock_ext2.elf bootblock_fat.elf

bootblock_mbr_elf_SOURCES = bootblock_mbr.s init.s disk.s misc.s video.s
bootblock_mbr_elf_LDFLAGS = -T $(srcdir)/bootblock_mbr.ld

bootblock_ext2_elf_SOURCES = bootblock_ext2.s init.s disk.s misc.s video.s load.s
bootblock_ext2_elf_LDFLAGS = -T $(srcdir)/bootblock_ext2.ld

bootblock_fat_elf_SOURCES = bootblock_fat.s init.s disk.s misc.s video.s load.s
bootblock_fat_elf_LDFLAGS = -T $(srcdir)/bootblock_fat.ld

bootblock_mbr.$(OBJEXT) init.$(OBJEXT) load.$(OBJEXT): bootblock.inc
