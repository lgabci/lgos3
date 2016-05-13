/* LGOS3 loader - console */
__asm__ (".code16gcc");				/* compile 16 bit code */

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

  __asm__ __volatile__ (
	"movb	%[vid_getcurmode], %%ah	\n"	/* get current vid mode	*/
	"movb	$0xff, %%bh		\n"
	"int	%[int_video]		\n"	/* mod: AX, BH		*/
	"movb	%%al, %[vidmode]	\n"	/* video mode		*/
	"movb	%%ah, %[maxcol]		\n"	/* number of char cols	*/
	"movb	%%bh, %[vidpage]	\n"	/* active page		*/
	: [maxcol]		"=m" (maxcol),
	  [vidpage]		"=m" (vidpage),
	  [vidmode]		"=m" (vidmode)
	: [int_video]		"i" (INT_VIDEO),
	  [vid_getcurmode]	"i" (VID_GETCURMODE)
	: "cc" , "ax", "bh"
  );

  if (vidpage == 0xff || maxcol == VID_GETCURMODE) {	/* BIOS bug	*/
		/* we have no video page number and column number	*/
    vidpage = 0;
    __asm__ __volatile__ (
	"movb	%[vid_setcurpage], %%ah	\n"	/* select current page	*/
	"movb	%[vidpage], %%al	\n"
	"int	%[int_video]		\n"
	:
	: [vid_setcurpage]	"i" (VID_SETCURPAGE),
	  [vidpage]		"m" (vidpage),
	  [int_video]		"i" (INT_VIDEO)
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
    }
  }

  maxcol --;
  maxrow = 25 - 1;
  color = CLR_LGRAY;

  __asm__ __volatile__ (
	"movb	%[vid_getcurpos], %%ah	\n"	/* get cursor position	*/
	"movb	%[vidpage], %%bh	\n"
	"int	%[int_video]		\n"	/* mod: AX, CX, DX	*/
	"movb	%%dh, %[row]		\n"	/* row			*/
	"movb	%%dl, %[col]		\n"	/* column		*/
	: [row]			"=m" (row),
	  [col]			"=m" (col)
	: [vidpage]		"m" (vidpage),
	  [int_video]		"i" (INT_VIDEO),
	  [vid_getcurpos]	"i" (VID_GETCURPOS)
	: "cc" , "ax", "bh", "cx", "dx"
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
	"movb	%[vid_writechra], %%ah	\n"	/* write char and attr.	*/
	"movb	%[ch], %%al		\n"	/* character to display	*/
	"movb	%[vidpage], %%bh	\n"	/* page number		*/
	"movb	%[color], %%bl		\n"	/* attribute		*/
	"movw	$1, %%cx		\n"	/* # of times to write	*/
	"int	%[int_video]		\n"	/* mod: -		*/
	:
	: [vid_writechra]	"i" (VID_WRITECHRA),
	  [ch]			"m" (ch),
	  [vidpage]		"m" (vidpage),
	  [color]		"m" (color),
	  [int_video]		"i" (INT_VIDEO)
	: "cc", "ax", "bx", "cx"
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
	"movb	%[vid_scrollup], %%ah	\n"	/* scroll up window	*/
	"movb	$0x1, %%al		\n"	/* # of lines to scroll	*/
	"movb	%[color], %%bh		\n"	/* attr of new lines	*/
	"xorw	%%cx, %%cx		\n"	/* upper left corner	*/
	"movb	%[maxrow], %%dh		\n"	/* row of low right cor	*/
	"movb	%[maxcol], %%dl		\n"	/* col of low right cor	*/
	"pushw	%%ds			\n"	/* BIOS bug destroys DS	*/
	"int	%[int_video]		\n"	/* mod: -		*/
	"popw	%%ds			\n"
	:
	: [vid_scrollup]	"i" (VID_SCROLLUP),
	  [color]		"i" (CLR_BLACK << 4 | CLR_GRAY),
	  [maxrow]		"m" (maxrow),
	  [maxcol]		"m" (maxcol),
	  [int_video]		"i" (INT_VIDEO)
	: "cc", "ax", "bh", "cx", "dx", "bp"	/* BIOS bug destroys BP	*/
    );
  }

  __asm__ __volatile__ (
	"movb	%[vid_setcurpos], %%ah	\n"	/* set cursor position	*/
	"movb	%[vidpage], %%bh	\n"	/* page number		*/
	"movb	%[row], %%dh		\n"	/* row			*/
	"movb	%[col], %%dl		\n"	/* column		*/
	"int	%[int_video]		\n"	/* mod: -		*/
	:
	: [vid_setcurpos]	"i" (VID_SETCURPOS),
	  [vidpage]		"m" (vidpage),
	  [row]			"m" (row),
	  [col]			"m" (col),
	  [int_video]		"i" (INT_VIDEO)
	: "cc", "ah", "bh", "dx"
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
  u8_t base;
  int type;
  int stringlen;
  char *str;

  percent = FALSE;
  base = 10;
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
          base = 16;
        case 'u':
          switch (type) {
            case 0:
              writenum(VA_ARG(args, u16_t), base, len, padchr);
              break;
            case 1:
              writenum(VA_ARG(args, u32_t), base, len, padchr);
              break;
            case 2:
              writenum(VA_ARG(args, u64_t), base, len, padchr);
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
        base = 10;
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
