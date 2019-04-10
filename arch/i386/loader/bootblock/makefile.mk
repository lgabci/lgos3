# i386 boot loader makefile

CCFLAGS += -m16

$(info MKDIR $(MKDIR))

$(DESTDIR)bootblock_mbr.elf: $(MKDIR)bootblock_mbr.s $(MKDIR)init.inc $(MKDIR)disk.inc $(MKDIR)misc.inc $(MKDIR)video.inc | $(DESTDIR)
	$(CC) $(CCFLAGS) -o $@ $<

#bootblock_ext2.elf: bootblock_ext2.o init.inc disk.inc misc.inc video.inc load.inc
#bootblock_fat.elf: bootblock_fat.o init.inc disk.inc misc.inc video.inc load.inc

$(DESTDIR) :
	mkdir -p $@
