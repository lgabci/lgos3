# i386 boot loader makefile
# this loader is for i386 only
ARCH := i386

.DELETE_ON_ERROR :
.SUFFIXES :
.PHONY : clean disasm

DIRS := bootblock loader

all :
	$(foreach dir, $(DIRS), $(MAKE) -C $(dir) &&) :

# disassemble loader -----------------------------------------------------------
disasm :
	$(MAKE) -C loader disasm

# clean ------------------------------------------------------------------------
clean :
	$(foreach dir, $(DIRS), $(MAKE) -C $(dir) clean &&) :
