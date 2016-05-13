# LGOS3 loader boot block
.arch i8086
.code16

.equ	BIOSSEG,	0x07c0		# BIOS boot block segment
.equ	BBSEG, 		0x0060		# move boot block segment here
.equ	RAMENDSEG,	0x9f00		# segment of end of RAM area (636 KB)
.equ	STACKSIZE,	0x200		# stack size

.equ	SECSIZE,	0x200		# sector size

.equ	INT_VID,	0x10		# video interrupt
.equ	VIDEO_TTY,	0x0e		# write teletext

.equ	INT_DISK,	0x13		# disk interrupt
.equ	DISK_RESET,	0x00		# reset disk system
.equ	DISK_GETSTAT,	0x01		# get status of last operation
.equ	DISK_READ,	0x02		# read sectors
.equ	DISK_GETPRM,	0x08		# get disk parameters
.equ	DISK_EXTCHK,	0x41		# int 13 extension check
.equ	DISK_EXTREAD,	0x42		# extended read
.equ	DISK_EXTGETPRM,	0x48		# extended get parameters

.equ	DISK_RETRY,	5		# retry counts for read

.equ	COUNTERSIZE,	2		# counter size
.equ	LBASIZE,	8		# LBA size

.section .text	# --------------------------------------------------------------
.globl start
start:
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
	movw	$SECSIZE / 2 * 2, %cx	# maybe loaded .text2 too (4k sectors)
	cld				# increment index
rep	movsw

	pushw	%es
	popw	%ds			# set DS to data segment
	ljmp	$BBSEG, $.Loffs		# set CS
.Loffs:
		# CS, DS, ES and SS are set to common code + data segment

	movb	%dl, drive		# drive

	movw	$bbstr, %si		# write bootblock string
	call	writestr

	movb	$DISK_EXTCHK, %ah	# check int 13 BIOS extension
	movw	$0x55aa, %bx
	movb	drive, %dl
	int	$INT_DISK
	jc	.Lnoint13ext
	cmpw	$0xaa55, %bx
	jne	.Lnoint13ext
	testb	$0x01, %cl
	jz	.Lnoint13ext
	incb	ext13			# int 13 BIOS extension installed

	subw	$0x1a - 4, %sp		# set up ext parameter table on stack
	xorw	%ax, %ax
	pushw	%ax
	movb	$0x1a, %al
	pushw	%ax
	movw	%sp, %si
	movb	$DISK_EXTGETPRM, %ah	# get extended parameters
	movb	drive, %dl
	int	$INT_DISK
	jc	ioerr

	addw	$0x10, %si		# total number of sectors
	movw	$totsec, %di
	movw	$4, %cx
	cld				# increment index
rep	movsw				# copy total sectors number

	lodsw				# sector size in bytes
	movw	%ax, secsz

	addw	$0x1a, %sp		# free parameter table on stack

	jmp	.Lint13over

.Lnoint13ext:				# int 13 BIOS extension not installed
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
	jne	ioerr
	movw	$0x2709, %cx		# assume 360kB floppy
	movb	$0x01, %dh		# if not exist, it will fail at 1st read

.Lgetprmok:				# compute C/H/S
	xorw	%ax, %ax
	movb	%dh, %al		# heads
	incw	%ax			# 0 based
	movw	%ax, nhead
	movb	%cl, %al		# sectors
	andb	$0x3f, %al		# only low 6 bits
	movw	%ax, nsect
	movw	%cx, %ax		# cylinders
	movb	$6, %cl
	shrb	%cl, %al
	xchgb	%ah, %al
	incw	%ax			# 0 based
	movw	%ax, ncyl
.Lint13over:

	cmpw	$SECSIZE, secsz		# if sector size > 512, it is readed yet
	ja	.Lnotreadbb

	movw	$nextbb, %si		# read second half of the bootblock
	movw	$BBSEG + (SECSIZE >> 4), %ax
	call	readsector

.Lnotreadbb:
	cmpw	$0x474c, chkb2		# check signature
	jne	.Lblk2notfound
	cmpw	$0x534f, chkb2 + 2
	jne	.Lblk2notfound

	jmp	readloader

.Lblk2notfound:
	movw	$b2nstr, %si
	jmp	stoperror

halt:		# --------------------------------------------------------------
# halts machine
# IN:	-
# OUT:	-
# MOD:	-
	call	stopfloppy
	cli
.Lhlt:	hlt
	jmp	.Lhlt

stopfloppy:	# --------------------------------------------------------------
# stop floppy motor
# IN:	-
# OUT:	-
# MOD:	AL, DX
	xorb	%al, %al
	movw	$0x3f2, %dx
	outb	%al, %dx
	ret

ioerr:		# --------------------------------------------------------------
# I/O error
# IN:	-
# OUT:	-
# MOD:	AH, BX, SI
	movw	$iostr, %si
	jmp	stoperror

geomerr:	# --------------------------------------------------------------
# I/O error
# IN:	-
# OUT:	-
# MOD:	AH, BX, SI
	movw	$geostr, %si
	jmp	stoperror

stoperror:	# --------------------------------------------------------------
# prints error message and halts machine
# IN:	SI = pointer to error string
# OUT:	-
# MOD:	AH, BX, SI
	call	writestr
	call	halt

readsector:	# --------------------------------------------------------------
# IN:	SI = pointer 64 bit sector number to read
#	AX = pointer to buffer segment, offset always 0 (AX:0x0000)
# OUT:	-
# MOD:	AX, BX, CX, DX, SI, DI, flags
	cmpb	$0, ext13		# int 13 extension installed?
	jz	.Lreadlegacy		# no

	pushw	%si	# test if LBA < totsec (LBA >= 0 && LBA < totsec)
	addw	$6, %si			# SI -> MSW of LBA
	movw	$totsec + 6, %di	# DI -> MSW of total sector number
	std				# decrement index
	movw	$4, %cx
repe	cmpsw				# compare
	popw	%si			# SI -> LSB of LBA
	jae	geomerr			# sector number >= totsec?

	pushw	6(%si)			# parameter block on stack
	pushw	4(%si)			# starting absolute disk number
	pushw	2(%si)
	pushw	(%si)
	pushw	%ax			# transfer buffer segment
	xorw	%ax, %ax
	pushw	%ax			# transfer buffer offset, always 0
	incw	%ax
	pushw	%ax			# number of blocks to transfer
	movb	$0x10, %al		# packet size + reserved byte
	pushw	%ax
	movw	%sp, %si		# SI -> disk address packet

	movb	$DISK_EXTREAD, %ah	# extended read
	movb	drive, %dl
	int	$INT_DISK
	jc	ioerr			# succesful?

	addw	$0x10, %sp		# remove parameter block from stack
	jmp	.Lreadok

.Lreadlegacy:
	movw	%ax, readseg		# buffer address
	xorw	%di, %di		# DI = retry counter
.Lreadretry:				# retry read from here
	movw	6(%si), %ax		# test high words, they must be zero
	orw	4(%si), %ax
	jnz	geomerr

	xor	%dx, %dx		# div LBA high word by sectors
	movw	2(%si), %ax
	divw	nsect			# division: DX = remainder, AX = qout.
	push	%ax			# save qout high word (cyl * head)
	movw	(%si), %ax		# div LBA lo word, DX = hi word remaind.
	divw	nsect			# division: DX = remainder, AX = qout
	incb	%dl			# sector number is 1 based
	movb	%dl, %bl		# remainder: sector num (fits in 6 bits)
	popw	%dx			# DX = cyl * head hi word, AX = lo word
	cmpw	nhead, %dx		# high word > heads?
	jae	geomerr			# quot (cyls) must fit in 16 bit
	divw	nhead			# division by heads
	cmpw	ncyl, %ax
	jae	geomerr			# cylinder number valid?
	movb	%dl, %dh		# head number (fits in 8 bits)
	movb	$6, %cl
	shlb	%cl, %ah
	xchgb	%ah, %al		# AH = cyl lo 8 bits, AL = cyl hi 2 bits
	orb	%bl, %al		# AL = sectors 6 bits + cyl low 2 bits
	movw	%ax, %cx		# CH = cyl low 8 bits

	movb	$DISK_READ, %ah		# read sector
	movb	$1, %al			# only 1 sector
	movb	drive, %dl
	xorw	%bx, %bx		# ES:BX buffer
	pushw	%es
	movw	readseg, %es

	stc				# BIOS bug
	int	$INT_DISK
	sti				# BIOS bug
	popw	%es
	jnc	.Lreadok		# succesful?

	movb	$DISK_RESET, %ah	# try to reset
	movb	drive, %dl
	int	$INT_DISK
	jc	.Lioe1		# succesful? (short jmp: ioerr over 0x80 bytes)

	incw	%di			# retry counter
	cmpw	$DISK_RETRY, %di
	jb	.Lreadretry
.Lioe1:	jmp	ioerr

.Lreadok:
	ret

writestr:	# --------------------------------------------------------------
# write a zero terminated string
# IN:	SI = pointer to string
# OUT:	-
# MOD:	AX, BX, SI
	pushfw				# save flags
	pushw	%bp			# BIOS bug, save BP

	movb	$VIDEO_TTY, %ah		# teletype output
	xorw	%bx, %bx		# 0. page, and color for graphics mode
	cld				# increment index

.Lnextchr:
	lodsb				# next char
	testb	%al, %al
	jz	.Lwritestrend
	int	$INT_VID
	jmp	.Lnextchr
.Lwritestrend:

	popw	%bp			# restore BP
	popfw				# restore flags
	ret				# return

.section .data	# --------------------------------------------------------------
bbstr:		.string	"Bootblk"
iostr:		.string	"I/O err"
geostr:		.string	"Geom err"
b2nstr:		.string	"Chksm err"
ext13:		.byte	0		# INT 13 BIOS extension
secsz:		.word	SECSIZE		# sector size in bytes
.globl nextbb
nextbb:		.quad	0		# second half of the boot block
.globl firstb
firstb:		.quad	0		# first block of blocklist
.globl ldraddr
ldraddr:	.word	0		# loader address offset
ldrseg:		.word	0		# loader address segment

# ==============================================================================
# second 512 bytes sector

.section .text2, "ax", @progbits	# --------------------------------------
chkb2:	.byte	'L, 'G, 'O, 'S		# check if read this block

# read the loader --------------------------------------------------------------
# IN:	-
# OUT:	-
# MOD:	AX, BX, CX, DX, SI, DI, flags
readloader:
	movw	$llstr ,%si		# print message: "second block"
	call	writestr

	movw	$BBSEG << 4, %ax	# compute address read to (DMA 64k)
	addw	$bssend, %ax		# after end of bss
	movw	secsz, %dx
	pushw	%dx			# save DX
	addw	%dx, %ax		# round up to nearest sector size bound.
	decw	%ax
	negw	%dx			# two's complement of sector size # '
	andw	%dx, %ax
	movb	$4, %cl
	shrw	%cl, %ax
	movw	%ax, saseg		# read index sectors here

	popw	%dx			# restore DX, DX = secsz
	shrw	%cl, %dx
	addw	%dx, %ax		# AX = saseg + (secsz >> 4)
	movw	%ax, ldrseg		# read loader to this segment
	movw	%ax, ldrreadseg		# starting address of reading

	movw	saseg, %ax		# index sector offset in DS
	subw	$BBSEG, %ax		# bootblock sector offset in DS
	shlw	%cl, %ax		# (fits in AX, because all in 1st 64KB)
	movw	%ax, saoff

	xorw	%dx, %dx		# compute recors/sector (2+8 bytes)
	movw	secsz, %ax
	subw	$LBASIZE, %ax		# last LBA for the next sector
	movw	$COUNTERSIZE + LBASIZE, %bx
	divw	%bx
	movw	%ax, recspsec

	movw	$firstb, %si		# first block number of blocklist

.Lstartsector:				# read new sector (index sector)
	movw	(%si), %ax		# if LBA = 0 then end
	orw	2(%si), %ax
	orw	4(%si), %ax
	orw	6(%si), %ax
	jz	.Lblkend

	movw	saseg, %ax		# blocklist address segment (offset = 0)
	call	readsector		# read sector

	movw	saoff, %si
	movw	recspsec, %cx		# loop on an index sect (512 - 8) / 10
.Lstartouter:
	pushw	%cx			# outer loop: save loop counter
	movw	(%si), %cx		# load counter
	jcxz	.Lblkend		# end of index
	incw	%si
	incw	%si
.Lstartinner:
	pushw	%cx			# save loop variable

	movw	ldrreadseg, %ax		# read address (offset)

	cmpw	$RAMENDSEG, %ax		# reach end of RAM?
	jb	.Lbelowramend		# no, it is OK
	movw	$lnfstr, %si		# yes, stop
	jmp	stoperror
.Lbelowramend:

	pushw	%si			# save SI
	call	readsector		# read sector
	popw	%si			# restore SI

	movb	$1, ldrrd		# readed flag

	movw	secsz, %ax
	movb	$4, %cl
	shrw	%cl, %ax
	addw	%ax, ldrreadseg		# next address

	addw	$1, (%si)		# inc LBA number
	adcw	$0, 2(%si)
	adcw	$0, 4(%si)
	adcw	$0, 6(%si)

	popw	%cx			# restore loop variable
	loop	.Lstartinner		# inner loop: read sectors

	addw	$LBASIZE, %si		# SI = pointer to next LBA number

	popw	%cx			# outer loop: restore loop counter
	loop	.Lstartouter

	movw	saoff, %si		# last LBA in sector
	addw	secsz, %si
	subw	$LBASIZE, %si
	jmp	.Lstartsector

.Lblkend:
	testb	$1, ldrrd		# readed?
	jnz	.Lldrreaded

	movw	$nrstr, %si		# loader not loaded
	jmp	stoperror

.Lldrreaded:
	movw	$okstr, %si		# print OK message
	call	writestr

	movw	$loadercfgpath, %si	# pointer to path in SI
	ljmp	*ldraddr		# jump to loader

.section .data2, "aw", @progbits	# --------------------------------------
llstr:		.string	"\r\nSecond block, loading loader: "
nrstr:		.string	"loader not loaded!"
lnfstr:		.string	"loader too big to fit into memory!"
okstr:		.string	"OK\r\n"
ldrrd:		.byte	0		# loader readed
.globl	loadercfgpath
loadercfgpath:	.space	200, 0		# path of loader conf file

.section .bss	# --------------------------------------------------------------
.lcomm	drive, 1			# BIOS disk ID

.lcomm	ncyl, 2				# drive cylinder number
.lcomm	nhead, 2			# drive head number
.lcomm	nsect, 2			# drive sector/track number
.lcomm	totsec, LBASIZE			# total sectors for extended read
.lcomm	readseg, 2			# legacy read segment

.lcomm	saseg, 2			# segment of first sector aligned addr.
.lcomm	saoff, 2			# offset of first sector in DS segment
.lcomm	recspsec, 2			# records per sector

.lcomm	ldrreadseg, 2			# read next sector of loader to here

.lcomm	stack, STACKSIZE		# stack
