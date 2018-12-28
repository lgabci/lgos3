data_DATA = lgos3.img

CLEANFILES = lgos3.img

imgsize = 100M

lgos3.img: ../loader/bootblock/bootblock_mbr.elf
	-$(RM) $@
<<<<<<< HEAD
	a=QQQ echo ddelf: $(DDELF)
#	$(DD) of=$@ bs=1 seek=$(imgsize) count=0 >/dev/null
=======
	echo DDELF $(DDELF)
	$(DD) of=$@ bs=1 seek=$(imgsize) count=0 >/dev/null
	-$(RM) $@
	rm -rf $@
>>>>>>> 8e7e8d0af2c278205eb5569172e97e5b4c5c243e
