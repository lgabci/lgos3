# LGOS3 loader boot block for Ext2
.arch i8086
.code16

.section .text	# ------------------------------------------------------------

.global main
main:
	call	load_ldr_2nd		# load and run 2nd stage loader

.section .data	# ------------------------------------------------------------
.globl initstr
initstr:    .string "Ext2\r\n"
