#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ([2.69])
AC_INIT([lgos3], [0.0.1], [])

AC_CONFIG_SRCDIR([arch/i386/kernel/initc.c])
AC_CONFIG_HEADERS([config.h])
AM_INIT_AUTOMAKE([-Wall -Werror foreign])

# Checks for programs.
AC_PROG_CC
AM_PROG_AS

AC_SUBST([AM_CFLAGS], ["-ffreestanding -nostdinc -pedantic"])

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
                 arch/i386/loader/bootblock/Makefile])
AC_OUTPUT
