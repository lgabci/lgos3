# i386 boot loader makefile

#CCFLAGS += -m16

#loader.elf: init.o console.o disk.o elf.o ext2.o fat.o lib.o loader.o \
             multiboot.o

.PHONY: bootblock
bootblock: $(DESTDIR)/loader.elf

-include $(DESTDIR)/loader.elf.d

$(DESTDIR)/init.o $(DESTDIR)/console.o \
  $(DESTDIR)/disk.o $(DESTDIR)/elf.o $(DESTDIR)/ext2.o $(DESTDIR)/fat.o \
  $(DESTDIR)/lib.o $(DESTDIR)/loader.o $(DESTDIR)/multiboot.o \
  $(SRCDIR)/loader.ld: | $(DESTDIR)

$(DESTDIR)/loader.elf: $(DESTDIR)/init.o $(DESTDIR)/console.o \
  $(DESTDIR)/disk.o $(DESTDIR)/elf.o $(DESTDIR)/ext2.o $(DESTDIR)/fat.o \
  $(DESTDIR)/lib.o $(DESTDIR)/loader.o $(DESTDIR)/multiboot.o \
  $(SRCDIR)/loader.ld
