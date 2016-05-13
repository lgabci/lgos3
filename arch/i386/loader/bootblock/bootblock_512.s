# LGOS3 loader boot block for MBR and FAT, 512 bytes length
.arch i8086
.code16

.ifdef BOOTCODE				# test BOOTCODE || MBRCODE
.else
.ifdef MBRCODE
.else
.error "Nor BOOTCODE nor MBRCODE specified"
.endif
.endif

.equ	BIOSSEG,	0x07c0		# BIOS boot block segment
.equ	BBSEG, 		0x0060		# move boot block segment here
.equ	CODESIZE,	0x200		# code size of boot sector
.equ	STACKSIZE,	0x200		# stack size

.equ	DIRENTRYSIZE,	0x20		# FAT directory entry size

.equ	INT_VIDEO,	0x10		# video interrupt
.equ	VID_WRITETT,	0x0e		# write teletype output

.equ	INT_DISK,	0x13		# disk interrupt
.equ	DISK_RESET,	0x00		# reset disk
.equ	DISK_GETSTAT,	0x01		# get status of last operation
.equ	DISK_READ,	0x02		# read sectors
.equ	DISK_GETPRM,	0x08		# get disk parameters

.equ	DISK_RETRY,	5		# retry counts for read

.equ	BOOTSIGN,	0xaa55		# boot sector signature

.section .text	# --------------------------------------------------------------
.globl start
start:

.ifdef BOOTCODE				# compile only in boot sector code
	jmp	bootcodestart		# jump over BPB
.org	3, 0x90				# pad to offset 3

.globl	bootdatastart
bootdatastart:				# start of boot sector data area

.space	0x57, 0				# space for boot parameter block

.globl	bootcodestart
bootcodestart:				# start of boot sector code
.endif	# BOOTCODE

	cli				# disable interrupts
	movb	$0x80, %al		# disable NMI
	outb	%al, $0x70
	inb	$0x71, %al

	movw	$BIOSSEG, %ax		# set segment registers
	movw	%ax, %ds		# and copy bootblock to 0060:0000

	movw	$BBSEG, %ax
	movw	%ax, %es
	movw	%ax, %ss
	movw	$stack + STACKSIZE, %sp

	sti				# enable interrupts
	movb	$0x00, %al		# enable NMI
	outb	%al, $0x70
	inb	$0x71, %al

	xorw	%si, %si		# copy
	xorw	%di, %di
	movw	$CODESIZE / 2 * 2, %cx
	cld				# increment index
rep	movsw

	pushw	%es
	popw	%ds			# set DS to data segment
	ljmp	$BBSEG, $.Loffs		# set CS
.Loffs:
		# CS, DS, ES and SS are set to common code + data segment

	movb	%dl, drive		# BIOS disk ID

	movw	$initstr, %si		# write init message
	call	writestr

.ifdef BOOTCODE				# compile only in boot sector code
	movw	firstbb + 6, %ax	# beyond 4G sectors?
	orw	firstbb + 4, %ax
	jz	.Lzeroupperwords
	jmp	.Lgeomerror

.Lzeroupperwords:
	movw	firstbb + 2, %ax	# read 0.th block?
	orw	firstbb, %ax
	jnz	.Lupperwordsok
.endif	# BOOTCODE

.ifdef MBRCODE				# compile only in MBR code
	movw	$0x1be, %si		# find active partition
	movw	$4, %cx
.Lloopfindact:
	andw	$0x80, (%si)		# active bit set in this entry?
	jnz	.Lactivepart
	addw	0x10, %si
	loop	.Lloopfindact

	movw	$actnoferrstr, %si	# no active part found
	call	writestr
	jmp	halt

.Lactivepart:				# SI points to the active part. entry
	movw	%si, actptr		# save active partition pointer
	movw	0x0a(%si), %ax		# read 0.th block?
	orw	0x08(%si), %ax
	jnz	.Lupperwordsok
.endif	# MBRCODE

	movw	$zeroblkerrstr, %si
	call	writestr
	jmp	halt

.Lupperwordsok:				# LBA 2 upper words = 0
	movb	$DISK_GETPRM, %ah	# get disk parameters
	movb	drive, %dl
	pushw	%es			# save ES
	pushw	%ds			# BIOS bug: may destroy DS
	int	$INT_DISK
	popw	%ds			# BIOS bug
	popw	%es			# restore ES

	movb	$DISK_GETSTAT, %ah	# BIOS bug: get status of last operation
	movb	drive, %dl
	int	$INT_DISK
	sti				# BIOS bug: may interrupts disabled

	jnc	.Lgetprmok		# succesful?
	cmpb	$0, drive		# floppy 0?
	jne	.Lioerror
	movw	$0x2709, %cx		# assume 360kB floppy
	movb	$0x01, %dh		# if not exist, it will fail at 1st read

.Lgetprmok:				# compute C/H/S
	xorw	%ax, %ax
	movb	%dh, %al		# heads
	incw	%ax			# 0 based
	movw	%ax, headnum
	movb	%cl, %al		# sectors
	andb	$0x3f, %al		# only low 6 bits
	movw	%ax, secnum
	movw	%cx, %ax		# cylinders
	movb	$6, %cl
	shrb	%cl, %al
	xchgb	%ah, %al
	incw	%ax			# 0 based
	movw	%ax, cylnum

.Lreadsector:
.ifdef MBRCODE				# compile only in MBR code
	movw	actptr, %si		# save active partition pointer
.endif	# MBRCODE

	xorw	%dx, %dx		# LBA, high word
.ifdef BOOTCODE				# compile only in boot sector code
	movw	firstbb + 2, %ax
.endif	# BOOTCODE
.ifdef MBRCODE				# compile only in MBR code
	movw	0x0a(%si), %ax
.endif	# MBRCODE
	divw	secnum			# / secnum
	orw	%ax, %ax		# LBA / secnum high word must be 0
	jnz	.Lgeomerror		# cyl * head must fit int 16 bits

.ifdef BOOTCODE				# compile only in boot sector code
	movw	firstbb, %ax		# LBA, low word, high remainder in DX
.endif	# BOOTCODE
.ifdef MBRCODE				# compile only in MBR code
	movw	0x08(%si), %ax		# LBA, low word, high remainder in DX
.endif	# MBRCODE
	divw	secnum			# AX = LBA / secnum, low word
	incw	%dx			# sector = remainder + 1
	movw	%dx, %bx		# BX = sector number for INT13

	xorw	%dx, %dx		# LBA / secnum, high word
	divw	headnum			# / headnum
					# DX = head, AX = cylinder

	cmpw	cylnum, %ax		# cylinder number is ok?
	jnb	.Lgeomerror		# no

	xchgb	%al, %ah
	movb	$6, %cl
	shrb	%cl, %al
	movw	%ax, %cx		# CX = cyl for INT 13
	orb	%bl, %cl		# CX = cyl + sec for INT13
	movb	%dl, %dh		# head number
	movb	drive, %dl		# drive
	movw	$BIOSSEG, %ax
	movw	%ax, %es		# read address segment
	xorw	%bx, %bx		# read address offset
	movb	$DISK_READ, %ah		# read sectors
	movb	$1, %al			# only 1 sector
	stc				# BIOS bug
	int	$INT_DISK
	sti				# BIOS bug
	jnc	.Lreadok

	incb	readcnt			# inc error counter
	cmpb	$DISK_RETRY, readcnt	# reached max. error count?
	jae	.Lioerror

	movb	$DISK_RESET, %ah	# read error, reset disk
	movb	drive, %dl
	int	$INT_DISK
	jc	.Lioerror
	jmp	.Lreadsector		# read again

.Lreadok:
	cmpw	$BOOTSIGN, %es:(CODESIZE - 2)	# test boot signature
	je	.Lsigok
	movw	$bootserrstr, %si	# boot sign not found
	call	writestr
	jmp	halt

.Lsigok:				# boot signature found
	call	stopfloppy		# stop floppy motors

.ifdef MBRCODE				# compile only in MBR code
	movw	actptr, %si		# set DS:SI to boot block or loader bin
.endif	# MBRCODE
	movb	drive, %dl		# drive to boot block or loader bin

	ljmp	$0, $BIOSSEG << 4	# jump to boot block or loader bin

.Lioerror:
	movw	$ioerrstr, %si
	call	writestr
	jmp	halt

.Lgeomerror:
	movw	$geomerrstr, %si
	call	writestr
	jmp	halt

halt:		# --------------------------------------------------------------
# stops machine
# IN:	-
# OUT:	-
# MOD:	flags
	call	stopfloppy		# stop floppy motors
	cli				# disable interrupts
.Lhalt:
	hlt				# halt
	jmp	.Lhalt

stopfloppy:	# --------------------------------------------------------------
# stop floppy motor
# IN:	-
# OUT:	-
# MOD:	AL, DX
	xorb	%al, %al
	movw	$0x3f2, %dx
	outb	%al, %dx
	ret

writestr:	# --------------------------------------------------------------
# write a string to the screen
# IN:	SI = pointer to zer terminated string
# OUT:	-
# MOD:	AX, BX, BP (BIOS bug), flags
.Lwritestr:
	movb	$VID_WRITETT, %ah	# write teletype output
	xorw	%bx, %bx		# page 0, foreground color 0 (graph)
	cld				# increment
.Lwritestrread:
	lodsb				# next char
	cmpb	$0, %al			# terminating zero?
	je	.Lwritestrend
	int	$INT_VIDEO
	jmp	.Lwritestrread
.Lwritestrend:
	ret

.section .data	# --------------------------------------------------------------
readcnt:	.byte	0		# read counter (read errors)

.ifdef BOOTCODE				# compile only in boot sector code
.globl	firstbb
firstbb:	.quad	0		# 1st. block of bootblock

initstr:	.string	"FAT boot sector.\r\n"
.endif	# BOOTCODE

.ifdef MBRCODE				# compile only in MBR code
actptr:		.word	0		# pointer to active partition entry

initstr:	.string	"MBR.\r\n"
actnoferrstr:	.string	"Active partition not found!"
.endif	# MBRCODE

ioerrstr:	.string	"I/O error!"
geomerrstr:	.string	"Geom. error!"
zeroblkerrstr:	.string "0.th block!"
bootserrstr:	.string	"Boot signature not found!"

.section .bss	# --------------------------------------------------------------
.lcomm	drive, 1			# BIOS boot disk ID (0x00 / 0x80, ...)
.lcomm	cylnum, 2			# number of cylinders of disk
.lcomm	headnum, 2			# number of heads of disk
.lcomm	secnum, 2			# sectors / track on disk

.lcomm	stack, STACKSIZE		# stack
