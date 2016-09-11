/* LGOS3 loader - multiboot functions */
__asm__ (".code16gcc");				/* compile 16 bit code	*/

#include "lib.h"
#include "disk.h"
#include "console.h"
#include "multiboot.h"

#define MB_MAX_OFFS		0x2000	/* header must be in first 8K	*/

#define MB_MAGIC		0x1badb002	/* mb magic value	*/
#define MB_FLAGOPTVALID		0x00010000	/* optional fields	*/

#define MB_NOTFOUND		0xffff	/* mb offset when not found	*/

#define MB_OWNCHKSUM0		'L'
#define MB_OWNCHKSUM1		'G'
#define MB_OWNCHKSUM2		'O'
#define MB_OWNCHKSUM3		'S'

struct __attribute__ ((packed)) req_s {		/* required parameters	*/
    u32_t magic;				/* magic value		*/
    u32_t flags;				/* flags		*/
    u32_t checksum;				/* chekcsum		*/
};
typedef struct req_s req_t;

struct __attribute__ ((packed)) opt_s {	/* optional parameters		*/
    u32_t header_addr;			/* phys location of header	*/
    u32_t load_addr;			/* phys addr of text segment	*/
    u32_t load_end_addr;		/* phys addr of end of data seg	*/
    u32_t bss_end_addr;			/* phys addr of end of bss seg	*/
    u32_t entry_addr;			/* phys addr of entry point	*/
};
typedef struct opt_s opt_t;

struct __attribute__ ((packed)) own_s {	/* own extension		*/
    u8_t ext_chksum[4];			/* own extension for real mode	*/
    u32_t real_entry;			/* real mode entry point	*/
};
typedef struct own_s own_t;

struct __attribute__ ((packed)) mbheader_s {	/* mb header		*/
  req_t req;
  opt_t opt;
  own_t own;
};
typedef struct  mbheader_s mbheader_t;

u32_t getmbheader(mbheader_t *mbh);

/* read mb header from file
input:	pointer to mb header
output:	offset of mb header in file; if not found then MB_NOTFOUND
	if mbh is not null and found mb header then fill mbh
*/
u32_t getmbheader(mbheader_t *mbh) {
  u32_t fsize;					/* file size		*/
  req_t req;
  unsigned int i;

  fsize = getfilesize();			/* get config file size	*/
  for (i = 0; i <= MIN(fsize, MB_MAX_OFFS) - sizeof(req_t); i = i + 4) {
    readfile(i, sizeof(req_t), &req);		/* read file at dwords	*/
    if (req.magic == MB_MAGIC &&		/* multiboot header	*/
      req.magic + req.flags + req.checksum == 0) {
      if (mbh != NULL) {
        mbh->req = req;
        if (req.flags & MB_FLAGOPTVALID) {		/* read opt	*/
          readfile(i + offsetof(mbheader_t, opt), sizeof(opt_t), &mbh->opt);
          readfile(i + offsetof(mbheader_t, own), sizeof(own_t), &mbh->own);
        }
        else {				/* opt not exists, fill zero	*/
          memset(&mbh->opt, 0, sizeof(opt_t));
          memset(&mbh->own, 0, sizeof(own_t));
        }
      }
      return i;
    }
  }

  return MB_NOTFOUND;
}

/* load mb file into memory
input:	address of far pointer to entry point
output:	1 = loaded, 0 = not loaded
*/
int loadmb(farptr_t *entry) {
  mbheader_t mb;			/* mb header			*/
  int mboff;				/* mb header offset in file	*/
  u32_t readoffs;			/* read from here the kernel	*/
  u32_t readsize;			/* read this many bytes		*/
  u32_t bsssize;			/* size of BSS			*/
  farptr_t fp;

  mboff = getmbheader(&mb);		/* get mb header and offset	*/
  if (mboff == MB_NOTFOUND) {		/* can not load			*/
    return 0;
  }

  if ((mb.req.flags & MB_FLAGOPTVALID) == 0) {		/* read opt	*/
    return 0;
  }

  if (mb.own.ext_chksum[0] != MB_OWNCHKSUM0 ||
    mb.own.ext_chksum[1] != MB_OWNCHKSUM1 ||
    mb.own.ext_chksum[2] != MB_OWNCHKSUM2 ||
    mb.own.ext_chksum[3] != MB_OWNCHKSUM3) {
    return 0;
  }
  printf("Multiboot loader.\n");

  readoffs = mboff - (mb.opt.header_addr - mb.opt.load_addr);
  if (mb.opt.load_end_addr == 0) {	/* to the end of file		*/
    readsize = getfilesize() - readoffs;
  }
  else {					/* to load_end_addr	*/
    readsize = mb.opt.load_end_addr - mb.opt.load_addr;
  }
  if (mb.opt.bss_end_addr == 0) {	/* no BSS segment present	*/
    bsssize = 0;
  }
  else {					/* to load_end_addr	*/
    bsssize = mb.opt.bss_end_addr - mb.opt.load_addr - readsize;
  }

  fp = malloc(readsize, 1);		/* alloc memory for kernel	*/

  printf("0x%lx (+ 0x%lx) @ 0x%lx --> %04x:%04x\n", readsize, bsssize,
    readoffs, fp.segment, fp.offset);
  readfile_f(readoffs, readsize, fp);			/* load kernel	*/
  memset_f(farptradd(fp, readsize), 0, bsssize);	/* clear BSS	*/

  fp.offset = fp.offset + mb.own.real_entry;

  *entry = fp;
  return 1;
}
