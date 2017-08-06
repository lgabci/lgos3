# LGOS3 loader boot block for FAT
.arch i8086
.code16

.section .itext, "ax"	# -----------------------------------------------------
	jmp	start			# jump over FAT BPB

.section .text	# ------------------------------------------------------------
.include "ins_init.s"

	call	load_ldr_2nd		# load and run 2nd stage loader

.include "ins_disk.s"
.include "ins_misc.s"
.include "ins_video.s"
.include "ins_load.s"

.section .data	# -------------------------------------------------------------
initstr:    .string "boot sector\r\n"
