OUTPUT_ARCH(i386)
OUTPUT_FORMAT(elf32-i386)
ENTRY(start)

SECTIONS {
  .text : {
    *(.text_init)
    *(.text)
    *(.text.*)
  }

  .data : {
    *(.data)
  }

  .rodata : {
    *(.rodata)
    *(.rodata*)
  }

  .bss : {
    *(.bss)
    *(COMMON)
  }
  bssend = .;
}
