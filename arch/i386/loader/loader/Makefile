# i386 boot loader makefile
# this loader is for i386 only
ARCH := i386

AS := as
ASFLAGS := --32 -march=$(ARCH)

CC := gcc
CCFLAGS := -m32 -march=$(ARCH) -S -O2 -nostdlib -nostdinc -ffreestanding -std=c99 -pedantic -Werror -Wall -Wextra -Wunreachable-code -fomit-frame-pointer -fno-asynchronous-unwind-tables

LD := ld
LDFLAGS :=

.DELETE_ON_ERROR :
.SUFFIXES :
.PHONY : disasm clean

all : loader.bin

%.d : %.c
	@$(CC) -M $(CCFLAGS) $< | sed 's,\($*\)\.o[ :]*,\1.o $@ : ,g' > $@

loaderobjs := loader.o console.o lib.o disk.o ext2.o fat.o elf.o multiboot.o
ifneq ($(MAKECMDGOALS),clean)
include $(loaderobjs:.o=.d)
endif
loaderobjs := $(loaderobjs) init.o

%.s : %.c
	$(CC) $(CCFLAGS) -o $@ $<

%.o : %.s
	$(AS) $(ASFLAGS) -o $@ $<

loader.elf : $(loaderobjs)
	$(LD) $(LDFLAGS) -T $(patsubst %.elf,%.ld,$@) -Map=$(patsubst %.elf,%.map,$@) -o $@ $^
	chmod -x $@
	strip $@

loader.bin : loader.elf
	objcopy -O binary $< $@
	chmod -x $@

# disassemble loader -----------------------------------------------------------
disasm : loader.bin
	objdump -D -b binary -mi386 -Maddr16,data16 $< | less

# clean ------------------------------------------------------------------------
clean :
	rm -f *.d *.o *.elf *.bin *.map
