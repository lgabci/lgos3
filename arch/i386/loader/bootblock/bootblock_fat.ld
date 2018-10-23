OUTPUT_ARCH(i386)
OUTPUT_FORMAT(elf32-i386)
ENTRY(start)

MEMORY {
  iram : ORIGIN = 0,     LENGTH = 0x3
  ram  : ORIGIN = 0x5a,  LENGTH = 0x1a4
  bsgn : ORIGIN = 0x1fe, LENGTH = 2
  bss  : ORIGIN = 0x200, LENGTH = 0x200
}

SECTIONS {
  /* jump over FAT BPB */
  .itext : {
    *(.itext)
  } >iram

  .text : {
    init.o(.text)
    bootblock_fat.o(.text)
    disk.o(.text)
    misc.o(.text)
    video.o(.text)
    load.o(.text)
  } >ram

  .data : ALIGN(1) {
    *(.data)
  } >ram

  .bootsign : {
    BYTE(0x55)
    BYTE(0xaa)
  } >bsgn

  .bss : {
    *(.bss)
  } >bss
}
