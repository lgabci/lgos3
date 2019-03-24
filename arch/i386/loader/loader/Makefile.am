AM_CFLAGS += -m16

noinst_PROGRAMS = loader.elf loader.bin

loader_elf_SOURCES = init.s console.c disk.c elf.c ext2.c fat.c lib.c loader.c multiboot.c
loader_elf_LDFLAGS = $(AM_LDFLAGS) -T $(srcdir)/loader.ld
loader_elf_LDADD = $(LDADD) -lgcc

loader_bin_SOURCES =
loader_bin_DEPENDENCIES = loader.elf
loader_bin_LINK = $(OBJCOPY) -O binary $< $@
