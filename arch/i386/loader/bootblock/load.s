# LGOS3 loader boot block, loader rutins
.arch i8086
.code16

.equ LDOFF, 0x400				# blocklist offset address
.equ LDSEG, (BBSEG + LDOFF >> 4)

.equ LDRSEG, (LDSEG + SECSIZE >> 4)		# segment address of loader

.equ INT_GETRAMSIZE, 0x12			# get memory size

.section .text	# --------------------------------------------------------------

load_ldr_2nd:	# --------------------------------------------------------------
# load 2nd stage loader
# IN:	-
# OUT:	load loader into memory and jump to it, halts machine on error
# MOD:	AX, BX, CX, DX, SI, flags
				# read blocklist file (512 byte)
	movw	(ldrblk), %ax			# DX:AX = LBA
	movw	(ldrblk + 2), %dx

	pushw	%ax				# ldrblk = 0 ?
	orw	%dx, %ax
	popw	%ax
	jnz	1f

	movw	$nrdstr, %si			# ldrblk is zero
	jmp	stoperr
1:

	movw	$LDSEG, %bx
	call	readsector

	int	$INT_GETRAMSIZE			# AX = KBs of RAM at 0x00000
	movb	$10 - 4, %cl			# * 1024 / 16
	shlw	%cl, %ax
	subw	$SECSIZE >> 4, %ax
	xchgw	%ax, %di	# DI = seg addr of (end of RAM - sector size)

	movw	$SECSIZE >> 2, %cx		# max number of blocks to read
	movw	$LDRSEG, %bx			# segment of loader
	movw	$LDOFF, %si			# address of blocklist
1:
	cmpw	%di, %bx			# top of RAM?
	ja	3f

	cld					# increment index
	lodsw					# LBA low word
	xchgw	%ax, %dx
	lodsw					# LBA high word
	xchgw	%ax, %dx

	pushw	%ax				# LBA 0 = stop
	orw	%dx, %ax
	popw	%ax
	jz	2f

	pushw	%cx				# read sector
	pushw	%si
	pushw	%di
	call	readsector
	popw	%di
	popw	%si
	popw	%cx

	addw	$SECSIZE >> 4, %bx		# segment address of next block
	loop	1b
2:
	cmpw	$LDRSEG, %bx			# readed one sector at least?
	je	4f

	ljmp	$LDRSEG, $0			# jump to loader

3:						# loader not fit into RAM
	movw	$ramstr, %si
	jmp	stoperr

4:						# no sector readed
	movw	$nrdstr, %si
	jmp	stoperr

.section .data	# --------------------------------------------------------------
ldrblk:	.long 0					# LBA block of block file
ramstr:	.string "Not enough memory."		# loader does not fit into RAM
nrdstr:	.string "No sectors readed."		# there was no readed sector
