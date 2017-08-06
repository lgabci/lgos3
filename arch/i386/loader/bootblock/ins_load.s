# LGOS3 loader boot block, loader rutins

.equ LDOFF, 0x400				# blocklist offset address
.equ LDSEG, (BBSEG + LDOFF >> 4)

.equ LDRSEG, (LDSEG + SECSIZE >> 4)		# segment address of loader

.section .text	# --------------------------------------------------------------

load_ldr_2nd:	# --------------------------------------------------------------
# load 2nd stage loader
# IN:	-
# OUT:	load loadewr into memory and jump to it, halts machine on error
# MOD:	AX, BX, CX, DX, SI, flags
				# read blocklist file (512 byte)
	movw	(ldrblk), %ax			# DX:AX = LBA
	movw	(ldrblk + 2), %dx
	movw	$LDSEG, %bx
	call	readsector


	movw	$SECSIZE >> 2, %cx		# max number of blocks to read
	movw	$LDRSEG, %bx			# segment of loader
	movw	$LDOFF, %si			# address of blocklist
1:
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
	call	readsector
	popw	%si
	popw	%cx

	addw	$SECSIZE >> 4, %bx		# segment address of next block
	loop	1b
2:
	ljmp	$LDRSEG, $0			# jump to loader

cli ##
hlt ##

.section .data	# --------------------------------------------------------------
ldrblk:	.long 0					# LBA block of block file
