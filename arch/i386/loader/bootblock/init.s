# LGOS3 loader boot block init
.arch i8086
.code16

.include "bootblock.inc"

.equ	CODESIZE,	0x200		# code size of boot sector
.equ	STACKSIZE,	0x180		# stack size

.section .text	# ------------------------------------------------------------
.global start
start:
	cli				# disable interrupts

	movw	$BIOSSEG, %ax		# set segment registers
	movw	%ax, %ds		# and copy bootblock to 0060:0000

	movw	$BBSEG, %ax
	movw	%ax, %es
	movw	%ax, %ss
	movw	$stack + STACKSIZE, %sp

	sti				# enable interrupts

	xorw	%si, %si		# copy
	xorw	%di, %di
	movw	$CODESIZE >> 1, %cx	# copy words
	cld				# increment index
rep	movsw

	movw	%ax, %ds		# set DS to data segment
	ljmp	$BBSEG, $1f		# set CS
1:		# CS, DS, ES and SS are set to common code + data segment

	movb	%dl, drive		# BIOS disk ID

	movw	$initstr, %si		# write init message
	call	writestr

	call	disk_getprm		# get disk parameters

.section .bss	# --------------------------------------------------------------
.lcomm	stack, STACKSIZE		# stack
