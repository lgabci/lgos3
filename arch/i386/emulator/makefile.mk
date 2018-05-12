# LGOS3 emulator makefile, pre-dependencies

HDCYLS := 1023
HDHEADS := 16
HDSECS := 63
HDSECSIZE := 512

HDSIZE := $$(($(HDCYLS) * $(HDHEADS) * $(HDSECS) * $(HDSECSIZE)))
HDPBLKSTART := 2048
HDPSTART := $$(($(HDPBLKSTART) * $(HDSECSIZE)))
HDPSIZE := $$((20480 * $(HDSECSIZE)))

# line feed
define LF :=


endef

# binary blocknum (from filefrag output)
define AWKBLK :=
{ if ($$0 ~ /^File size of/) {
    blknum = int(($$(NF - 5) + $$(NF - 1) - 1) / $$(NF - 1));
    if (blknum > BLKSZ / 4) {
      print "Too long blocklist." >"/dev/stderr";
      exit 1;
    };
    tail = (blknum < BLKSZ / 4);
  };
  if ($$1 ~ /^[[:digit:]]+:/) {
    for (i = $$4 + OFF; i <= $$5 + OFF && blknum > 0; i ++) {
      printf "%c%c%c%c", and(i, 0xff), and(rshift(i, 8), 0xff),
        and(rshift(i, 16), 0xff), and(rshift(i, 24), 0xff);
      blknum --;
    }
  }
}
END {
  if (tail) {
    printf "%c%c%c%c", 0, 0, 0, 0;
  }
}
endef
AWKBLK := '$(subst $(LF),,$(AWKBLK))'

# ELF program headers (from objdump output)
define AWKELF :=
{ if ($$1 == "LOAD") {
    if ($$5 != $$7) {
      print("Bad ELF file.");
      exit 1;
    }
    ioff = strtonum($$3);
    ooff = strtonum($$5);
  }
  if ($$1 == "filesz") {
    sz = strtonum($$2);
    if (sz > 0) {
      print(ioff " " sz " " ooff);
    }
  }
}
endef
AWKELF := '$(subst $(LF),,$(AWKELF))'

LOOPDEV := $(shell sudo losetup -f)
ifeq ($(LOOPDEV),)
$(error Can not find a loop device.)
endif

# call dd
# $(1): if
# $(2): of
# $(3): bs
# $(4): skip
# $(5): seek
# $(6): count
# $(7): conv
define dd =
$(if $(findstring */dev/,*$(2)),sudo ,)dd$(if $(1), if=$(1),)\
$(if $(2), of=$(2),)$(if $(3), bs=$(3),)$(if $(4), skip=$(4),)\
$(if $(5), seek=$(5),)$(if $(6), count=$(6))$(if $(7), conv=$(7),) status=none
endef

# copy ELF file contents to file
# $(1): ELF file
# $(2): output file
# $(3): tmp filek neve: $(3).tmp
define ddelf =
$(OBJDUMP) -p $(1) >$(3).tmp
awk -- $(AWKELF) $(3).tmp >$(3).tmp2
sort -n $(3).tmp2 | while read ioff sz ooff; do \
$(call dd,$(1),$(2),1,$$ioff,$$ooff,$$sz,notrunc); \
done
rm $(3).tmp $(3).tmp2
endef

qemu_img_hdd_ldr_ext2.img: ../loader/bootblock/bootblock_mbr.elf \
../loader/bootblock/bootblock_ext2.elf ../loader/loader/loader.bin \
../kernel/kernel.elf
	rm -f $@
	$(call dd,/dev/zero,$@,1,,$(HDSIZE),0,)
	$(call dd,$(SRCDIR)/mbr_hdd,$@,,,,,notrunc)
	$(call ddelf,../loader/bootblock/bootblock_mbr.elf,$@,$@)
	sudo losetup -o $(HDPSTART) --sizelimit $(HDPSIZE) $(LOOPDEV) $@
	sudo mkfs.ext2 $(LOOPDEV)
	mkdir -p $@.mnt
	sudo mount $(LOOPDEV) $@.mnt
	sudo chmod 777 $@.mnt
	mkdir -p $@.mnt/loader $@.mnt/kernel
	cp ../loader/loader/loader.bin $@.mnt/loader/
	cp ../kernel/kernel.elf $@.mnt/kernel/
	echo "hda1:/kernel/kernel.elf proba params x" >$@.mnt/loader/loader.cfg
	sudo filefrag -b512 -e -s $@.mnt/loader/loader.bin >loader.blk.tmp
	LANG=C; awk -- $(AWKBLK) OFF=$(HDPBLKSTART) BLKSZ=$(HDSECSIZE) \
loader.blk.tmp >$@.mnt/loader/loader.blk
	rm loader.blk.tmp
	sudo filefrag -b512 -e -s $@.mnt/loader/loader.blk >loader.blk.tmp
	LANG=C; awk -- $(AWKBLK) OFF=$(HDPBLKSTART) BLKSZ=4 loader.blk.tmp \
>loader.blk.tmp2
	$(call ddelf,../loader/bootblock/bootblock_ext2.elf,$(LOOPDEV),$@)
	SEEK=$$($(OBJDUMP) -t ../loader/bootblock/bootblock_ext2.elf | \
  awk -- '{if ($$(NF) == "ldrblk") {print $$1}}'); \
if [ -z "$$SEEK" ]; then echo "ldrblk not found in bootblock_ext2.elf" >&2; \
  exit 1; \
fi; \
$(call dd,loader.blk.tmp2,$(LOOPDEV),1,,$$((0x$$SEEK)),,notrunc)
	SEEK=$$($(OBJDUMP) -t ../loader/loader/loader.elf | \
  awk -- '{if ($$(NF) == "ldrcfgpath") {print $$1}}'); \
if [ -z "$$SEEK" ]; \
  then echo "ldrcfgpath not found in loader.elf" >&2; \
  exit 1; \
fi; \
printf "%s\0" "hda1:/loader/loader.cfg" | \
  $(call dd,,$@.mnt/loader/loader.bin,1,,$$((0x$$SEEK)),,notrunc)
	rm loader.blk.tmp loader.blk.tmp2
	sudo umount $@.mnt
	sudo losetup -d $(LOOPDEV)

qemu_img_hdd_grub_ext2.img: ../kernel/kernel.elf
	rm -f $@
	$(call dd,/dev/zero,$@,1,,$(HDSIZE),0,)
	$(call dd,$(SRCDIR)/mbr_hdd,$@,,,,,notrunc)
	sudo losetup -o $(HDPSTART) --sizelimit $(HDPSIZE) $(LOOPDEV) $@
	sudo mkfs.ext2 $(LOOPDEV)
	mkdir -p $@.mnt
	sudo mount $(LOOPDEV) $@.mnt
	sudo chmod 777 $@.mnt
	mkdir -p $@.mnt/loader $@.mnt/kernel
	cp ../kernel/kernel.elf $@.mnt/kernel/
	sudo umount $@.mnt
	sudo losetup -d $(LOOPDEV)

.PHONY: qemu
qemu: qemu_img_hdd_ldr_ext2.img
	$(QEMU) $(QEMUFLAGS)

.PHONY: qemu2
qemu2: qemu_img_hdd_grub_ext2.img
	$(QEMU) $(QEMUFLAGS2)

.PHONY: debug
debug: qemu_img_hdd_ldr_ext2.img
	$(QEMU) $(QEMUFLAGS) $(QEMUDBFLAGS) &
	$(GDB) $(GDBFLAGS)
