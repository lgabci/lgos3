# i386 makefile include

CC := i386-elf-gcc
CCFLAGS = -c -ffreestanding -nostdinc -O2 -pedantic -Werror -Wall -Wextra
CCFLAGS += -I$(SRCDIR) -MD -MF $@$(DEXT) -o $@ $<

AS := i386-elf-as
ASFLAGS = -I $(SRCDIR) --MD $@$(DEXT) -o $@ $<

LD := $(CC)
LDFLAGS = -nostdlib -ffreestanding -T $(SRCDIR)/$(@:.elf=.ld)
LDFLAGS += -Wl,-Map,$(@:.elf=.map) -o $@ $(filter %.o,$^)

OBJCOPY := i386-elf-objcopy
OBJCOPYFLAGS = -O binary $< $@

OBJDUMP := i386-elf-objdump

GDB := i386-elf-gdb
GDBFLAGS := -ex "target remote localhost:1234" -s ../loader/loader/loader.elf

QEMUDISK = -drive file=$<,if=ide,index=0,media=disk
QEMUDPAR = cyls=$(HDCYLS),heads=$(HDHEADS),secs=$(HDSECS),format=raw
QEMU := qemu-system-i386
QEMUFLAGS = -m 2 $(QEMUDISK),$(QEMUDPAR) -boot order=c -net none

QEMUFLOPPY = -fda $(SRCDIR)/grub.flp
QEMUFLAGS2 = -m 2 $(QEMUDISK),$(QEMUDPAR) $(QEMUFLOPPY) -boot order=a -net none

QEMUDBFLAGS := -s -S
