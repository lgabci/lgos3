# LGOS3 makefile

.SUFFIXES:
.DELETE_ON_ERROR:

# set architecture
ifndef _ARCH
_ARCH := $(shell uname -m)
ifneq (,$(filter $(_ARCH),i486 i586 i686))
_ARCH := i386
endif
endif
export _ARCH

DEXT := .d

# push
# $(1) = variable name to push (into a list of variable_)
push = \
$(eval $(1)_ := $(value $(1)_) $(value $(1)))

# pop
# $(1) = variable name to pop (from a list of variable_)
pop = \
$(eval $(1) := $$(lastword $(value $(1)_))) \
$(eval $(1)_ := $$(filter-out $(value $(1)),$(value $(1)_)))

# include function
# $(1) = include file name
include = \
$(call push,MKDIR) \
$(eval temp_ := $(abspath $(MKDIR)$(1))) \
$(eval MKDIR := $(dir $(temp_))) \
$(eval include $(temp_)) \
$(call pop,MKDIR)

# set source and destination path
MKDIRBASE := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
MKDIR := $(MKDIRBASE)
ifeq (,$(DESTDIRBASE))
DESTDIRBASE := /tmp/lgos3/
endif
DESTDIR = $(subst $(MKDIRBASE),$(DESTDIRBASE),$(MKDIR))


$(call include,arch/$(_ARCH)/makefile.mk)





all: | $(DESTDIR)


$(DESTDIR):
	mkdir -p $@

.PHONY: clean
clean:
	rm -rf $(DESTDIR)
