noinst_PROGRAMS = lgos3.img

lgos3_img_SOURCES =
lgos3_img_DEPENDENCIES = ../loader/bootblock/bootblock_mbr.bin ../loader/bootblock/bootblock_ext2.bin ../loader/loader/loader.bin ../kernel/kernel.elf

lgos3_img_LINK = $(srcdir)/mkimg.sh $@ $^
