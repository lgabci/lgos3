# LGOS3 loader, init
.arch i8086
.code16

.equ STACKSIZE,	0x1000			# stack size in bytes
.equ LOADERCFGPATHSIZE, 0x100		# loader config file path max length

.equ INT_VIDEO, 0x10			# video interrupt
.equ VID_TELETYPE, 0x0e			# write teletype output
.equ VID_GETCURMODE, 0x0f		# get current video mode

.section .text	# --------------------------------------------------------------
.globl start
start:


	cli					# disable interrupts
	movb	$0x80, %al			# disable NMI
	outb	%al, $0x70
	inb	$0x71, %al

	movw	%cs, %ax			# set segment regs.
	movw	%ds, %bx			# save old DS
	movw	%ax, %ds
	movw	%ax, %es
	movw	%ax, %ss
	movw	$stack + STACKSIZE, %sp		# set stack

	sti					# enable interrupts
	movb	$0x00, %al			# enable NMI
	outb	%al, $0x70
	inb	$0x71, %al

	movw	$.bss, %di			# clear bss
	movw	$_bssend + 1, %cx
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

	movw	$loadercfgpath, %di		# copy loaderpath
	movw	$LOADERCFGPATHSIZE - 1, %cx
	cld					# incerement index
	pushw	%ds
	movw	%bx, %ds
rep	movsb
	xorb	%al, %al			# tailing zero
	stosb					# if it not exists
	popw	%ds

	jmp	loadkernel			# jump to C source

.arch i8086
.Lno386:					# no 386 CPU found

	movb	$VID_GETCURMODE, %ah		# get current video mode and page
	xorb	%bh, %bh			# set to zero (if BIOS not set)
	int	$INT_VIDEO
	movb	%bh, vidpage			# store page

	cld					# increment index
	movw	$strno386, %si			# start of string
	call	.Lwrt
	jmp	_halt

.Lwrt:						# write zero terminated string
	movb	$VID_TELETYPE, %ah		# teletype output
	movb	vidpage, %bh			# video page
	movb	$0x7, %bl		# foreground color for graphics modes
.Lwrtchr:
	lodsb					# next char
	orb	%al, %al			# test ending zero
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
strno386:	.string "LGOS loader requires 80386 or better CPU."

.section .bss	# --------------------------------------------------------------

.globl stack	##
.lcomm stack, STACKSIZE				# stack

.globl loadercfgpath
.lcomm loadercfgpath, LOADERCFGPATHSIZE		# loader config file path

.globl dataseg
.lcomm dataseg, 2				# data segment (= all segments)
.lcomm vidpage, 1				# current video page
