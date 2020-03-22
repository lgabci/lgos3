# LGOS3 loader boot block for FAT
.arch i8086
.code16

.section .itext, "ax"	# -----------------------------------------------------
	jmp	start			# jump over FAT BPB

.section .text	# ------------------------------------------------------------
.include "init.inc"

	call	load_ldr_2nd		# load and run 2nd stage loader

.include "disk.inc"
.include "load.inc"

.section .data	# -------------------------------------------------------------
initstr:    .string "boot\r\n"  ## TODO boot sector\r\n
