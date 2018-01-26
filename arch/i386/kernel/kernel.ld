OUTPUT_ARCH(i386)
OUTPUT_FORMAT(elf32-i386)
ENTRY(start32)

PAGE_SIZE = 0x1000;
PDIR32 = 0x100000;
PTBL32 = PDIR32 + PAGE_SIZE;
PTBLPG = PTBL32 + PAGE_SIZE;

LOAD_ADDR = PTBLPG + PAGE_SIZE;
KERNEL_BOTTOM = 0xc0000000;
ENTRY_ADDR = start32;

SECTIONS {
  .mbheader 0x0 : AT (LOAD_ADDR) {
    *(.mbheader)
  }

			/* real mode text			*/
  .text16 ADDR(.mbheader) + SIZEOF(.mbheader) : {
    *(.text16)
  }

			/* real mode data			*/
  .data16 ADDR(.text16) + SIZEOF(.text16) : {
    *(.data16)
  }

			/* protected mode code @ 1MB		*/
  .text32 (LOAD_ADDR + ADDR(.data16) + SIZEOF(.data16) + 0x1000 - 1) & ~ (0x1000 - 1) :
    AT ((LOADADDR(.data16) + SIZEOF(.data16) + 0x1000 - 1) & ~ (0x1000 - 1)) {
    *(.text32)
  }

			/* protected mode data @ 1MB		*/
  .data32 ADDR(.text32) + SIZEOF(.text32) : {
    *(.data32)
  }

	/* unpaged code + data: phys addr, lin addr, size, pages	*/
  .text KERNEL_BOTTOM :	/* protected mode code @ KERNEL_BOTTOM	*/
    AT ((ADDR(.data32) + SIZEOF(.data32) + 0x1000 - 1) & ~ (0x1000 - 1)) {
    *(.text)
  }

			/* protected mode data @ KERNEL_BOTTOM	*/
  .data (ADDR(.text) + SIZEOF(.text) + 0x1000 - 1) & ~ (0x1000 - 1) : {
    *(.data)
    *(.rodata)
    *(.rodata*)
  }

			/* protected mode data @ KERNEL_BOTTOM	*/
  .bss ADDR(.data) + SIZEOF(.data) : {
    *(.bss)
    *(COMMON)
  }
}

  HEADER_ADDR = LOAD_ADDR + ADDR(.mbheader);
  LOAD_END_ADDR = LOADADDR(.data) + SIZEOF(.data);
  BSS_END_ADDR = LOAD_END_ADDR + SIZEOF(.bss);
			/* copy this many bytes above 1MB	*/
  CP_FROM = ADDR(.text32) - LOAD_ADDR;
  CP_TO = LOADADDR(.text32);
  CP_SIZE = LOAD_END_ADDR - CP_TO;

  PG_WX_PHYS = PDIR32;			/* paging		*/
  PG_WX_LIN = PDIR32;
  PG_WX_SIZE = ADDR(.data32) + SIZEOF(.data32) - PDIR32;

  PG_X_PHYS = LOADADDR(.text);
  PG_X_LIN = ADDR(.text);
  PG_X_SIZE = SIZEOF(.text);

  PG_W_PHYS = LOADADDR(.data);
  PG_W_LIN = ADDR(.data);
  PG_W_SIZE = ADDR(.bss) + SIZEOF(.bss) - ADDR(.data);

