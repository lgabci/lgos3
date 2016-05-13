/* LGOS3 loader header - assembly init */
#ifndef __init_h__
#define __init_h__

extern u16_t dataseg;	/* data segment = CS, DS, SS, ES, FS, GS	*/
extern char loadercfgpath[];		/* from bootblock		*/

extern void _halt() __attribute__ ((noreturn));	/* halt (asm function)	*/
extern void _stopfloppy();			/* stop floppy motors	*/

#endif	/* #ifndef __init_h__ */
