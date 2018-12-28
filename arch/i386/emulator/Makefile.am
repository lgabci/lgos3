data_DATA = lgos3.img

CLEANFILES = lgos3.img

imgsize = 100M

lgos3.img: ../loader/bootblock/bootblock_mbr.elf
	-$(RM) $@
	echo DDELF $(DDELF)
	$(DD) of=$@ bs=1 seek=$(imgsize) count=0 >/dev/null
	-$(RM) $@
	rm -rf $@
