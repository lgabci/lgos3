OUTPUT_ARCH(i386)
OUTPUT_FORMAT(binary)
ENTRY(start)

SECTIONS {
  .text 0x0: {
    *(.text)
  }

  .data : ALIGN(1) {
    *(.data)
  }

  .bootsign 0x1fe: {
    BYTE(0x55)
    BYTE(0xaa)
  }

  .text2 : ALIGN(1) {
    *(.text2)
  }

  .data2 : ALIGN(1) {
    *(.data2)
  }

  .bss : ALIGN(0x200) {
    *(.bss)
  }

  . = ALIGN(0x10);
  bssend = .;

  .fileend 0x3ff: {
    BYTE(0x00)
  }
}
