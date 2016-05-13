/* LGOS3 loader header - console */
#ifndef __console_h__
#define __console_h__

#include "lib.h"

/* colors */
#define	CLR_BLACK	0x0
#define	CLR_BLUE	0x1
#define	CLR_GREEN	0x2
#define	CLR_CYAN	0x3
#define	CLR_RED		0x4
#define	CLR_MAGENTA	0x5
#define	CLR_BROWN	0x6
#define	CLR_LGRAY	0x7
#define	CLR_GRAY	0x8
#define	CLR_LBLUE	0x9
#define	CLR_LGREEN	0x0a
#define	CLR_LCYAN	0x0b
#define	CLR_LRED	0x0c
#define	CLR_LMAGENTA	0x0d
#define	CLR_YELLOW	0x0e
#define	CLR_WHITE	0x0f

void initvideo();
u8_t getcolor();
void setcolor(u8_t c);
void vprintf(const char *format, va_list arg);
void printf(const char *format, ...) __attribute__ ((noinline));

#endif	/* #ifndef __console_h__ */
