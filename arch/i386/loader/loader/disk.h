/* LGOS3 loader header - disk functions */
#ifndef __disk_h__
#define __disk_h__

#include "lib.h"

void stopfloppy();			/* stop floppy motors		*/
					/* read btes from a partition	*/
void readpartbytes(u64_t byteaddr, u32_t size, farptr_t dest);

void openfile(const char *fname);	/* open file			*/
u64_t getfilesize();			/* get file length		*/
void readfile(u64_t pos, u32_t len, void *dest);      /* read file near	*/
void readfile_f(u64_t pos, u32_t len, farptr_t dest); /* read file far	*/

#endif	/* #ifndef __disk_h__ */
