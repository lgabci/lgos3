bin_PROGRAMS = kernel.elf

kernel_elf_SOURCES = init.s initc.c descript.c paging.c
kernel_elf_LDFLAGS = $(AM_LDFLAGS) -T $(srcdir)/kernel.ld
kernel_elf_LDADD = -lgcc
