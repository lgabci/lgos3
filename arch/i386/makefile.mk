# i386 makefile include

CC := i686-elf-gcc
CCFLAGS = -c -ffreestanding -nostdinc -O2 -pedantic -Werror -Wall -Wextra
CCFLAGS += -std=c99 -I$(call rs,$(dir $<)) -MD -MF $@$(DEXT)

AS := i686-elf-as
ASFLAGS = -I $(call rs,$(dir $<)) --MD $@$(DEXT)

LD := $(CC)
LDFLAGS = -nostdlib -ffreestanding -T $(filter %.ld,$^)
LDFLAGS += -Wl,-Map,$(@:.elf=.map) -o $@ $(filter %.o,$^)

OBJCOPY := i686-elf-objcopy
OBJCOPYFLAGS = -O binary $< $@

OBJDUMP := i686-elf-objdump

GDB := i686-elf-gdb
GDBFLAGS := -ex "target remote localhost:1234" -s ../loader/loader/loader.elf

QEMUDISK = -drive file=$<,if=ide,index=0,media=disk
QEMUDPAR = cyls=$(HDCYLS),heads=$(HDHEADS),secs=$(HDSECS),format=raw
QEMU := qemu-system-i386
QEMUFLAGS = -m 2 $(QEMUDISK),$(QEMUDPAR) -boot order=c -net none -d guest_errors
QEMUDBFLAGS := -s -S

PHONY: $(ARCH)
$(ARCH): loader kernel emulator

$(call make_include,loader/makefile.mk kernel/makefile.mk emulator/makefile.mk)
