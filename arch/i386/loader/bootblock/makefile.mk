# i386 boot loader makefile

CCFLAGS += -m16

bootblock_mbr.elf: bootblock_mbr.o init.inc disk.inc misc.inc video.inc
bootblock_ext2.elf: bootblock_ext2.o init.inc disk.inc misc.inc video.inc load.inc
bootblock_fat.elf: bootblock_fat.o init.inc disk.inc misc.inc video.inc load.inc
