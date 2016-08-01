# i386 kernel init makefile
ARCH := i386

AS := as
ASFLAGS := --32 -march=$(ARCH)

CC := gcc
CCFLAGS := -m32 -march=$(ARCH) -S -O2 -nostdlib -nostdinc -ffreestanding -std=c99 -pedantic -Werror -Wall -Wextra -fomit-frame-pointer -fno-asynchronous-unwind-tables

LD := ld
LDFLAGS := -m elf_i386

.DELETE_ON_ERROR :
.SUFFIXES :
.PHONY : clean disasm

all : init.bin

%.o : %.s
	$(AS) $(ASFLAGS) -o $@ $<

init.elf : init.o
	$(LD) $(LDFLAGS) -T $(patsubst %.elf,%.ld,$@) -Map=$(patsubst %.elf,%.map,$@) -o $@ $^
	chmod -x $@

init.bin : init.elf
	objcopy -O binary $< $@
	chmod -x $@

# disassemble kernel -----------------------------------------------------------
disasm : init.bin
	objdump -D -b binary -mi386 -Maddr16,data16 $< | less

# clean ------------------------------------------------------------------------
clean :
	rm -f *.o *.elf *.bin *.map
