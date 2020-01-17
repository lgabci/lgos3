/* LGOS3 loader - console */

#include "lib.h"
#include "console.h"

#define	MAXNUMLEN	20			/* max. number digits */

#define	INT_VIDEO	0x10			/* video interrupt */

#define	VID_SETCURPOS	0x2			/* set cursor position */
#define	VID_GETCURPOS	0x3			/* get cursor position */
#define	VID_SETCURPAGE	0x5			/* set current display page */
#define	VID_SCROLLUP	0x6			/* scroll up window */
#define	VID_WRITECHRA	0x9			/* write char and attr */
#define	VID_GETCURMODE	0x0f			/* get current mode */

static u8_t vidpage;
static u8_t maxcol;
static u8_t maxrow;
static u8_t col;
static u8_t row;
static u8_t color;
static u8_t digits[] = {'0', '1', '2', '3', '4', '5', '6', '7',
                        '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'};

static void writechr(u8_t ch);
static void writestr(char *str);
static void writenum(u64_t num, u8_t base, u8_t minlen, u8_t pad);

/* initialize video
get screen width & height, actual video page number, current cursor position
set default background and foreground color
input:	-
output:	-
*/
void initvideo() {
  u8_t vidmode;

  __asm__ __volatile__ (			/* get curr vid mode	*/
    "       int     %[int_video]	\n"	/* mod: AX, BH		*/
    "       movb    %%ah, %[maxcol]	\n"	/* number of char cols	*/
    "       movb    %%bh, %%bl		\n"	/* active page		*/
    : "=a" (vidmode),
      "=b" (vidpage),
      [maxcol] "=m" (maxcol)
    : "a" ((u16_t)VID_GETCURMODE << 8),		/* AH = 0x0f		*/
      "b" ((u16_t)0xff << 8),			/* BH = 0xff		*/
      [int_video] "i" (INT_VIDEO)
  );

  if (vidpage == 0xff || maxcol == VID_GETCURMODE) {	/* BIOS bug	*/
		/* we have no video page number and column number	*/
    vidpage = 0;
    __asm__ __volatile__ (
      "       int     %[int_video]	\n"	/* select current page	*/
      :
      : "a" ((u16_t)VID_SETCURPAGE << 8 | vidpage),	/* AH = 0x05	*/
        [int_video] "i" (INT_VIDEO)
    );

    switch (vidmode) {		/* get columns number from video mode	*/
      case 2:
      case 3:
      case 6:
      case 7:
        maxcol = 80;
        break;
      default:
        maxcol = 40;
        break;
    }
  }

  maxcol --;
  maxrow = 25 - 1;
  color = CLR_LGRAY;

  __asm__ __volatile__ (			/* get cursor position	*/
    "       int     %[int_video]	\n"
    "       movb    %%dh, %%al		\n"	/* DX = row & column	*/
    : "=a" (row),
      "=d" (col)
    : "a" ((u16_t)VID_GETCURPOS << 8),		/* AH = 0x03		*/
      "b" ((u32_t)vidpage << 8),		/* BH = vide page num	*/
      [int_video] "i" (INT_VIDEO)
    : "cx"
  );
}

/* get color
get background and foreground color
input:	-
output:	background and foreground color
*/
u8_t getcolor() {
  return color;
}

/* set color
set background and foreground color
input:	background and foreground color
output:	-
*/
void setcolor(u8_t c) {
  color = c;
}

/* print character
print character, break line on LF
- for use only in this .c file
input:	character to print
output:	-
*/
static void writechr(u8_t ch) {
  if (ch == '\n') {
    col = 0;
    ++ row;
  }
  else {
    __asm__ __volatile__ (
      "       int     %[int_video]	\n"
      :
      : "a" ((u16_t)VID_WRITECHRA << 8 | ch),	/* AH = 0x09, AL = char	*/
        "b" ((u16_t)vidpage << 8 | color),	/* BH = page, BL = clr	*/
        "c" ((u16_t)1),				/* CX = counter		*/
        [int_video] "i" (INT_VIDEO)
    );
    col ++;
  }

  if (col > maxcol) {
    col = 0;
    row ++;
  }

  if (row > maxrow) {
    row = maxrow;
    __asm__ __volatile__ (
      "       movw    %%ds, %%si	\n"	/* BIOS bug clears DS	*/
      "       int     %[int_video]	\n"
      "       movw    %%si, %%ds	\n"
      :
      : "a" ((u16_t)VID_SCROLLUP << 8 | 1),	/* AH = 0x06, AL = line	*/
        "b" ((u16_t)(CLR_BLACK << 4 | CLR_GRAY) << 8),	/* BH = color	*/
        "c" ((u16_t)0),				/* CX = upper left	*/
        "d" ((u16_t)maxrow << 8 | maxcol),	/* DX = lower right	*/
        [int_video] "i" (INT_VIDEO)
      : "si", "bp"				/* BIOS bug		*/
    );
  }

  __asm__ __volatile__ (
    "       int     %[int_video]	\n"
    :
    : "a" ((u16_t)VID_SETCURPOS << 8),		/* AH = 0x02		*/
      "b" ((u16_t)vidpage << 8),		/* BH = page number	*/
      "d" ((u16_t)row << 8 | col),		/* DH = row, DL = col	*/
      [int_video]		"i" (INT_VIDEO)
  );
}

/* print string
print zero terminated string
- for use only in this .c file
input:	pointer to string
output:	-
*/
static void writestr(char *str) {
  while (*str) {
    writechr(*(str ++));
  }
}

/* print number
print decimal or hexa number
- for use only in this .c file
input:	number
	base (10 or 16)
	minimal length in characters
	character to pad to minimal length
output:	-
*/
static void writenum(u64_t num, u8_t base, u8_t minlen, u8_t pad) {
  u8_t len;
  char buff[MAXNUMLEN + 1];		/* tailing 0	*/
  char *digit;

  if (base <= 16) {
    len = 0;
    digit = &buff[MAXNUMLEN + 1];
    *-- digit = 0;
    do {
      *-- digit = digits[num % base];
      num = num / base;
      len ++;
    } while (num > 0 && digit > buff);
    if (num > 0) {
      *digit = '?';
    }
    for (; len < minlen && digit > buff; len ++) {
      *-- digit = pad;
    }
    writestr(digit);
  }
}

/* print variable arguments
print a format string and variable arguments given by a variable argument list
input:	format string
	variable argument list (va_list)
output:	-
*/
void vprintf(const char *format, va_list args) {
  int percent;
  int len;
  u8_t padchr;
  int type;
  int stringlen;
  char *str;

  percent = FALSE;
  padchr = ' ';
  len = 0;
  type = 0;

  while (*format) {
    if (percent) {
      switch (*format) {
        case '%':
          writechr(*format);
          percent = FALSE;
          break;
        case 'c':
          writechr(VA_ARG(args, u8_t));
          percent = FALSE;
          break;
        case 's':
          str = VA_ARG(args, char *);
          stringlen = strlen(str);
          for (; len > stringlen; len --) {
            writechr(' ');
          }
          writestr(str);
          percent = FALSE;
          break;
        case 'x':
        case 'u':
          switch (type) {
            case 0:
              writenum(VA_ARG(args, u16_t), *format == 'u' ? 10 : 16, len, padchr);
              break;
            case 1:
              writenum(VA_ARG(args, u32_t), *format == 'u' ? 10 : 16, len, padchr);
              break;
            case 2:
              writenum(VA_ARG(args, u64_t), *format == 'u' ? 10 : 16, len, padchr);
              break;
          }
          percent = FALSE;
          break;
        case '0':
          if (! len) {
            padchr = '0';
          }
          else {
            len = len * 10;
          }
          break;
        case '1':
        case '2':
        case '3':
        case '4':
        case '5':
        case '6':
        case '7':
        case '8':
        case '9':
          len = len * 10 + *format - '0';
          break;
        case 'l':
            if (type < 2) {
              type ++;
            }
          break;
        default:
          percent = FALSE;
          break;
      }
      if (! percent) {
        padchr = ' ';
        len = 0;
        type = 0;
      }
    }
    else {
      if (*format == '%') {
        percent = TRUE;
      }
      else {
        writechr(*format);
      }
    }

    format ++;
  }
}

/* print variable arguments
print a format string and variable arguments given by more arguments
input:	format string
	variable arguments
output:	-
*/
void printf(const char *format, ...) {
  va_list args;

  VA_START(args, format);
  vprintf(format, args);
  VA_END(args);
}
