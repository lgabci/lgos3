# LGOS3 loader, init
.arch i8086
.code16

.equ STACKSIZE,	0x400			# stack size in bytes (last 4 bits = 0)

.equ INT_VIDEO, 0x10			# video interrupt
.equ VID_TELETYPE, 0x0e			# write teletype output
.equ VID_GETCURMODE, 0x0f		# get current video mode

.equ INT_GETRAMSIZE, 0x12		# get RAM size in AX

.extern bssend

.section .text_init, "ax", @progbits	# --------------------------------------
			# init .text section

.globl start
start:
	cli					# disable interrupts
	movw	%cs, %ax			# set segment regs.
	movw	%ax, %ds
	movw	%ax, %es
	subw	$0x10, %ax			# set up temp stack
	movw	%ax, %ss			# 256 byte, below program
	movw	$0x100, %sp
	sti					# enable interrupts

	int	$INT_GETRAMSIZE			# get RAM size in KB
	movw	$0x400, %bx
	mulw	%bx
	movw	%ax, ramsize
	movw	%dx, ramsize + 2

	movw	%ds, %ax			# DX:AX = phys addr of bssend
	movw	$0x10, %bx
	mulw	%bx
	addw	$bssend, %ax
	adcw	$0, %dx

	cmpw	ramsize + 2, %dx		# check if bssend is in RAM
	jb	1f
	cmpw	ramsize, %ax
	jb	1f

	movw	$strnoram, %si			# not enough RAM
	call	.Lwrt
	jmp	_halt
1:
	movw	%ds, %ax			# set stack
	cli
	movw	%ax, %ss
	movw	$stack + STACKSIZE, %sp
	sti

	movw	$.bss, %di			# clear bss
	movw	$bssend + 1, %cx
	subw	%di, %cx
	cld					# increment index
	xorb	%al, %al
	rep	stosb

	movw	%ds, dataseg

	pushfw		# check 80386 before use fs, gs, 32bit registers
	popw	%ax				# get FLAGS
	andw	$0x0fff, %ax			# clear bits 12-15
	pushw	%ax
	popfw					# set FLAGS
	pushfw
	popw	%ax				# get FLAGS
	andw	$0xf000, %ax			# clear bits 0-11
	cmpw	$0xf000, %ax			# test bits 12-15
	je	.Lno386				# if bits 12-15 set, then 8086

.arch i286					# 80286 or better CPU
	pushfw
	popw	%ax				# get FLAGS
	orw	$0xf000, %ax			# set bits 12-15
	pushw	%ax
	popfw					# set FLAGS
	pushfw
	popw	%ax				# get FLAGS
	andw	$0xf000, %ax			# clear bits 0-11
	jz	.Lno386				# if bits 12-15 clear, then 286

.arch i386					# 80386 or better CPU
	movw	%ds, %ax			# set FS, GS segment registers
	movw	%ax, %fs
	movw	%ax, %gs

	jmp	loadkernel			# jump to C source

.arch i8086
.Lno386:					# no 386 CPU found

	movw	$strno386, %si			# start of string
	call	.Lwrt
	jmp	_halt

.Lwrt:						# write zero terminated string
	movb	$VID_GETCURMODE, %ah		# get current video mode and page
	xorb	%bh, %bh			# set to zero (if BIOS not set)
	int	$INT_VIDEO			# BH = video page

	movb	$VID_TELETYPE, %ah		# teletype output
	movb	$0x7, %bl		# foreground color for graphics modes
	cld					# increment index
.Lwrtchr:
	lodsb					# next char
	testb	%al, %al			# test ending zero
	jz	.Lwrtend
	int	$INT_VIDEO			# write char
	jmp	.Lwrtchr
.Lwrtend:
	ret

.globl _halt
_halt:
	call	_stopfloppy			# stop floppy motors
	cli					# disbale interrupts
.Lhlt:
	hlt					# halt CPU
	jmp	.Lhlt

.globl _stopfloppy
_stopfloppy:					# stop floppy motors
	xorb	%al, %al
	movw	$0x3f2, %dx
	outb	%al, %dx
	ret

.section .data	# --------------------------------------------------------------
.globl ramsize
ramsize:	.hword 0, 0			# RAM size in bytes

strno386:	.string "LGOS loader requires 80386 or better CPU."
strnoram:	.string "Not enough memory."

.section .bss	# --------------------------------------------------------------

.lcomm stack, STACKSIZE				# stack

.globl dataseg
.lcomm dataseg, 2				# data segment (= all segments)
