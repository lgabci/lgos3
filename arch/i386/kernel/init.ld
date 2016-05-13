OUTPUT_ARCH(i386)
OUTPUT_FORMAT(elf32-i386)
ENTRY(start)

LOAD_ADDR = 0x100000;
ENTRY_ADDR = start;

SECTIONS {
  .mbheader 0x0 : AT (LOAD_ADDR) {
    HEADER_ADDR = LOAD_ADDR + .;
    init.o(.mbheader)
  }

  .rmtext : {		/* real mode text	*/
    init.o(.rmtext)
  }

  .rmdata : {		/* real mode data	*/
    init.o(.rmdata)
  }

  .text LOAD_ADDR + ADDR(.rmdata) + SIZEOF(.rmdata) :
    AT (LOADADDR(.rmdata) + SIZEOF(.rmdata)) {
    *(.text)
  }

  .data : {
    *(.data)
  }

  .rodata : {
    *(.rodata)
    *(.rodata*)
  }

  LOAD_END_ADDR = .;

  .bss : {
    *(.bss)
    *(COMMON)
  }
  BSS_END_ADDR = .;
}
