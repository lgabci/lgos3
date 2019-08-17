# i386 boot loader makefile
LOADER_ELF := $(DESTDIR)/loader.elf

-include $(LOADER_ELF)$(DEXT)

OBJS := $(DESTDIR)/init.o $(DESTDIR)/console.o \
  $(DESTDIR)/disk.o $(DESTDIR)/elf.o $(DESTDIR)/ext2.o $(DESTDIR)/fat.o \
  $(DESTDIR)/lib.o $(DESTDIR)/loader.o $(DESTDIR)/multiboot.o

$(OBJS): | $(DESTDIR)

$(OBJS): CCFLAGS += -m16

.PHONY: bootblock
bootblock: $(LOADER_ELF)

$(LOADER_ELF): $(OBJS) $(SRCDIR)/loader.ld
