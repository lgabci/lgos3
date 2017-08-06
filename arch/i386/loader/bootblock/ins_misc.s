# LGOS3 loader boot block, misc functions

.section .text	# --------------------------------------------------------------

stopfloppy:	# --------------------------------------------------------------
# stop floppy motor
# IN:	-
# OUT:	-
# MOD:	AL, DX
	xorb	%al, %al
	movw	$0x3f2, %dx
	outb	%al, %dx
	ret

stoperr:	# --------------------------------------------------------------
# wite error message and stops machine
# IN:	SI: pointer to error message
# OUT:	-
# MOD:	flags
	call	writestr
	call	stopfloppy		# stop floppy motors
1:
	hlt				# halt
	jmp	1b
