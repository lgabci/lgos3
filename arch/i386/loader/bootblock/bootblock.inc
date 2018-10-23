# LGOS3 bootblock loader global include file

.equ	BIOSSEG,	0x07c0		# BIOS boot block segment
.equ	BBSEG, 		0x0060		# move boot block segment here

.equ	SECSIZE,	0x200		# sector size: 512 bytes
