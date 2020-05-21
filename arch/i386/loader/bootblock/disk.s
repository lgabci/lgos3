# LGOS3 loader boot block, disk
.arch i8086
.code16

.equ    INT_DISK,       0x13            # disk interrupt
.equ    DISK_RESET,     0x00            # reset disk
.equ    DISK_GETSTAT,   0x01            # get status of last operation
.equ    DISK_READ,      0x02            # read sectors
.equ    DISK_GETPRM,    0x08            # get disk parameters

.equ    DISK_RETRY,     5               # retry counts for read

.equ    SECSIZE,        0x200           # sector size: 512 bytes

.section .text

.global disk_getprm
disk_getprm:
# get disk parameters
# IN:   -
# OUT:  variables: cylnum, headnum, secnum
# MOD:  AX, BX, CX, DX, SI (BIOS bug), DI, BP (BIOS bug), flags
        movb    $DISK_GETPRM, %ah       # get disk parameters
        movb    (drive), %dl
        pushw   %es                     # save ES
        pushw   %ds                     # BIOS bug: may destroy DS
        int     $INT_DISK
        sti                             # BIOS bug: interrupts may be disabled
        popw    %ds                     # BIOS bug
        popw    %es                     # restore ES
        jc      ioerror

        incb    %dh                     # heads: 0 based
        movb    %dh, (headnum)

        movb    %cl, %al
        andb    $0x3f, %al              # sectors, only low 6 bits
        movb    %al, (secnum)

        xchgw   %ax, %cx                # cylinders
        movb    $6, %cl
        shrb    %cl, %al
        xchgb   %al, %ah
        incw    %ax                     # 0 based
        movw    %ax, (cylnum)

        movb    $DISK_GETSTAT, %ah      # BIOS bug: get status of last op.
        movb    (drive), %dl            # to reset bus
        int     $INT_DISK

        ret

.global readsector
readsector:
## TODO rewrite
# read sector, using readsector_chs, halt on error
# IN:   AX:DX: LBA number of sector to read
#       ES:BX: address to read
# OUT:  memory, halt on error
# MOD:  AX, CX, DX, SI, flags

# S = lba % spt + 1     6 bits
# H = lba / spt % h     8 bits
# C = lba / spt / h     10 bits

        movw    $secnum, %si            # SI: address of secnum

        pushw   %dx                     # save low word
        xorw    %dx, %dx
        divw    (%si)                   # high word / secnum
        xchgw   %ax, %cx                # save LBA / SPT high word
        popw    %ax                     # DX:AX = LBA / SPT high rem, low word
        divw    (%si)                   # DX = remainder: sector number - 1
        xchgw   %dx, %cx                # DX:AX = LBA / SPT
        incw    %cx                     # CX = sec: LBA mod SPT + 1, 6 bits

        divw    (headnum)               # LBA / SPT / number of heads
        test    %dx, %dx                # DX = 0?, cyl must fit in 10 bits
        jnz     geomerror
        cmpw    %ax, (cylnum)           # AX = cylinder
        jb      geomerror
        xchgb   %ah, %al
        rorb    %al
        rorb    %al
        orb     %al, %cl                # CX = cylinder and sector

        movb    %dl, %dh                # DH = head number

.globl readsector_chs
readsector_chs:
# read sector - CHS, halt on error
# IN:   CX: cylinder and sector number
#       DH: head number
#       ES:BX: address to read
# OUT:  memory, halt on error
# MOD:  AX, DL, DI, flags
        cmpb    %dh, (headnum)          # test head: 0 .. headnum - 1
        jb      geomerror

        movb    %cl, %al                # test sector: 1 .. secnum
        andb    $0x3f, %al
        jz      geomerror
        cmpb    %al, (secnum)
        jbe     geomerror

        movw    %cx, %ax                # test cylinder: 0 .. cylnum - 1
        rolb    %al
        rolb    %al
        andb    $0x02, %al
        xchgb   %ah, %al
        cmpw    %ax, (cylnum)
        jb      geomerror

        movw    $DISK_RETRY, %di        # DI = error counter
1:      movw    $DISK_READ << 8 | 1, %ax        # disk read, 1 sector
        movb    (drive), %dl            # disk number
        pushw   %di                     # save error counter
        pushw   %dx                     # BIOS bug
        stc                             # BIOS bug
        int     $INT_DISK
        sti                             # BIOS bug
        popw    %dx                     # BIOS bug
        popw    %di                     # restore error counter

        jnc     2f                      # error?
        decw    %di                     # yes, decrease counter
        jz      ioerror                 # I/O error

        movb    $DISK_RESET, %ah        # reset disk before retry read
        int     $INT_DISK
        jc      ioerror                 # I/O error
        jmp     1b                      # error?

2:      ret

ioerror:
# I/O error: print error message and halt machine
# IN:   -
# OUT:  halt
# MOD:  -
        movw    $ioerrstr, %si
        jmp     stoperr

geomerror:
# geom error: print error message and halt machine
# IN:   -
# OUT:  halt
# MOD:  -
        movw    $geomerrstr, %si
        jmp     stoperr

.section .data
ioerrstr:       .string         "I/O err"
geomerrstr:     .string         "Geom. err"

.section .bss
## TODO remove .global drive from here
.globl drive
.lcomm  drive, 1                        # BIOS boot disk ID (0x00 / 0x80, ...)

.lcomm  headnum, 2                      # number of heads of disk
.lcomm  secnum, 2                       # sectors / track on disk
.lcomm  cylnum, 2                       # number of cylinders of disk
