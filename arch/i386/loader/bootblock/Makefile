# i386 boot loader makefile
# this loader is for i386 only
ARCH := i386

AS := as
ASFLAGS := --32 -march=$(ARCH)

LD := ld
LDFLAGS :=

.DELETE_ON_ERROR :
.SUFFIXES :
.PHONY : disasm clean

all : bootblock.bin bootblock_fat.bin bootblock_mbr.bin

# bootblock --------------------------------------------------------------------
bootblock.o : bootblock.s
	$(AS) $(ASFLAGS) -o $@ $<

bootblock.bin : bootblock.o
	$(LD) -T $(patsubst %.bin,%.ld,$@) -Map=$(patsubst %.bin,%.map,$@) -o $@ $^
	chmod -x $@

# bootblock for FAT ------------------------------------------------------------
bootblock_fat.o : bootblock_512.s
	$(AS) $(ASFLAGS) --defsym BOOTCODE=0 -o $@ $<

bootblock_fat.bin : bootblock_fat.o
	$(LD) -T $(patsubst %.bin,%.ld,$@) -Map=$(patsubst %.bin,%.map,$@) -o $@ $^
	chmod -x $@

# bootblock for MBR ------------------------------------------------------------
bootblock_mbr.o : bootblock_512.s
	$(AS) $(ASFLAGS) --defsym MBRCODE=0 -o $@ $<

bootblock_mbr.bin : bootblock_mbr.o
	$(LD) -T $(patsubst %.bin,%.ld,$@) -Map=$(patsubst %.bin,%.map,$@) -o $@ $^
	chmod -x $@

# disassemble loader -----------------------------------------------------------
disasm : bootblock.bin
	objdump -D -b binary -mi386 -Maddr16,data16 $< | less

# clean ------------------------------------------------------------------------
clean :
	rm -f *.bin *.o *.map
