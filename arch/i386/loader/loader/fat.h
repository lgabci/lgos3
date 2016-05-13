/* LGOS3 loader header - FAT filesystem header */
#ifndef __fat_h__
#define __fat_h__

#include "lib.h"

int initfat();			/* initialize FAT filesystem		*/
void openfatfile(const char *fname);	/* open file			*/
u64_t getfatfilesize();			/* get file length		*/
void readfatfile(u64_t pos, u32_t len, farptr_t dest);	/* read file	*/

#endif	/* #ifndef __fat_h__ */
