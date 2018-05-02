OUTPUT_ARCH(i386)
OUTPUT_FORMAT(elf32-i386)
ENTRY(start32)

LOAD_ADDR = 0x100000;
KERNEL_BOTTOM = 0xc0000000;

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
/*  .text32 (LOAD_ADDR + ADDR(.data16) + SIZEOF(.data16) + 0x1000 - 1) & ~ (0x1000 - 1) :
    AT ((LOADADDR(.data16) + SIZEOF(.data16) + 0x1000 - 1) & ~ (0x1000 - 1)) {
*/
  .text32 : {
    *(.text32)
  }

			/* protected mode data @ 1MB		*/
/*  .data32 ADDR(.text32) + SIZEOF(.text32) : {
*/
  .data32 : {
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
