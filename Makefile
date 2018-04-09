# LGOS3 makefile

.SUFFIXES:
.DELETE_ON_ERROR:

ifndef _ARCH
_ARCH := $(shell uname -m)
ifneq (,$(filter $(_ARCH),i486 i586 i686))
_ARCH := i386
endif
endif
export _ARCH

.PHONY: all
all: emulator/qemu

MKFILE := $(abspath $(lastword $(MAKEFILE_LIST)))

ifeq ($(DESTDIR),)

SRCDIR = $(abspath $(dir $(MKFILE))/arch/$(_ARCH)/$(@D))
DESTDIR = $(abspath /tmp/lgos3/arch/$(_ARCH)/$(@D))

TARGETS :=
include $(shell find $(dir $(MKFILE)) -name makefile.pre)

MKFLAGS = SRCDIR=$(SRCDIR) DESTDIR=$(DESTDIR) -C $(DESTDIR) -f $(MKFILE)
MKFLAGS += --no-print-directory

$(TARGETS):
	@$(if $(wildcard $(DESTDIR)),,mkdir -p $(DESTDIR))
	@+$(MAKE) $(MKFLAGS) $(@F)

else

.SECONDARY:

VPATH := $(SRCDIR)

DEXT := .d # temp dep file extension
DEPEXT := .mk.d # dep file extension

define MKDEPFILE =
@cat $@$(DEXT) >$@$(DEPEXT)
@echo >>$@$(DEPEXT)
@sed -e 's/.*: *//;s/ *\\//;s/^ *//;s/ / :\n/g;/^$$/d;s/$$/ :/' $@$(DEXT) >>$@$(DEPEXT)
@rm $@$(DEXT)
endef

include $(abspath $(dir $(MKFILE))/arch/$(_ARCH)/makefile.mk)
include $(SRCDIR)/makefile.mk

include $(wildcard *$(DEPEXT))

%.o: %.c
	$(CC) $(CCFLAGS)
	$(MKDEPFILE)

%.o: %.s
	$(AS) $(ASFLAGS)
	$(MKDEPFILE)

# dependencies from makefile.mk files
%.elf:
	$(LD) $(LDFLAGS)
	chmod -x $@

%.bin: %.elf
	$(OBJCOPY) $(OBJCOPYFLAGS)
	chmod -x $@

endif

.PHONY: clean
clean:
	rm -rf $(DESTDIR)
