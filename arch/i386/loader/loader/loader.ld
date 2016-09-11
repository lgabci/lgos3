OUTPUT_ARCH(i386)
OUTPUT_FORMAT(elf32-i386)
ENTRY(start)

SECTIONS {
  .text 0x0: {
    init.o(.text*)
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
