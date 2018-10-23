# LGOS3 loader boot block, video rutins
.arch i8086
.code16

.include "bootblock.inc"
.include "bootblock.inc"

.equ	INT_VIDEO,	0x10		# video interrupt
.equ	VID_WRITETT,	0x0e		# write teletype output

.section .text	# --------------------------------------------------------------

		# --------------------------------------------------------------
# write a string to the screen
# IN:	SI = pointer to zero terminated string
# OUT:	-
# MOD:	AX, BX, BP (BIOS bug), flags
1:
	int	$INT_VIDEO
writestr:
.global writestr
	movb	$VID_WRITETT, %ah	# write teletype output
	xorw	%bx, %bx		# page 0, foreground color 0 (graph)
	cld				# increment
	lodsb				# next char
	cmpb	$0, %al			# terminating zero?
	jne	1b			# no, write char
	ret				# yes, return
