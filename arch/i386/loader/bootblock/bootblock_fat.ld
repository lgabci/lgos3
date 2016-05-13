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
}
