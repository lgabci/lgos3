OUTPUT_ARCH(i386)
OUTPUT_FORMAT(elf32-i386)
ENTRY(start)

MEMORY {
  ram  : ORIGIN = 0,     LENGTH = 0x1be
  bsgn : ORIGIN = 0x1fe, LENGTH = 2
  bss  : ORIGIN = 0x200, LENGTH = 0x200
}

SECTIONS {
  .text : ALIGN(1) {
    *(.text)
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
    *(COMMON)
  } >bss
}
