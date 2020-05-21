# LGOS3 loader boot block for MBR
.arch i8086
.code16
## TODO remove .equ BIOSSEG from here
.equ BIOSSEG, 0x07c0

.equ PTADDR,    0x1be                   # partition table address
.equ PTENUM,    0x04                    # number of partition entries
.equ PTESZ,     0x10                    # partition entry size
.equ PACTFLG,   0x80                    # partition active flag

.equ BSADDR,    0x1fe                   # boot sector signature address
.equ BOOTSIGN,  0xaa55                  # boot sector signature

# BIOS to MBR interface
# CS:IP = 0000:7c00
# DL = boot drive, not all BIOSes support it

.global main
main:
        movw    $PTENUM, %cx            # MBR entry counter
        movw    $PTADDR, %bx            # 0. MBR entry
        xorw    %si, %si                # pointer to active MBR entry

1:      cmpb    $PACTFLG, (%bx)         # active bit set in this entry?
        jne     2f                      # ative bit set?

        testw   %si, %si                # 1st active part. found?
        jnz     4f                      # not the 1st, invalid part table
        movw    %bx, %si
        jmp     3f

2:      cmpb    $0, (%bx)               # it wasn't 0x80, it must be 0x00
        jne     4f                      # invalid partition table

3:      addw    $PTESZ, %bx
        loop    1b

        testw   %si, %si                # act partition found?
        jnz     5f

        movw    $noactstr, %si          # no active part found
        jmp     stoperr

4:      movw    $invptstr, %si          # invalid partition table
        jmp     stoperr

5:      movw    0x0a(%si), %ax          # active part found (SI -> MBR entry)
        movw    0x08(%si), %dx          # AX:DX = LBA sector number
        pushw   %ax                     # test if block = 0 (then use CHS)
        orw     %dx, %ax
        popw    %ax
        movw    $readsector, %si        # SI = funtion address to call
        jnz     6f

        movw    0x02(%si), %cx          # use CHS: CX = cyls and sectors
        movb    0x01(%si), %dh          # DH = heads

        xorb    %dl, %dl                # test if block = 0 (then use CHS)
        pushw   %dx
        orw     %cx, %dx
        popw    %dx
        jz      4b
        movw    $readsector_chs, %si    # SI = funtion address to call

6:      movw    $BIOSSEG, %bx           # segment address to read
        movw    %bx, %es
        xorw    %bx, %bx
        call    *%si                    # call readsector or readsector_chs
        call    stopfloppy              # stop floppy motor

        movw    $BSADDR, %di            # check boot sector signature
        cmpw    $BOOTSIGN, (%di)
        je      6f

        movw    $invbsstr, %si          # invalid boot sector
        jmp     stoperr

6:      movb    (drive), %dl            # boot drive from MBR
        ljmp    $0, $BIOSSEG << 4       # jump to bootsector

.section .data  # ------------------------------------------------------------
.globl initstr
initstr:    .string "MBR\r\n"
noactstr:   .string "No active part."    ## TODO no active partition found
invptstr:   .string "Invalid part table."    ## TODO
invbsstr:   .string "Invalid boot sector."

.section .bss   # ------------------------------------------------------------
