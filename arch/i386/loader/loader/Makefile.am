AM_CFLAGS += -m16

bin_PROGRAMS = loader.elf

loader_elf_SOURCES = init.s console.c disk.c elf.c ext2.c fat.c lib.c loader.c multiboot.c
loader_elf_LDFLAGS = $(AM_LDFLAGS) -T $(srcdir)/loader.ld
loader_elf_LDADD = -lgcc
