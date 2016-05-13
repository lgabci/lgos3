# LGOS3 kernel init
.arch i8086
.code16

.equ MBMAGIC, 0x1badb002		# multiboot magic number
.equ MBFLAGS, 0x00000000

.section .mbheader, "a", @progbits	# --------------------------------------
			# multiboot header section, must be an ALLOC setion,
			# to put to the beginning of the file and to put to
			# the binary file (if using binary instead of ELF)
.align 4				# align multiboot header to dword

.long MBMAGIC				# multiboot header, magic value
.long MBFLAGS				# multiboot loader flags
.long - (MBMAGIC + MBFLAGS)		# checksum

.if MBFLAGS & 0x00010000		# optional header, if need
.extern LOAD_ADDR
.extern HEADER_ADDR
.extern LOAD_END_ADDR
.extern BSS_END_ADDR
.extern ENTRY_ADDR
.long HEADER_ADDR			# header_addr
.long LOAD_ADDR				# load_addr
.long LOAD_END_ADDR			# load_end_addr
.long BSS_END_ADDR			# bss_end_addr
.long ENTRY_ADDR			# entry_addr
.byte 'L, 'G, 'O, 'S			# own extension for real mode entry
.long rstart				# real mode entry address
.endif

.section .rmtext, "ax", @progbits	# --------------------------------------
			# real mode .text section

.globl rmstart				# real mode start address
rmstart:
	cli

	cli
	movw	$0xb800, %ax		##
	movw	%ax, %es		##
	movw	%cs, %ax		##
	movw	%ax, %ds		##
	movb	char, %al		##
	movb	%al, %es:0		##
	movb	color, %al		##
	movb	%al, %es:1		##
o:	hlt				##
	jmp	o			##

.section .rmdata, "aw", @progbits	# --------------------------------------
			# real mode .data section
char:	.byte 'C		# '
color:	.byte 0x5e

.section .text	# --------------------------------------------------------------
.arch i386
.code32
.globl start
start:
	cli
	movb	char + 0x100000, %al	##
	movb	%al, 0xb8000		##
	movb	color + 0x100000, %al	##
	movb	%al, 0xb8001		##
	cli				##
o2:	hlt				##
	jmp	o2
end:

.section .data	# --------------------------------------------------------------

.section .bss	;;
.lcomm aaa, 1	;;
