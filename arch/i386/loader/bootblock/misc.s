# LGOS3 loader boot block, misc functions
.arch i8086
.code16

.include "bootblock.inc"

.section .text	# --------------------------------------------------------------

stopfloppy:	# --------------------------------------------------------------
.global stopfloppy
# stop floppy motor
# IN:	-
# OUT:	-
# MOD:	AL, DX
	xorb	%al, %al
	movw	$0x3f2, %dx
	outb	%al, %dx
	ret

stoperr:	# --------------------------------------------------------------
.global stoperr
# wite error message and stops machine
# IN:	SI: pointer to error message
# OUT:	-
# MOD:	flags
	call	writestr
	call	stopfloppy		# stop floppy motors
1:
	hlt				# halt
	jmp	1b
