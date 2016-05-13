/* LGOS3 loader header - ext2 filesystem header */
#ifndef __ext2_h__
#define __ext2_h__

#include "lib.h"

int initext2();			/* initialize Ext2; read superblock	*/
void openext2file(const char *fname);	/* open file			*/
u64_t getext2filesize();		/* get file length		*/
void readext2file(u64_t pos, u32_t len, farptr_t dest);	/* read file	*/

#endif	/* #ifndef __ext2_h__ */
