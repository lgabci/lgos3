# i386 kernel init makefile
ARCH := i386

AS := i686-elf-as
ASFLAGS := --32 -march=$(ARCH)

CC := i686-elf-gcc
CCFLAGS := -m32 -march=$(ARCH) -S -O2 -nostdlib -nostdinc -ffreestanding -std=c99 -pedantic -Werror -Wall -Wextra -fomit-frame-pointer -fno-asynchronous-unwind-tables

LD := i686-elf-ld
LDFLAGS := -m elf_i386

COBJECTS := init.o paging.o descript.o
SOBJECTS := inits.o
KERNEL := init

.DELETE_ON_ERROR :
.SUFFIXES :
.PHONY : clean disasm

all : init.bin

%.d : %.c
	@$(CC) -M $(CCFLAGS) $< | sed 's,\($*\)\.o[ :]*,\1.o $@ : ,g' > $@

ifneq ($(MAKECMDGOALS),clean)
include $(COBJECTS:.o=.d)
endif

%.s : %.c
	$(CC) $(CCFLAGS) -o $@ $<

%.o : %.s
	$(AS) $(ASFLAGS) -o $@ $<

$(KERNEL).elf : $(SOBJECTS) $(COBJECTS)
	$(LD) $(LDFLAGS) -T $(patsubst %.elf,%.ld,$@) -Map=$(patsubst %.elf,%.map,$@) -o $@ $^
	chmod -x $@

$(KERNEL).bin : $(KERNEL).elf
	i686-elf-objcopy -O binary $< $@
	chmod -x $@

# disassemble kernel -----------------------------------------------------------
disasm : $(KERNEL).elf
	i686-elf-objdump -d $< | less

# clean ------------------------------------------------------------------------
clean :
	rm -f $(SOBJECTS) $(COBJECTS) $(COBJECTS:.o=.d) $(KERNEL).elf $(KERNEL).map $(KERNEL).bin
