AM_CFLAGS = -ffreestanding -nostdinc -pedantic -Werror -Wall -Wextra -m16

bin_PROGRAMS = bootblock_mbr.elf bootblock_ext2.elf bootblock_fat.elf

bootblock_mbr_elf_SOURCES: bootblock_mbr.s init.inc disk.inc misc.inc video.inc
bootblock_mbr_elf_LDFLAGS = -T $(srcdir)/bootblock_mbr_elf.ld

bootblock_ext2_elf_SOURCES: bootblock_ext2.s init.inc disk.inc misc.inc video.inc load.inc
bootblock_ext2_elf_LDFLAGS = -T $(srcdir)/bootblock_ext2.ld

bootblock_fat_elf_SOURCES: bootblock_fat.s init.inc disk.inc misc.inc video.inc load.inc
bootblock_fat_elf_LDFLAGS = -T $(srcdir)/bootblock_fat.ld
