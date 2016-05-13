# i386 qemu makefile
ARCH := i386
IMGTYPE := $(or $(MAKECMDGOALS),hd)
FSTYPE ?= fat
BOOTLDR ?= own

IMGFILE := /tmp/$(ARCH)_$(IMGTYPE)_$(FSTYPE)_$(BOOTLDR).img

TELNETADDR := 127.0.0.1
TELNETPORT := 1233
QEMU := qemu-system-i386
QEMUFLAGS := -m 2 -net none -serial none -parallel none -display curses -monitor telnet:$(TELNETADDR):$(TELNETPORT),server,nowait -no-reboot
SCREENFLAGS := -t qemu

LDRBINS := ../loader/bootblock/bootblock.bin ../loader/loader/loader.bin
LDRBINS := $(LDRBINS) ../loader/loader/loader.elf
ifeq ($(IMGTYPE),hd)
LDRBINS := $(LDRBINS) ../loader/bootblock/bootblock_mbr.bin
endif
ifeq ($(FSTYPE),fat)
LDRBINS := $(LDRBINS) ../loader/bootblock/bootblock_fat.bin
endif

KERNELBINS := ../kernel/init.bin ../kernel/init.elf

.DELETE_ON_ERROR :
.SUFFIXES :
.PHONY : fd hd clean

telnet := mp=0; while ! netcat -z -n $(TELNETADDR) $(TELNETPORT) && [ "$$mp" != 10 ]; do sleep 1; mp=$$((mp+1)); done; \
screen -t t telnet $(TELNETADDR) $(TELNETPORT)
killqemu := killall -w $(QEMU) 2>/dev/null || true

all : $(IMGTYPE)

$(IMGFILE) : $(LDRBINS) $(KERNELBINS)
	$(call killqemu)
	sudo ./mkdisk.sh $@ $(IMGTYPE) $(FSTYPE) $(BOOTLDR)

fd : $(IMGFILE)
	screen $(SCREENFLAGS) $(QEMU) -fda $(IMGFILE) -boot a $(QEMUFLAGS)
	$(call telnet)

hd : $(IMGFILE)
	screen $(SCREENFLAGS) $(QEMU) -drive file=$(IMGFILE),if=ide,bus=0,unit=0,$$(cat $(IMGFILE).geom),trans=lba -boot c $(QEMUFLAGS)
	$(call telnet)

bighd : hd

clean :
	$(call killqemu)
	bash -c 'rm -f /tmp/i386_{fd,hd}_{ext2,fat}_{grub,own}.img{.geom,}'
