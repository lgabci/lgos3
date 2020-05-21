# LGOS3 loader boot block init
.arch i8086
.code16

.equ    BIOSSEG,        0x07c0          # BIOS boot block segment
.equ    BBSEG,          0x0060          # move boot block segment here
.equ    CODESIZE,       0x200           # code size of boot sector
.equ    STACKSIZE,      0x180           # stack size

.section .inittext, "ax", @progbits

.extern drive                           # disk.s

.globl start
start:
        cli                             # disable interrupts
        movw    $BBSEG, %ax
        movw    %ax, %ss
        movw    $stack + STACKSIZE, %sp
        sti                             # enable interrupts
        movw    %ax, %ds                # set DS and ES
        movw    %ax, %es

        movw    $(BIOSSEG - BBSEG) << 4, %si
        xorw    %di, %di
        movw    $CODESIZE >> 1, %cx     # copy words
        cld                             # increment index
rep     movsw

        ljmp    $BBSEG, $1f             # set CS

.section .text

1:              # CS, DS, ES and SS are set to common code + data segment

        movb    %dl, drive              # BIOS disk ID

        movw    $initstr, %si           # write init message
        call    writestr

        call    disk_getprm             # get disk parameters

        jmp     main

.section .bss

.lcomm  stack, STACKSIZE                # stack
