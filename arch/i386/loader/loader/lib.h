/* LGOS3 loader header - arithmetic library */
#ifndef __lib_h__
#define __lib_h__

#define	NULL		(void *)0		/* NULL value		*/

typedef unsigned char u8_t;			/* unsigned types	*/
typedef unsigned short int u16_t;
typedef unsigned long int u32_t;
typedef unsigned long long int u64_t;

typedef signed char s8_t;			/* signed types		*/
typedef signed short int s16_t;
typedef signed long int s32_t;
typedef signed long long int s64_t;

#define	MAX_U8	0xff				/* max unsigned values	*/
#define	MAX_U16	0xffff
#define	MAX_U32	0xfffffffflu
#define MAX_U64	0xffffffffffffffffllu

#define TRUE	1				/* logical true value	*/
#define FALSE	0				/* logical false value	*/

						/* min & max macros	*/
#define	MIN(a, b)	((a) > (b) ? (b) : (a))
#define	MAX(a, b)	((a) > (b) ? (a) : (b))

#define	_INTSIZEOF(n)	((sizeof(n) + sizeof(int) - 1) & (~(sizeof(int) - 1)))

typedef void *va_list;				/* variable argument	*/
#define VA_START(ap, v)	(ap = (va_list)((u32_t)&v + _INTSIZEOF(v)))
#define	VA_ARG(ap, t)	(*(t *)((u32_t)(ap = (va_list)((u32_t)ap + \
			  _INTSIZEOF(t))) - _INTSIZEOF(t)))
#define	VA_END(ap)	(ap = (va_list)0)

#define offsetof(st, m)	((size_t)&((st *)0)->m)

struct __attribute__ ((packed)) farptr_s {	/* far pointer seg:off	*/
  u16_t offset;
  u16_t segment;
};						/* can use for far jump	*/
typedef struct farptr_s farptr_t;

typedef u32_t size_t;				/* size type		*/

u64_t __udivdi3(u64_t n, u64_t d);	/* 64 bit division algorithms	*/
u64_t __umoddi3(u64_t n, u64_t d);

farptr_t farptr(void *offset);			/* far pointer func.s	*/
farptr_t farptrnorm(farptr_t p);
farptr_t farptradd(farptr_t p, u32_t size);
void * farptr_physaddr(farptr_t p);

size_t strlen(const char *);		/* str and mem functions	*/
void *memcpy(void *dest, const void *src, size_t size);
farptr_t memcpy_f(farptr_t dest, farptr_t src, size_t size);
void *memset(void *s, char c, size_t n);
farptr_t memset_f(farptr_t s, char c, size_t n);
char *strcpy(char *dest, const char *src);
int strcmp(const char *str1, const char *str2);
int strcicmp(const char *str1, const char *str2);
size_t strtoken(const char **str, const char delim);
char *strchr(const char *str, int c);
char tolower(char c);		/* convert a letter to lowercase	*/

farptr_t malloc(u32_t size, u16_t align);	/* allocate memory	*/

void stoperror(const char *message, ...) __attribute__ ((noinline,noreturn));
void halt() __attribute__ ((noreturn));		/* halt			*/

#endif	/* #ifndef __lib_h__ */
