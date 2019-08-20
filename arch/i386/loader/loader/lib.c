/* LGOS3 loader - aritmethic library */

#include "console.h"
#include "disk.h"
#include "init.h"
#include "lib.h"

extern int bssend;			/* end of bss, from loader.ld	*/
extern u32_t ramsize;  		/* size of conventional RAM in bytes	*/


/*
64 bit division
input:	n	numerator (dividend)
	d	denominator (divisor)
	r	pointer to remainder
output:	quotient
*/
u64_t __udivrem(u64_t n, u64_t d, u64_t *rem) {
  u64_t q;	/* quotient */
  u64_t r;	/* remainder */
  signed int i;	/* loop variable */

  q = 0;
  r = 0;
  if (d) {	/* divide by 0 ? */
    for (i = 63; i >= 0; i --) {
      r = (r << 1) | (n >> i & 1);
      if (r >= d) {
        r = r - d;
        q = q | (u64_t)1 << i;
      }
    }
  }
  if (rem) {
    *rem = r;
  }
  return q;
}

/*
64 bit division, calls by C compiler
input:	n	numerator (dividend)
	d	denominator (divisor)
output:	quotient
*/
u64_t __udivdi3(u64_t n, u64_t d) {
  return __udivrem(n, d, 0);
}

/*
64 bit modulo division, calls by C compiler
input:	n	numerator (dividend)
	d	denominator (divisor)
output:	remainder
*/
u64_t __umoddi3(u64_t n, u64_t d) {
  u64_t r;	/* remainder */

  __udivrem(n, d, &r);
  return r;
}

/*
*/
u64_t __udivmoddi4(u64_t a, u64_t b, u64_t *rem) {
   u64_t quot = 0, qbit = 1;

  if ( b == 0 ) {
    return 1/((unsigned)b); /* Intentional divide by zero, without
				 triggering a compiler warning which
				 would abort the build */
  }

  /* Left-justify denominator and count shift */
  while ( (s64_t)b >= 0 ) {
    b = b << 1;
    qbit = qbit << 1;
  }

  while ( qbit ) {
    if ( b <= a ) {
      a = a - b;
      quot = quot + qbit;
    }
    b = b >> 1;
    qbit = qbit >> 1;
  }

  if ( rem )
    *rem = a;

  return quot;
}

/* create far pointer
return far pointer dataseg:offset
input:	offset
output:	far pointer
*/
farptr_t farptr(void *offset) {
  farptr_t p;
  p.segment = dataseg;
  p.offset = (u32_t)offset;
  return p;
}

/* normalize far pointer
normalize segment:offset to minimal offset
input:	far pointer
output:	normalized pointer
*/
farptr_t farptrnorm(farptr_t p) {
  return farptradd(p, 0);
}

/* add integer to far pointer
add integer to far pointer and normalize segment:offset to minimal offset
input:	far pointer
	integer to add
output:	pointer + integer address
*/
farptr_t farptradd(farptr_t p, u32_t size) {
  u32_t addr;
  farptr_t retp;

  addr = (u32_t)farptr_physaddr(p) + size;
  retp.segment = addr >> 4;
  retp.offset = addr & 0x0f;
  return retp;
}

/* get physical address of a far ptr address
input:	far pointer
output:	physical address
*/
void * farptr_physaddr(farptr_t p) {
  return (void *)(((u32_t)p.segment << 4) + p.offset);
}

/* length of a string
calculate length of a string, without terminating zero
input:	str	pointer to a string
output:	number of bytes in the string
*/
size_t strlen(const char *str) {
  int i;
  for(i = 0; str[i] != 0; i ++);
  return i;
}

/* copy near memory region
copy a memory region in data segment
input:	dest	destination
	src	source
	size	length in bytes
output:	near pointer to destination
	halts machine if either dest + size or src + size beyond 64K
*/
void *memcpy(void *dest, const void *src, size_t size) {
  if (MAX((u32_t)dest, (u32_t)src) + size - 1 > 0xffff) {
    stoperror("Near memcpy beyond 64K: %04x:%04lx -> %04x:%04lx, "
      "size: %lu bytes.", dataseg, src, dataseg, dest, size);
  }

  memcpy_f(farptr(dest), farptr((void *)src), size);
  return dest;
}

/* copy far memory region
copy a far memory region
input:	dest	destination
	src	source
	size	length in bytes
output:	far pointer to destination
*/
farptr_t memcpy_f(farptr_t dest, farptr_t src, size_t size) {
  farptr_t dret;

  dret = dest;
  dest = farptrnorm(dest);
  src = farptrnorm(src);

  while (size > 0) {
    u32_t dummy;
    u32_t len;
    len = MIN((size_t)(0x10000 - MAX(dest.offset, src.offset)), size);

    __asm__ __volatile__ (
      "       cld			\n"	/* increment index	*/
      "       movw    %%ds, %%bx	\n"	/* save DS, ES		*/
      "       movw    %%es, %%dx	\n"
      "       movw    %[destsegm], %%es	\n"	/* set segment regs	*/
      "       movw    %[srcsegm], %%ds	\n"
      "rep    movsb			\n"	/* copy bytes		*/
      "       movw    %%bx, %%ds	\n"	/* restore DS, ES	*/
      "       movw    %%dx, %%es	\n"
      : "=D" (dummy),
        "=S" (dummy),
        "=c" (dummy)
      : [srcsegm] "m" (src.segment),
        "S" (src.offset),
        [destsegm] "m" (dest.segment),
        "D" (dest.offset),
        "c" (len)
      : "cc", "bx", "dx", "memory"
    );

    dest = farptradd(dest, len);
    src = farptradd(src, len);
    size = size - len;
  }

  return dret;
}

/* fill near memory
fill near memory with a constant byte
input:	s	near destination
	c	constant byte
	n	length in bytes
output:	near pointer to destination
*/
void *memset(void *s, char c, size_t n) {
  if ((u32_t)s + n - 1 > 0xffff) {
    stoperror("Near memset beyond 64K: %04x:%04lx, size: %lu bytes.",
      dataseg, s, n);
  }

  memset_f(farptr(s), c, n);
  return s;
}

/* fill far memory
fill far memory with a constant byte
input:	s	far destination
	c	constant byte
	n	length in bytes
output:	far pointer to destination
*/
farptr_t memset_f(farptr_t s, char c, size_t n) {
  farptr_t dret;

  dret = s;
  s = farptrnorm(s);

  while (n > 0) {
    u32_t dummy;
    u32_t len;
    len = MIN((size_t)(0x10000 - s.offset), n);

    __asm__ __volatile__ (
      "       cld			\n"	/* increment index	*/
      "       movw    %%es, %%dx	\n"	/* save ES		*/
      "       movw    %[segm], %%es	\n"	/* set segment regs	*/
      "rep    stosb			\n"	/* set byte values	*/
      "       movw    %%dx, %%es	\n"	/* restore ES		*/
      : "=D" (dummy),
        "=c" (dummy)
      : [segm]	"m" (s.segment),
        "D" (s.offset),
        "c" (len),
        "a" (c)
      : "cc", "dx", "memory"
    );

    s = farptradd(s, len);
    n = n - len;
  }

  return dret;
}

/* copy string
copy string from src to dest, including terminating zero
input:	dest	pointer to destination
	src	pointer to source
output:	pointer to destination
*/
char *strcpy(char *dest, const char *src) {
  char *ret;

  ret = dest;
  while ((*dest ++ = *src ++));

  return ret;
}

/* compare strings
input:	str1	the first string to compare
	str2	the second string to compare
output:	if value < 0 then str1 < str2
	if value > 0 then str2 < str1
	if value == 0 then str1 == str2
*/
int strcmp(const char *str1, const char *str2) {
  size_t i;

  for (i = 0; str1[i] == str2[i] && str1[i] != '\0'; i ++);

  return str1[i] - str2[i];
}

/* compare case insensitive strings
input:	str1	the first string to compare
	str2	the second string to compare
output:	if value < 0 then str1 < str2
	if value > 0 then str2 < str1
	if value == 0 then str1 == str2
*/
int strcicmp(const char *str1, const char *str2) {
  size_t i;

  for (i = 0; tolower(str1[i]) == tolower(str2[i]) && str1[i] != '\0'; i ++);

  return tolower(str1[i]) - tolower(str2[i]);
}

/* tokenize string
get next token from string
input:	pointer to sring to tokenize
	delimiter char
output:	pointer to start of token (return)
	length of token in bytes
*/
size_t strtoken(const char **str, const char delim) {
  const char *c;

  for( ; **str == delim; (*str) ++);	/* find first not delim char	*/

			/* count chars to next delim or end of string	*/
  for (c = *str; *c != delim && *c != '\0'; c ++);

  return c - *str;
}

/* serach character in string
input:	string
	char to find
output:	pointer to to the first occurence of char in str,
	or NULL if it is not found
*/
char *strchr(const char *str, int c) {
  for (; *str != '\0'; str ++) {
    if (*str == c) {
      return (char *)str;
    }
  }

  return NULL;
}

/* convert a character to lowercase
input:	character to convert
output:	the converted char
*/
char tolower(char c) {
  if (c >= 'A' && c <= 'Z') {
    return c + 'a' -'A';
  }
  else {
    return c;
  }
}

/* allocate memory
input:	size of mem in bytes
	alignment in bytes
output:	far pointer to allocated mem
*/
farptr_t malloc(u32_t size, u16_t align) {
  static farptr_t bsstop = {0, 0};
  farptr_t p;

  if (bsstop.segment == 0 && bsstop.offset == 0) {	/* 1st call	*/
    bsstop = farptr(&bssend);			/* initialize		*/
  }
  if (align > 1) {				/* align, if need	*/
    u16_t alignmod;
    alignmod = (u32_t)farptr_physaddr(bsstop) % align;
    if (alignmod > 0) {
      bsstop = farptradd(bsstop, align - alignmod);
    }
  }
  p = bsstop;					/* return value		*/
  bsstop = farptradd(bsstop, size);		/* new top of BSS	*/
  if ((u32_t)farptr_physaddr(bsstop) > ramsize) {
    stoperror("Not enough memory to load kernel.");
  }
  return farptrnorm(p);
}

/* prints error message and stop machine
input:	dest	message
	...	parameters
output:	halts machine
*/
void stoperror(const char *message, ...) {
  va_list args;

  setcolor(CLR_LRED);				/* set light red color	*/
  VA_START(args, message);			/* get parameters	*/
  vprintf(message, args);			/* print status	*/
  VA_END(args);
  halt();					/* halt machine	*/
}

/* halt machine
stop floppy motors and halts machine
input:	-
output:	-
*/
void halt() {
  setcolor(CLR_RED << 4 | CLR_WHITE);
  printf("halt");

  __asm__ __volatile__ (
    "       jmp     _halt		\n"	/* jump to asm halt	*/
  );
//  __builtin_unreachable();			/* asm noreturn		*/
  while(1) ; //
}
