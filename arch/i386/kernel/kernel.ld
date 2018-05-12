OUTPUT_ARCH(i386)
OUTPUT_FORMAT(elf32-i386)
ENTRY(start32)

KERNEL_BOTTOM = 0xc0000000;

HEADER_ADDR = LOAD_ADDR + mbheader;
LOAD_ADDR = 0x100000;
LOAD_END_ADDR = LOAD_ADDR + dataend - KERNEL_BOTTOM;
BSS_END_ADDR = LOAD_ADDR + bssend - KERNEL_BOTTOM;
ENTRY_ADDR = start32;

SECTIONS {
			/* real mode text			*/
  .text16 0 : AT (LOAD_ADDR) {
    *(.text16)
  }

			/* real mode data			*/
  .data16 : {
    *(.data16)
  }
  d16end = . + 0x1000;

			/* protected mode code @ 1MB, non paged	*/
  .text32 LOAD_ADDR + d16end : AT (LOAD_ADDR + d16end) {
    *(.text32)
  }

			/* protected mode data @ 1MB, non paged */
  .data32 : {
    *(.data32)
  }
  d32end = .;

			/* protected mode code @ KERNEL_BOTTOM	*/
  .text KERNEL_BOTTOM - LOAD_ADDR + d32end : AT (d32end) {
    *(.text)
  }

			/* protected mode data @ KERNEL_BOTTOM	*/
  .data : {
    *(.data)
    *(.rodata)
    *(.rodata*)
  }
  dataend = .;
			/* protected mode data @ KERNEL_BOTTOM	*/
  .bss : {
    *(.bss)
    *(COMMON)
  }
  bssend = .;
}
