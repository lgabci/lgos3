# LGOS3 loader boot block for Ext2
.arch i8086
.code16

.section .text	# ------------------------------------------------------------
.include "init.inc"

	call	load_ldr_2nd		# load and run 2nd stage loader

.section .data	# ------------------------------------------------------------
initstr:    .string "Ext2\r\n"
