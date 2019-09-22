# LGOS3 makefile

.SUFFIXES:
.DELETE_ON_ERROR:

# set architecture
ifndef ARCH
ARCH := $(shell uname -m)
ifneq (,$(filter $(ARCH),i486 i586 i686))
ARCH := i386
endif
endif
export ARCH

DEXT := .d

# macro to remove last slash from a path
define rs
$(patsubst %/,%,$(1))
endef

# set source and destination path
SRCDIR := $(call rs,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
DESTDIR := /tmp/lgos3

MKDIRS := $(DESTDIR)

all: $(ARCH) | $(DESTDIR)

.PHONY: clean
clean:
	rm -rf $(DESTDIR)

$(DESTDIR)/%.o: $(SRCDIR)/%.s
	$(AS) $(ASFLAGS) -o $@ $<

$(DESTDIR)/%.o: $(SRCDIR)/%.c
	$(CC) $(CCFLAGS) -o $@ $<

$(DESTDIR)/%.elf:
	$(LD) $(LDFLAGS)
	chmod -x $@
	echo $(SRCDIR) " --> " $(DESTDIR)

$(DESTDIR)/%.bin: $(DESTDIR)/%.elf
	$(OBJCOPY) $(OBJCOPYFLAGS) $< $@

# macro to include a list of makefiles
define make_include
$(foreach a,$(1),$(eval
  SRCDIR := $(call rs,$(dir $(SRCDIR)/$(a)))
  DESTDIR := $(call rs,$(dir $(DESTDIR)/$(a)))
  MKDIRS += $(call rs,$(dir $(DESTDIR)/$(a)))
  include $(SRCDIR)/$(a)
  SRCDIR := $(SRCDIR)
  DESTDIR := $(DESTDIR)
))
endef

$(call make_include,arch/$(ARCH)/makefile.mk)

$(MKDIRS):
	mkdir -p $@
