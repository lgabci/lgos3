# LGOS3 loader boot block for Ext2

.section .text	# ------------------------------------------------------------
.include "ins_init.s"

	call	load_ldr_2nd		# load and run 2nd stage loader

.include "ins_disk.s"
.include "ins_misc.s"
.include "ins_video.s"
.include "ins_load.s"

.section .data	# ------------------------------------------------------------
initstr:    .string "Ext2\r\n"
