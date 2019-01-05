data_DATA = lgos3.img

CLEANFILES = lgos3.img

imgsize = 100M
mbr = ../loader/bootblock/bootblock_mbr.elf

lgos3.img: $(mbr)
	$(DD) of=$@ bs=1 seek=$(imgsize) count=0 >/dev/null
	OBJDUMP=$(OBJDUMP); AWK=$(AWK); export OBJDUMP AWK; $(srcdir)/objcopy.sh $@ $(mbr) 0
