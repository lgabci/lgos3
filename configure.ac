#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ([2.69])
AC_INIT([lgos3], [0.0.1], [])

AC_CONFIG_SRCDIR([arch/i386/kernel/initc.c])
AC_CONFIG_HEADERS([config.h])
AM_INIT_AUTOMAKE([-Wall -Werror foreign])

# Checks for programs.
AC_PROG_CC([gcc])
AM_PROG_AS

AC_PROG_AWK
AC_PATH_PROG([DD],[dd])
if test x"${DD}" == x; then
  AC_MSG_ERROR([Program not found: dd])
fi

AC_PATH_TOOL([OBJDUMP], [objdump])
if test x"${OBJDUMP}" == x; then
  AC_MSG_ERROR([Program not found: objdump])
fi

AC_SUBST([AM_CFLAGS], ["-ffreestanding -nostdlib -lgcc -pedantic -Wall -Werror"])


AC_SUBST([DDELF], [$OBJDUMP])
#i686-lgos-objdump -h arch/i386/loader/bootblock/bootblock_mbr.elf | awk '{if ($1 ~ /^[0-9]+$/) {str = $6 " " $4 " " $3; getline; if (/LOAD/) print str}}' | while read skip seek count; do dd if="arch/i386/loader/bootblock/bootblock_mbr.elf" of="arch/i386/emulator/lgos3.img" bs=1 skip=$((0x$skip)) seek=$((0x$seek)) count=$((0x$count)) conv=notrunc iflag=fullblock; done


# Checks for libraries.

# Checks for header files.

# Checks for typedefs, structures, and compiler characteristics.
#AC_TYPE_SIZE_T

# Checks for library functions.
#AC_FUNC_MALLOC
#AC_CHECK_FUNCS([memset strchr])

AC_CONFIG_FILES([Makefile
                 arch/i386/kernel/Makefile
                 arch/i386/loader/Makefile
                 arch/i386/loader/loader/Makefile
                 arch/i386/loader/bootblock/Makefile
                 arch/i386/emulator/Makefile])
AC_OUTPUT
