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
# $(1) = variable name to push (using variable_c, variable_0, variable_1, ...)
push = \
$(eval temp_ := $(1)_$(words $(value $(1)_c))) \
$(eval $(1)_c := $(temp_) $(value $(1)_c)) \
$(eval $(temp_) := $(value $(1))) \
$(eval undefine temp_)

# pop
# $(1) = variable name to pop (using variable_c, variable_0, variable_1, ...)
pop = \
$(eval temp_ := $(firstword $(value $(1)_c))) \
$(eval $(1) := $(if $(temp_),$(value $(temp_)),)) \
$(eval $(if $(temp_),undefine $(temp_),)) \
$(eval $(1)_c := $(wordlist 2,$(words $(value $(1)_c)),$(value $(1)_c))) \
$(eval $(if $(value $(1)_c),,undefine $(1)_c)) \
$(eval undefine temp_)

# include function
# $(1) = include file name
include = \
$(call push,MKDIR) \
$(eval temp_ := $(abspath $(MKDIR)$(1))) \
$(eval MKDIR := $(dir $(temp_))) \
$(eval include $(temp_)) \
$(eval undefine temp_) \
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
