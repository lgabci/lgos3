# LGOS3 loader boot block, video rutins
.arch i8086
.code16

.equ    INT_VIDEO,      0x10            # video interrupt
.equ    VID_WRITETT,    0x0e            # write teletype output
        
.section .text  # --------------------------------------------------------------

# write a string to the screen
# IN:   SI = pointer to zero terminated string
# OUT:  -
# MOD:  AX, BX, SI, BP (BIOS bug), flags
.globl writestr
writestr:
        movb    $VID_WRITETT, %ah
        xorw    %bx, %bx                # BH = page 0, BL = color in gfx modes

        cld
1:      lodsb
        testb   %al, %al
        jz      2f

        int     $INT_VIDEO

        jmp     1b

2:      ret
