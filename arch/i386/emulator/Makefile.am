data_DATA = lgos3.img

CLEANFILES = lgos3.img

imgsize = 100M
mbr = ../loader/bootblock/bootblock_mbr.elf

lgos3.img: $(mbr)
	OBJDUMP=$(OBJDUMP); AWK=$(AWK); DD=$(DD); export OBJDUMP AWK DD; $(srcdir)/objcopy.sh $@ $(mbr) 0
