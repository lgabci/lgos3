# LGOS3 makefile

ARCH ?= $(shell uname -m)
ifneq (, $(filter $(ARCH), i386 i486 i586 i686))
  ARCH := i386
endif
export ARCH

.DELETE_ON_ERROR :
.SUFFIXES :
.PHONY : fd hd debug loader disasm clean

all : hd

fd : loader
	$(MAKE) -C arch/$(ARCH)/qemu fd

hd : loader
	$(MAKE) -C arch/$(ARCH)/qemu hd

debug : loader
	$(MAKE) -C arch/$(ARCH)/qemu debug

disasm : loader
	$(MAKE) -C arch/$(ARCH)/loader disasm

clean :
	$(MAKE) -C arch/$(ARCH)/loader clean

loader :
	$(MAKE) -C arch/$(ARCH)/loader
