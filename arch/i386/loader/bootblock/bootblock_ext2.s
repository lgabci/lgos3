# LGOS3 loader boot block for Ext2

.include "bootblock.inc"

.section .text	# ------------------------------------------------------------
	call	load_ldr_2nd		# load and run 2nd stage loader

.section .data	# ------------------------------------------------------------
initstr:    .string "Ext2\r\n"
.global initstr
