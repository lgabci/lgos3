# i386 boot loader makefile

CCFLAGS += -m16

loader.elf: init.o console.o disk.o elf.o ext2.o fat.o lib.o loader.o \
             multiboot.o
