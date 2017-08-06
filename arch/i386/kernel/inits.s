# LGOS3 kernel init
.arch i8086
.code16

.include "multiboot.inc"			# multiboot constants

##.equ MBFLAGS, 0x00010000
.equ MBFLAGS, 0x00000000

.equ BIT_PE, 0x00000001				# CR0, Protetion Enable bit
.equ BIT_PG, 0x80000000				# CR0, Paging bit

.equ INT_VIDEO, 0x10				# video interrupt
.equ VID_TTYOUT, 0x0e				# teletype output
.equ VID_GETMODE, 0X0f				# get video mode and curr page
.equ COLOR_GRAY, 0x07				# grax color

.equ STACKSIZE, 0x100				# stack size

.equ PG_SIZE, 0x1000				# page size

.equ PG_SH_PD, 0x16				# page dir shift bits
.equ PG_SH_PT, 0x0c				# page table shift bits

.equ PG_MASK_PD, 0xffc00000			# page dir mask bits
.equ PG_MASK_PT, 0x003ff000			# page table mask bits
.equ PG_MASK_PG, 0x00000fff			# page mask bits

.equ PG_FL_P, 0x01				# page present
.equ PG_FL_NP, 0x00				# page not present
.equ PG_FL_RW, 0x02				# page read/write
.equ PG_FL_RO, 0x00				# page read only
.equ PG_FL_S, 0x00				# page supervisor
.equ PG_FL_U, 0x04				# page user
.equ PG_FL_A, 0x20				# page accessed
.equ PG_FL_D, 0x40				# page dirty
.equ PG_MASK_AVAIL, 0xe00			# page available bits mask

.equ RMNULLSEL, 0x00				# real mode GDT, null selector
.equ RMCODESEL, 0x08				# real mode GDT, null selector
.equ RMDATASEL, 0x10				# real mode GDT, null selector

.extern CP_FROM					# copy from this offset
.extern CP_TO					# copy to this phys address
.extern CP_SIZE					# copy this many bytes

.extern PDIR32					# temp page dir address
.extern PTBL32					# temp page tbl address
.extern PTBLPG					# temp page tbl address

.extern PG_WX_PHYS				# rw phys addr (text32 - bss32)
.extern PG_WX_LIN				# rw lin addr
.extern PG_WX_SIZE				# size in bytes

.extern PG_X_PHYS				# ro phys addr (text)
.extern PG_X_LIN				# ro lin addr
.extern PG_X_SIZE				# size in bytes

.extern PG_W_PHYS				# rw phys addr (data - bss)
.extern PG_W_LIN				# rw lin addr
.extern PG_W_SIZE				# size in bytes

.extern KERNEL_BOTTOM				# kernel lowest address
.extern HEADER_ADDR				# mb header address in memory
.extern LOAD_ADDR				# load file image to this addr
.extern LOAD_END_ADDR				# end of reading
.extern BSS_END_ADDR				# end of bss
.extern ENTRY_ADDR

.extern init					# C initialization code

.section .mbheader, "a", @progbits	# --------------------------------------
			# multiboot header section, must be an ALLOC setion,
			# to put to the beginning of the file and to put to
			# the binary file (if using binary instead of ELF)
.balign 4					# align mb header to dword

.long MBMAGIC					# multiboot header, magic value
.long MBFLAGS					# multiboot loader flags
.long - (MBMAGIC + MBFLAGS)			# checksum

.if MBFLAGS & 0x00010000			# optional header, if need
.long HEADER_ADDR				# header_addr
.long LOAD_ADDR					# load_addr
.long LOAD_END_ADDR				# load_end_addr
.long BSS_END_ADDR				# bss_end_addr
.long ENTRY_ADDR				# entry_addr
.byte 'L, 'G, 'O, 'S				# own ext. for real mode entry
.long start16					# real mode entry address
.endif

.section .text16, "ax", @progbits	# --------------------------------------
			# real mode .text section

.globl start16					# real mode start address
start16:
	cli					# disable interrupts
	movb	$0x80, %al			# disable NMI
	outb	%al, $0x70
	inb	$0x71, %al

	movw	%cs, %ax			# set up segments
	movw	%ax, %ds
	movw	%ax, %es
	movw	%ax, %ss			# set up stack
	movw	$rmstackend, %sp

	movb	$'L, %al			# check data segment
	movb	$'G, %ah
	cmpw	lgmag, %ax
	jne	ldrmess
	movb	$'D, %al
	movb	$'S, %ah
	cmpw	lgmag + 2, %ax
	jne	ldrmess

	call	addrtest			# check code segment
addrtest:					# stack is OK now
	popw	%ax
	cmpw	$addrtest, %ax
	jne	ldrmess

	call	rmgetvidmode			# get current video page
	movb	%bh, rmvidpage

	pushfw					# check 80386 CPU
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
	jmp	switchtoprotmode		# jump to switch to prot mode

.arch i8086
.Lno386:					# no 386 CPU found
	movw	$strno386, %si			# write no 386 CPU message
	call	rmwritestr
	call	halt

# messed up code or data segment: print an excalamtion mark and halt machine
# inp:	-
# out:	-
# mod:	-
ldrmess:					# data segment missing
	movw	%cs, %ax			# set up emergency stack
	addw	$0x1000, %ax
	movw	%ax, %ss

	movb	$0x00, %al			# enable NMI
	outb	%al, $0x70
	inb	$0x71, %al
	sti					# enable interrupts

	call	rmgetvidmode			# get current video page
	movb	$'!, %al			# print "!"
	call	rmwritechr
	call	halt

# halt machine
# inp:	-
# out:	-
# mod:	-
halt:						# halt machine
	call	stopfloppy
_halt:
	hlt
	jmp	_halt

stopfloppy:					# stop floppy motors
	xorb	%al, %al
	movw	$0x3f2, %dx
	outb	%al, %dx
	ret

# real mode get video mode
# inp:	-
# out:	AH = number of char columns
#	AL = display mode
#	BH = active page
# mod:	-
rmgetvidmode:
	movb	$VID_GETMODE, %ah
	int	$INT_VIDEO
	ret

# real mode write char
# inp:	AL = char to display
#	BH = page number
# out:	-
# mod:	AH, BL, BP (BIOS bug)
rmwritechr:
	movb	$VID_TTYOUT, %ah
	movb	$COLOR_GRAY, %bl
	push	%ds				# save DS, BIOS bug
	int	$INT_VIDEO
	pop	%ds				# restore DS, BIOS bug
	ret

# real mode write string
# inp:	SI = pointer to zero terminated string
# out:	-
# mod:	AX, BX, SI, BP (BIOS bug), Flags
rmwritestr:
	cld					# increment index
	movb	rmvidpage, %bh			# set video page
1:	lodsb					# load char
	orb	%al, %al			# tailing zero?
	jz	2f
	call	rmwritechr			# write char
	jmp	1b				# next char
2:	ret

.arch i386					# 80386 or better CPU

# switch on gate A20
# inp:	-
# out:	-
# mod:	AX, CX, SI, DI, FLAGS
a20on:
	call	checka20
	jnz	.La20on			# A20 is on?

	movw	$0x2401, %ax		# try BIOS
	stc
	int	$0x15
	jc	1f			# error?
	testb	%ah, %ah
	jne	1f
	call	checka20
	jnz	.La20on			# A20 is on?
1:
	call	.Lkbwait
	movb	$0xd1, %al		# command: write output port
	outb	%al, $0x64
	call	.Lkbwait
	movb	$0xdf, %al		# enable A20 gate
	outb	%al, $0x60
	call	.Lkbwait
	call	checka20
	jnz	.La20on			# A20 is on?

	inb	$0x92, %al		# try fast A20 gate
	testb	$0x02, %al
	jnz	1f			# don't touch if is set yet
	orb	$0x02, %al		# bit 1: 1 = A20 gate on
	andb	$0xfe, %al		# bit 0: 1 = system reset
	outb	%al, $0x92
1:
	call	checka20
	jnz	.La20on			# A20 is on?
	jmp	1b	# maybe very slow: continuous check, until A20 is on

.La20on:
	ret

# wait until keyboard controller data port is writable
# inp:	-
# out:	-
# mod:	AL
.Lkbwait:
	inb	$0x64, %al		# read status port
	testb	$0x02, %al		# test if bit 1 is zero
	jnz	.Lkbwait
	ret

# check gate A20
# inp:	-
# out:	enabled: ZF = 0, disabled: ZF = 1
# mod:	AX, CX, SI, DI
checka20:
	pushw	%ds
	pushw	%es

	xorw	%ax, %ax		# DS:SI = 0x0000:0200
	movw	%ax, %ds
	movw	$0x200, %si
	decw	%ax			# ES:DI = 0xFFFF:0210
	movw	%ax, %es
	movw	$0x210, %di
	movw	%ax, %cx		# CX = 0xFFFF

	movw	(%si), %ax
	pushw	%ax			# save original value
1:
	incw	%ax			# test A20
	movw	%ax, %es:(%di)
	cmpw	%ax, (%si)
	loope	1b

	popw	(%si)			# restore original value

	popw	%es
	popw	%ds
	ret

switchtoprotmode:				# switch to protected mode
	smsw	%ax				# check VM86 mode
	testb	$BIT_PE, %al
	jnz	.Lnorm				# no real mode

## ------------------------------------------------------
#jmp 1f
#jmp 3f
	inb	$0x92, %al
	andb	$0xfc, %al
	outb	%al, $0x92
#jmp 1f
3:
	movw	$0x2400, %ax
	int	$0x15
#jmp 1f

	call	2f
	movb	$0xd1, %al
	outb	%al, $0x64
	call	2f
	movb	$0xdf, %al
	movb	$0xdd, %al
	outb	%al, $0x60
	call	2f
jmp 1f
2:
	inb	$0x64,%al
	testb	$0x2, %al
	jnz	2b
	ret
1:
## ------------------------------------------------------
	call	a20on				# switch on gate A20

## check available memory, we need more than 1MB

	movl	%cr0, %eax			# set PE bit in CR0
	orl	$BIT_PE, %eax
	movl	%eax, %cr0
	jmp	1f				# jump after entering prot mode
1:

	xorl	%eax, %eax
	movw	%ds, %ax
	shll	$4, %eax
	movl	%eax, %esi		# later: copy PM code from this address
	xorl	%edx, %edx

	xorl	%eax, %eax			# set up GDT
	movw	%ds, %ax
	shll	$4, %eax
	addl	%eax, rmgdtr_base
	lgdt	rmgdtr

	xorl	%esi, %esi			# data segment to ESI
	movw	%ds, %si
	shl	$4, %esi

	movw	$RMDATASEL, %ax			# set up segments
	movw	%ax, %ds
	movw	%ax, %es
	movw	%ax, %fs
	movw	%ax, %gs
	movw	%ax, %ss
	movl	$pmstackend, %esp		# set up stack

	addl	$CP_FROM, %esi			# copy PM code
	movl	$CP_TO, %edi
	movl	$CP_SIZE, %ecx
	cld
addr32 rep	movsb

	movl	$0, %ebx			# no MB information structure
	movl	$LDRMAGIC, %eax			# set up for PM code

	ljmpl	$RMCODESEL, $start32		# jump to PM code

## -----------------------------------------------------------------------------
	movb	$0x00, %al			# enable NMI
	outb	%al, $0x70
	inb	$0x71, %al
	sti					# enable interrupts
## -----------------------------------------------------------------------------

.Lnorm:						# CPU not in real mode
	movw	$strnorm86, %si			# write CPU is not in real mode
	call	rmwritestr
	call	halt

.arch i8086					# 8086 CPU again

.section .data16, "aw", @progbits	# --------------------------------------
			# real mode .data section
lgmag:		.byte 'L, 'G, 'D, 'S	# magic value of data segment
strno386:	.string "LGOS requires 80386 or better CPU."
strnorm86:	.string "LGOS requires CPU to be in real mode."

.balign 8				# align GDT
rmgdt:					# real mode GDT
.org rmgdt + RMNULLSEL
		.quad 0x0000000000000000	# null selector
.org rmgdt + RMCODESEL
		.quad 0x00cf9a000000ffff	# code selector
.org rmgdt + RMDATASEL
		.quad 0x00cf92000000ffff	# data selector
rmgdtend:				# end of real mode GDT

.balign 8				# align GDTR
rmgdtr:					# GDT register
rmgdtr_limit:	.hword rmgdtend - rmgdt - 1
rmgdtr_base:	.long rmgdt

.balign 2				# align stack to word boundary
rmstack:	.skip STACKSIZE		# real mode stack
rmstackend:
rmvidpage:	.skip 1			# real mode video page

.section .text32, "ax", @progbits	# --------------------------------------
			# protected mode .text section
.arch i386
.code32
.globl start32
start32:					# called from grub
	cli					# disable interrupts
	movb	$0x80, %al			# disable NMI
	outb	%al, $0x70
	inb	$0x71, %al

	movl	$PDIR32, %edi			# set up paging, clear pdir
	movl	$PG_SIZE >> 2, %ecx
	xorl	%eax, %eax
	cld
rep	stosl

	movl	$PTBL32, %edi			# clear ptable for 1MB
	movl	$PG_SIZE >> 2, %ecx
	xorl	%eax, %eax
	cld
rep	stosl

	movl	$PTBLPG, %edi			# clear ptable for kernel
	movl	$PG_SIZE >> 2, %ecx
	xorl	%eax, %eax
	cld
rep	stosl

	movl	$PDIR32, %ebx		# ------- fill page directory

	movl	$PG_WX_LIN, %esi		# PD entry address -> ESI
	shrl	$PG_SH_PD, %esi
	movl	$PTBL32, %eax			# page table address -> EAX
	orl	$PG_FL_P | PG_FL_RW | PG_FL_S, %eax
	movl	%eax, (%ebx, %esi, 4)

	movl	$PG_X_LIN, %esi			# PD entry address -> ESI
	shrl	$PG_SH_PD, %esi
	movl	$PTBLPG, %eax			# page table address -> EAX
	orl	$PG_FL_P | PG_FL_RW | PG_FL_S, %eax
	movl	%eax, (%ebx, %esi, 4)

	movl	$PG_WX_LIN, %edi	# ------- page entry address -> EDI
	andl	$PG_MASK_PT, %edi
	shrl	$PG_SH_PT - 2, %edi		# -2: 4 byte long entries
	addl	$PTBL32, %edi

	movl	$PG_WX_SIZE, %ecx		# count -> ECX
	jecxz	2f				# if ECX = 0 then nothing to do
	addl	$1 << PG_SH_PT - 1, %ecx
	shrl	$PG_SH_PT, %ecx

	movl	$PG_WX_PHYS, %eax		# physical address -> EAX
	orl	$PG_FL_P | PG_FL_RW | PG_FL_S, %eax
	cld
1:
	stosl					# fill page table
	addl	$PG_SIZE, %eax
	loop	1b
2:

	movl	$PG_X_LIN, %edi		# ------- page entry address -> EDI
	andl	$PG_MASK_PT, %edi
	shrl	$PG_SH_PT - 2, %edi		# -2: 4 byte long entries
	addl	$PTBLPG, %edi

	movl	$PG_X_SIZE, %ecx		# count -> ECX
	jecxz	2f				# if ECX = 0 then nothing to do
	addl	$1 << PG_SH_PT - 1, %ecx
	shrl	$PG_SH_PT, %ecx

	movl	$PG_X_PHYS, %eax		# physical address -> EAX
	orl	$PG_FL_P | PG_FL_RO | PG_FL_S, %eax
	cld
1:
	stosl					# fill page table
	addl	$PG_SIZE, %eax
	loop	1b
2:

	movl	$PG_W_LIN, %edi		# ------- page entry address -> EDI
	andl	$PG_MASK_PT, %edi
	shrl	$PG_SH_PT - 2, %edi		# -2: 4 byte long entries
	addl	$PTBLPG, %edi

	movl	$PG_W_SIZE, %ecx		# count -> ECX
	jecxz	2f				# if ECX = 0 then nothing to do
	addl	$1 << PG_SH_PT - 1, %ecx
	shrl	$PG_SH_PT, %ecx

	movl	$PG_W_PHYS, %eax		# physical address -> EAX
	orl	$PG_FL_P | PG_FL_RW | PG_FL_S, %eax
	cld
1:
	stosl					# fill page table
	addl	$PG_SIZE, %eax
	loop	1b
2:

	movl	$PDIR32, %eax		# ------- set PDBR
	movl	%eax, %cr3

	movl	%cr0, %eax			# enable paging
	orl	$BIT_PG,%eax
	movl	%eax, %cr0

	jmp	init				# C init function

.section .data32, "aw", @progbits	# --------------------------------------
			# protected mode .data section
.balign 4				# align stack to dword boundary
pmstack:	.skip STACKSIZE		# protected mode stack
pmstackend:

## ----------------------------------------------------------------------------
.data
.byte 0
## ----------------------------------------------------------------------------
