# LGOS3 loader boot block for FAT
.arch i8086
.code16

.section .itext, "ax"	# -----------------------------------------------------
	jmp	start			# jump over FAT BPB

.section .text	# ------------------------------------------------------------

	call	load_ldr_2nd		# load and run 2nd stage loader

.section .data	# -------------------------------------------------------------
.globl initstr
initstr:    .string "boot\r\n"  ## TODO boot sector\r\n
