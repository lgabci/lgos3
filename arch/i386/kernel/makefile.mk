# i386 kernel init makefile
KERNEL_ELF := $(DESTDIR)/kernel.elf

-include $(KERNEL_ELF)$(DEXT)

OBJS := $(DESTDIR)/init.o $(DESTDIR)/initc.o $(DESTDIR)/paging.o \
  $(DESTDIR)/descript.o

$(OBJS): | $(DESTDIR)

.PHONY: kernel
kernel: $(KERNEL_ELF)

$(KERNEL_ELF): $(OBJS) $(SRCDIR)/kernel.ld
