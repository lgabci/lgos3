# LGOS3 loader boot block, disk
.arch i8086
.code16

.equ	INT_DISK,	0x13		# disk interrupt
.equ	DISK_RESET,	0x00		# reset disk
.equ	DISK_GETSTAT,	0x01		# get status of last operation
.equ	DISK_READ,	0x02		# read sectors
.equ	DISK_GETPRM,	0x08		# get disk parameters

.equ	DISK_RETRY,	5		# retry counts for read

.equ	SECSIZE,	0x200		# sector size: 512 bytes

.section .text	# --------------------------------------------------------------

disk_getprm:	# --------------------------------------------------------------
.global disk_getprm
# get disk parameters
# IN:	-
# OUT:	variables: cylnum, headnum, secnum
# MOD:	AX, BX, CX, DX, SI (BIOS bug), DI, BP (BIOS bug), flags
	movb	$DISK_GETPRM, %ah	# get disk parameters
	movb	(drive), %dl
	pushw	%es			# save ES
	pushw	%ds			# BIOS bug: may destroy DS
	int	$INT_DISK
	popw	%ds			# BIOS bug
	popw	%es			# restore ES
	sti				# BIOS bug: interrupts may be disabled
	pushf

	movb	$DISK_GETSTAT, %ah	# BIOS bug: get status of last op.
	movb	(drive), %dl
	int	$INT_DISK

	popf				# getprm was succesful?
	jc	ioerror

	movw	$headnum, %di		# DI: address of headnum
	cld				# increment index

	xorw	%ax, %ax
	movb	%dh, %al		# heads
	incw	%ax			# 0 based
	stosw				# DI: headnum

	movb	%cl, %al		# sectors
	andw	$0x3f, %ax		# only low 6 bits
	stosw				# DI: secnum

	xchgw	%cx, %ax		# cylinders
	movb	$6, %cl
	shrb	%cl, %al
	xchgb	%ah, %al
	incw	%ax			# 0 based
	stosw				# DI: cylnum

	ret

readsector:	# --------------------------------------------------------------
.global readsector
## rewrite
# read sector, using readsector_chs, halt on error
# IN:	DX:AX: LBA number of sector to read
#	BX: segment adress (offset always zero)
# OUT:	memory, halt on error
# MOD:	AX, CX, DX, SI, DI, flags

# S = lba % spt + 1	6 bits
# H = lba / spt % h	8 bits
# C = lba / spt / h	10 bits

	movw	$secnum, %si		# SI: address of secnum

	pushw	%ax			# save low word
	xchgw	%dx, %ax
	xorw	%dx, %dx
	divw	(%si)			# high word / secnum
	xchgw	%ax, %cx		# save LBA / SPT high word
	popw	%ax			# DX:AX = LBA / SPT high rem, low word
	divw	(%si)			# remainder: sector number - 1
	xchgw	%dx, %cx		# DX:AX = LBA / SPT
	incw	%cx			# sec number (LBA mod SPT + 1, 6 bits)

	divw	(headnum)		# LBA / SPT / number of heads
	## test: DX = 0, cyl must fit in 10 bits
	xchgb	%ah, %al		# AX = cylinder
	pushw	%cx
	movb	$6, %cl
	shlb	%cl, %al
	popw	%cx
	orw	%ax, %cx		# CX = cylinder and sector

	movb	%dl, %dh		# DH = head number

readsector_chs:	# --------------------------------------------------------------
.global readsector_chs
# read sector - CHS, halt on error
# IN:	CX: cylinder and sector number
#	DH: head number
#	BX: segment address (offset always zero)
# OUT:	memory, halt on error
# MOD:	AX, DL, DI, flags
	movw	$headnum, %di		# DI: address of headnum
	cld				# increment index

	xorw	%ax, %ax		# test head: 0 ... headnum - 1
	movb	%dh, %al
	scasw				# DI: headnum
	jae	geomerror

	movw	%cx, %ax		# test sector: 1 ... secnum
	andw	$0x3f, %ax
	jz	geomerror
	scasw				# DI: secnum
	ja	geomerror

	movw	%cx, %ax		# test cylinder: 0 ... cylnum - 1
	pushw	%cx
	movb	$6, %cl
	shrb	%cl, %al
	popw	%cx
	xchgb	%ah, %al
	scasw				# DI: cylnum
	jae	geomerror

	movw	$DISK_RETRY, %di	# DI = error counter
1:	movw	$DISK_READ << 8 | 1, %ax	# disk read, 1 sector
	movb	(drive), %dl		# disk number
	pushw	%es
	pushw	%bx
	movw	%bx, %es
	xorw	%bx, %bx		# read address: ES:BX
	pushw	%dx			# BIOS bug
	pushw	%di			# save error counter
	stc				# BIOS bug
	int	$INT_DISK
	sti				# BIOS bug
	popw	%di			# restore error counter
	popw	%dx			# BIOS bug
	popw	%bx
	popw	%es

	jnc	2f			# error?
	decw	%di			# yes, decrease counter
	jz	ioerror			# I/O error

	movb	$DISK_RESET, %ah	# reset disk before retry read
	movb	(drive), %dl
	int	$INT_DISK
	jc	ioerror			# I/O error
	jmp	1b			# error?

2:	ret

ioerror:	# --------------------------------------------------------------
# I/O error: print error message and halt machine
# IN:	-
# OUT:	halt
# MOD:	-
	movw	$ioerrstr, %si
	jmp	stoperr

geomerror:	# --------------------------------------------------------------
# geom error: print error message and halt machine
# IN:	-
# OUT:	halt
# MOD:	-
	movw	$geomerrstr, %si
	jmp	stoperr

.section .data	# --------------------------------------------------------------
ioerrstr:	.string	"I/O err"
geomerrstr:	.string	"Geom. err"

.section .bss	# --------------------------------------------------------------
.lcomm	drive, 1			# BIOS boot disk ID (0x00 / 0x80, ...)
.global drive

	# the next 3 field must be in this order
.lcomm	headnum, 2			# number of heads of disk
.lcomm	secnum, 2			# sectors / track on disk
.lcomm	cylnum, 2			# number of cylinders of disk
