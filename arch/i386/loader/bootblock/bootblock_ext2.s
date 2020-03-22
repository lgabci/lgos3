# LGOS3 loader boot block for Ext2

.section .text	# ------------------------------------------------------------
.include "init.inc"

	call	load_ldr_2nd		# load and run 2nd stage loader

.include "disk.inc"
.include "load.inc"

.section .data	# ------------------------------------------------------------
initstr:    .string "Ext2\r\n"
