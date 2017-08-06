# i386 boot loader makefile
# this loader is for i386 only
ARCH := i386

AS := i686-elf-as
ASFLAGS := --32 -march=$(ARCH) --fatal-warnings

LD := i686-elf-ld
LDFLAGS := --fatal-warnings

.DELETE_ON_ERROR :
.SUFFIXES :
.PHONY : disasm clean
.SECONDARY : bootblock_mbr.elf bootblock_ext2.elf bootblock_fat.elf

all : bootblock_mbr.bin bootblock_ext2.bin bootblock_fat.bin

bootblock_mbr.o : bootblock_mbr.s ins_disk.s ins_init.s ins_misc.s ins_video.s
	$(AS) $(ASFLAGS) -o $@ $<

bootblock_ext2.o : bootblock_ext2.s ins_disk.s ins_init.s ins_misc.s ins_video.s ins_load.s
	$(AS) $(ASFLAGS) -o $@ $<

bootblock_fat.o : bootblock_fat.s ins_disk.s ins_init.s ins_misc.s ins_video.s ins_load.s
	$(AS) $(ASFLAGS) -o $@ $<

bootblock_%.elf : bootblock_%.o
	$(LD) $(LDFLAGS) -T $(patsubst %.elf,%.ld,$@) -Map=$(patsubst %.elf,%.map,$@) -o $@ $^
	chmod -x $@

bootblock_%.bin : bootblock_%.elf
	i686-elf-objcopy -O binary $< $@
	chmod -x $@

# disassemble loader -----------------------------------------------------------
disasm : bootblock_ext2.bin
	i686-elf-objdump -D -b binary -mi386 -Maddr16,data16 $<

# clean ------------------------------------------------------------------------
clean :
	bash -c 'rm -f bootblock_{mbr,ext2,fat}.{o,elf,bin,map}'
