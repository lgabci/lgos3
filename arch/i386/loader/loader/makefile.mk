# i386 boot loader makefile

.PHONY: bootblock
bootblock: $(DESTDIR)/loader.elf

-include $(DESTDIR)/loader.elf.d

OBJS := $(DESTDIR)/init.o $(DESTDIR)/console.o \
  $(DESTDIR)/disk.o $(DESTDIR)/elf.o $(DESTDIR)/ext2.o $(DESTDIR)/fat.o \
  $(DESTDIR)/lib.o $(DESTDIR)/loader.o $(DESTDIR)/multiboot.o

$(OBJS): CCFLAGS += -m16

$(OBJS): | $(DESTDIR)

$(DESTDIR)/loader.elf: $(OBJS) $(SRCDIR)/loader.ld
