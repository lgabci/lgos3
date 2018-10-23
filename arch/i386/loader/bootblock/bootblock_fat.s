# LGOS3 loader boot block for FAT
.arch i8086
.code16

.include "bootblock.inc"

.section .itext, "ax"	# -----------------------------------------------------
	jmp	start			# jump over FAT BPB

.section .text	# ------------------------------------------------------------
	call	load_ldr_2nd		# load and run 2nd stage loader

.section .data	# -------------------------------------------------------------
initstr:    .string "boot sector\r\n"
.global initstr
