# LGOS3 loader boot block for MBR
.include "init.inc"

.equ PTADDR,	0x1be			# partition table address
.equ PTENUM,	0x04			# number of partition entries
.equ PTESZ,	0x10			# partition entry size
.equ PACTFLG,	0x80			# partition active flag

.equ BSADDR,	0x1fe			# boot sector signature address
.equ BOOTSIGN,	0xaa55			# boot sector signature

	movw	$PTADDR, %si		# find active partition
	movb	$PTENUM, %bl

1:	cmpb	$PACTFLG, (%si)		# active bit set in this entry?
	je	3f			# ative bit set
	cmpb	$0, (%si)
	jne	2f			# invalid partition table
	addw	$PTESZ, %si
	decb	%bl
	jnz	1b			# next MBR entry

	movw	$invptstr, %si		# no active part found
	jmp	stoperr

2:	movw	$invptstr, %si		# invalid partition table
	jmp	stoperr

3:	pushw	%si			# save SI
	xorw	%cx, %cx		# use LBA (CL = 0)
	movw	0x0a(%si), %dx		# active part found (SI -> MBR entry)
	movw	0x08(%si), %ax
	pushw	%ax			# test if block = 0 (then use CHS)
	orw	%dx, %ax
	popw	%ax
	movw	$readsector, (readf)
	jnz	4f

	movw	0x02(%si), %cx		# use CHS: CX = cyls and sectors
	movb	0x01(%si), %dh		# DH = heads

	xorb	%dl, %dl		# test if block = 0 (then use CHS)
	pushw	%dx
	orw	%cx, %dx
	popw	%dx
	movw	$readsector_chs, (readf)
	jnz	4f

	movw	$invptstr, %si		# MBR entry points to zeroth block
	jmp	stoperr

4:	decb	%bl			# test the other entries
	jz	5f			# no next entry
	addw	$PTESZ, %si
	cmpb	$0, (%si)
	jne	2b			# invalid partition table
	jmp	4b			# next MBR entry

5:	movw	$BIOSSEG, %bx		# segment address to read
	call	*readf			# call readsector or readsector_chs
	call	stopfloppy		# stop floppy motor

	pushw	%ds			# check boot sector signature
	movw	%bx, %ds
	movw	$BSADDR, %bx
	cmpw	$BOOTSIGN, (%bx)
	popw	%ds
	je	6f

	movw	$invbsstr, %si		# invalid boot sector
	jmp	stoperr

6:	popw	%si			# give parameters to boot sector
	movw	%si, %bp		# DS:SI and DS:BP -> part table entry
	movb	(%si), %dl		# boot drive (boot status from pt)
	ljmp	$0, $BIOSSEG << 4	# jump to bootsector

.include "disk.inc"

.section .data	# ------------------------------------------------------------
initstr:    .string "MBR\r\n"
invptstr:   .string "Invld part ta."    ## TODO
invbsstr:   .string "Invld boot sector."

.section .bss	# ------------------------------------------------------------
readf:      .word		# read function (readsector/readsector_chs)
