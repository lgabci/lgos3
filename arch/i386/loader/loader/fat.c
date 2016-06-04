/* LGOS3 loader - FAT filesystem */
__asm__ (".code16gcc");				/* compile 16 bit code	*/

#include "disk.h"
#include "console.h"
#include "lib.h"
#include "fat.h"

#define PATHSEP			'\\'	/* path separator		*/

#define FATBDSTART		3	/* data in boot sector at here	*/
#define DIRENTRYSIZE		32		/* directory entry size	*/

#define FAT12			0
#define FAT16			1
#define FAT32			2

#define FAT32MAXMAJORVER	0		/* max. filesystem ver.	*/
#define FAT32MAXMINORVER	0		/* that this prog knows	*/

#define FAT12CLUSCNT		4085
#define FAT16CLUSCNT		65525

#define LONGNAMESIZE		256		/* long filename length	*/
#define SHORTNAMESIZE		11	/* short filename length	*/
#define SHORTNAMENSIZE		8	/* short filename name length	*/
#define SHORTNAMEESIZE		3	/* short filename ext length	*/
#define SHORTNAMEEXTSEP		'.'	/* short filename ext separator	*/
#define LASTLONGENTRY		0x40		/* last long file name	*/
#define LONGNAMECHARS		13		/* chars in one entry	*/

#define DIRENTEMPTY		0xe5		/* empty dir entry	*/
#define DIRENTEMPTYALL		0x00		/* empty to the end	*/
#define DIRENTEMPTYMOD		0x05		/* change this to 0xe5	*/

#define ATTR_READ_ONLY		0x01
#define ATTR_HIDDEN		0x02
#define ATTR_SYSTEM		0x04
#define ATTR_VOLUME_ID		0x08
#define ATTR_DIRECTORY		0x10
#define ATTR_ARCHIVE		0x20
#define ATTR_LONG_NAME		(ATTR_READ_ONLY | ATTR_HIDDEN | \
                                  ATTR_SYSTEM | ATTR_VOLUME_ID)
#define ATTR_LONG_NAME_MASK	(ATTR_READ_ONLY | ATTR_HIDDEN | \
                                  ATTR_SYSTEM | ATTR_VOLUME_ID | \
                                  ATTR_DIRECTORY | ATTR_ARCHIVE )

#define BS_EXTBOOTSIG		0x29	/* etended boot signature	*/

struct __attribute__ ((packed)) bootsect16_s {	/* FAT12/16 boot sector	*/
  u8_t bs_oemname[8];
  u16_t bpb_bytspersec;
  u8_t bpb_secperclus;
  u16_t bpb_resvdseccnt;
  u8_t bpb_numfats;
  u16_t bpb_rootentcnt;
  u16_t bpb_totsec16;
  u8_t bpb_media;
  u16_t bpb_fatsz16;
  u16_t bpb_secpertrk;
  u16_t bpb_numheads;
  u32_t bpb_hiddsec;
  u32_t bpb_totsec32;
  u8_t bs_drvnum;
  u8_t bs_reserved1;
  u8_t bs_bootsig;
  u32_t bs_volid;
  u8_t bs_vollab[11];
  u8_t bs_filsystype[8];
};
typedef struct bootsect16_s bootsect16_t;

struct __attribute__ ((packed)) bootsect32_s {	/* FAT32 bootsector	*/
  u8_t bs_oemname[8];
  u16_t bpb_bytspersec;
  u8_t bpb_secperclus;
  u16_t bpb_resvdseccnt;
  u8_t bpb_numfats;
  u16_t bpb_rootentcnt;
  u16_t bpb_totsec16;
  u8_t bpb_media;
  u16_t bpb_fatsz16;
  u16_t bpb_secpertrk;
  u16_t bpb_numheads;
  u32_t bpb_hiddsec;
  u32_t bpb_totsec32;
  u32_t bpb_fatsz32;
  u16_t bpb_extflags;
  u16_t bpb_fsver;
  u32_t bpb_rootclus;
  u16_t bpb_fsinfo;
  u16_t bpb_bkbootsec;
  u8_t bpb_reserved[12];
  u8_t bs_drvnum;
  u8_t bs_reserved1;
  u8_t bs_bootsig;
  u32_t bs_volid;
  u8_t bs_vollab[11];
  u8_t bs_filsystype[8];
};
typedef struct bootsect32_s bootsect32_t;

union bootsect_u {
  bootsect16_t b16;
  bootsect32_t b32;
};
typedef union bootsect_u bootsect_t;

struct __attribute__ ((packed)) direntry_s {
  u8_t dir_name[11];			/* entry name		*/
  u8_t dir_attr;			/* attributes		*/
  u8_t dir_ntres;			/* Win NT use this	*/
  u8_t dir_cnttimetenth;		/* millisecond stamp	*/
  u16_t dir_crttime;			/* creation time	*/
  u16_t dir_crtdate;			/* creation date	*/
  u16_t dir_lstaccdate;			/* last access date	*/
  u16_t dir_fstclushi;			/* first clust hi word	*/
  u16_t dir_wrttime;			/* last write time	*/
  u16_t dir_wrtdate;			/* last write date	*/
  u16_t dir_fstcluslo;			/* first clust lo word	*/
  u32_t dir_filesize;			/* 32 bit file size	*/
};
typedef struct direntry_s direntry_t;

struct __attribute__ ((packed)) longdirentry_s {
  u8_t ldir_ord;			/* order		*/
  u16_t ldir_name1[5];			/* long name 1-5 char	*/
  u8_t ldir_attr;			/* attributes		*/
  u8_t ldir_type;			/* type			*/
  u8_t ldir_chksum;			/* checksum		*/
  u16_t ldir_name2[6];			/* long name 6-11 char	*/
  u16_t ldir_fstcluslo;		/* low cluster, must be 0	*/
  u16_t ldir_name3[2];			/* long name 12-13 char	*/
};
typedef struct longdirentry_s longdirentry_t;

struct fatprm_s {
  u32_t bytesperclus;			/* cluster size in bytes	*/
  u32_t fatoffs;	/* start of FAT in partition, 2nd cluster	*/
  u64_t rootdiroffs;	/* only FAT1/16, root dir offset in partition	*/
  u32_t rootdirsize;		/* only FAT1/16, root dir size in bytes	*/
  u64_t dataoffs;	/* start of data in partition, 2nd cluster	*/
  u32_t countofclusters;
  u32_t fat32rootclus;
  u8_t fattype;
  u32_t eoc;
  u32_t bad;
};
typedef struct fatprm_s fatprm_t;

static fatprm_t fatprm;
static direntry_t g_direntry;	/* global dir entry (opened file)	*/
static direntry_t *g_pdirentry;	/* pointer to global dir entry		*/

static u32_t getnextclust(u32_t n);
static int iseoc(u32_t n);
static int isbad(u32_t n);
static void readcont(direntry_t *entry, u64_t pos, u32_t size, farptr_t dest);
static int findentry(direntry_t *dir, direntry_t *entry, char *fname);
static void copysname(direntry_t *d, char *name);
static void copylname(longdirentry_t *ld, char *name);
static u8_t getchecksum(u8_t *name);
static void getdirentry(const char *path, direntry_t *entry);

/* initialize FAT parameters
initialize FAT fs
- stop on error
input:	-
output:	0 - error, 1 - initialized
*/
int initfat() {
  bootsect_t b;
  u32_t	fatsz;
  u16_t rootdirsectors;

  readpartbytes(FATBDSTART, sizeof(b), farptr(&b));	/* read FAT BPB	*/

  fatprm.bytesperclus = b.b16.bpb_secperclus * b.b16.bpb_bytspersec;

  fatsz = b.b16.bpb_fatsz16 != 0 ? b.b16.bpb_fatsz16 : b.b32.bpb_fatsz32;
  fatprm.fatoffs = b.b16.bpb_resvdseccnt * b.b16.bpb_bytspersec;

  fatprm.rootdiroffs = fatprm.fatoffs +		/* root dir offset	*/
    (b.b16.bpb_numfats * fatsz) * b.b16.bpb_bytspersec;
  fatprm.rootdirsize = b.b16.bpb_rootentcnt * DIRENTRYSIZE;
  rootdirsectors = (fatprm.rootdirsize +
    b.b16.bpb_bytspersec - 1) / b.b16.bpb_bytspersec;

  fatprm.dataoffs = fatprm.rootdiroffs + rootdirsectors * b.b16.bpb_bytspersec;

  fatprm.countofclusters = ((b.b16.bpb_totsec16 != 0 ? b.b16.bpb_totsec16 :
    b.b32.bpb_totsec32) - (b.b16.bpb_resvdseccnt +
    b.b16.bpb_numfats * fatsz + rootdirsectors)) /
    b.b16.bpb_secperclus;

  if (fatprm.countofclusters < FAT12CLUSCNT) {	/* detect FAT type	*/
    fatprm.fattype = FAT12;
    fatprm.eoc = 0x0ff8;
    fatprm.bad = 0x0ff7;
    fatprm.fat32rootclus = 0;
  }
  else if (fatprm.countofclusters < FAT16CLUSCNT) {
    fatprm.fattype = FAT16;
    fatprm.eoc = 0xfff8;
    fatprm.bad = 0xfff7;
    fatprm.fat32rootclus = 0;
  }
  else {
    if (b.b32.bpb_fsver >> 8 > FAT32MAXMAJORVER ||  /* check FS version	*/
      (b.b32.bpb_fsver >> 8 == FAT32MAXMAJORVER &&
      (b.b32.bpb_fsver & 0x0f) > FAT32MAXMINORVER)) {
      stoperror("Unknown FAT32 filesystem version: %u.%u.",
        b.b32.bpb_fsver >> 8, b.b32.bpb_fsver & 0x0f);
    }

    fatprm.fattype = FAT32;
    fatprm.eoc = 0x0ffffff8;
    fatprm.bad = 0x0ffffff7;
    fatprm.fat32rootclus = b.b32.bpb_rootclus;
  }

  {				/* print filesystem info	*/
    char oemname[sizeof(b.b16.bs_oemname) + 1];
    u8_t bootsig;
    u32_t volid;
    u8_t vollab[sizeof(b.b16.bs_vollab) + 1];
    signed int i;

    memcpy(oemname, b.b16.bs_oemname, sizeof(b.b16.bs_oemname));
    oemname[sizeof(b.b16.bs_oemname)] = '\0';

    if (fatprm.fattype == FAT32) {
      bootsig = b.b32.bs_bootsig;
      volid = b.b32.bs_volid;
      memcpy(vollab, b.b32.bs_vollab, sizeof(b.b32.bs_vollab));
      vollab[sizeof(b.b32.bs_vollab)] = '\0';
    }
    else {
      bootsig = b.b16.bs_bootsig;
      volid = b.b16.bs_volid;
      memcpy(vollab, b.b16.bs_vollab, sizeof(b.b16.bs_vollab));
      vollab[sizeof(b.b16.bs_vollab)] = '\0';
    }

    for (i = strlen((char *)vollab) - 1; i >= 0 && vollab[i] == ' ';
      vollab[i --] = '\0');		/* trim spaces		*/

    printf("Detected %s filesystem, OEM ID: \"%s\", ",
      fatprm.fattype == FAT12 ? "FAT12" :
        fatprm.fattype == FAT16 ? "FAT16" : "FAT32", oemname);

    if (bootsig == BS_EXTBOOTSIG) {
      printf("volume ID: %04lx-%04lx, volume label: \"%s\", ",
        volid >> 16, volid & 0xffff, vollab);
    }

    printf("size: %lu (%lu%s) clusters.\n",
      fatprm.countofclusters,
      fatprm.bytesperclus >= 1024 ? fatprm.bytesperclus / 1024 :
        fatprm.bytesperclus,
      fatprm.bytesperclus >= 1024 ? "K" : " byte");

  }

  g_pdirentry = NULL;			/* no file opened		*/
  return 1;		/* FAT filesystem successfull initialized	*/
}

/* get next FAT chan number
get the next number from a FAT chain
- use only this C file
- stop on error
input:	FAT cluster number
output:	next cluster or EOF
*/
static u32_t getnextclust(u32_t n) {
  u32_t ret;						/* return value	*/
  u32_t fatoffset;	/* FAT cluster entry offset in filesystem	*/
  int esize;		/* entry size					*/

  if (n < 2 || n > fatprm.countofclusters + 1) {	/* valid?	*/
    stoperror("Invalid cluster number: %lu.", n);
  }

  switch (fatprm.fattype) {		/* compute offset of FAT entry	*/
    case FAT12:
      fatoffset = n + n / 2;
      esize = 2;
      break;
    case FAT16:
      fatoffset = n * 2;
      esize = 2;
      break;
    case FAT32:
      fatoffset = n * 4;
      esize = 4;
      break;
    default:				/* impossible			*/
      stoperror("Invalid FAT type: %u.", fatprm.fattype);
      break;
  }

  fatoffset = fatprm.fatoffs + fatoffset;
  readpartbytes(fatoffset, esize, farptr(&ret));

  switch (fatprm.fattype) {
    case FAT12:
      if (n & 1) {			/* higher 12 bits	*/
        ret = ret >> 4 & 0x0fff;
      }
      else {				/* lower 12 bits	*/
        ret = ret & 0x0fff;
      }
      break;
    case FAT16:				/* all 16 bits		*/
        ret = ret & 0xffff;
      break;
    case FAT32:				/* only lower 28 bits	*/
      ret = ret & 0x0fffffff;
      break;
  }

  return ret;
}

/* end of cluster chain?
check cluster number to EOC
- use only this C file
input:	FAT cluster number
output:	0 = not EOC, 1 = EOC
*/
static int iseoc(u32_t n) {
  return n >= fatprm.eoc;
}

/* bad cluster?
check cluster number to BAD
- use only this C file
input:	FAT cluster number
output:	0 = not BAD, 1 = BAD
*/
static int isbad(u32_t n) {
  return n == fatprm.bad;
}

/* read contents
read file or directory contents
- for use only in this .c file
- stop on error
input:	pointer to directory entry
	file byte position of starting address
	number of bytes to read
	far pointer to destination
output:	readed bytes at far pointer
	halt on error
*/
static void readcont(direntry_t *entry, u64_t pos, u32_t size, farptr_t dest) {
  u32_t clustnum;
  u32_t i;
  u32_t incluspos;

  if (entry == NULL) {			/* FAT32 root directory		*/
    if (fatprm.fattype == FAT32) {
      clustnum = fatprm.fat32rootclus;
    }
    else {				/* FAT12/16 root directory	*/
      if (pos + size > fatprm.rootdirsize) {
        memset_f(dest, 0, size);	/* return an empty dir entry	*/
        return;
      }
      else {
        readpartbytes(fatprm.rootdiroffs + pos, size, dest);
      }
      return;
    }
  }
  else {					/* file or directory	*/
    if (entry->dir_name[0] == DIRENTEMPTY ||	/* empty entry?	*/
      entry->dir_name[0] == DIRENTEMPTYALL) {
      stoperror("Empty directory entry in readcont fuction.");
    }

    if (entry->dir_attr & ATTR_VOLUME_ID) {	/* check file type	*/
      stoperror("Not a regular file in readcont function.");
    }

    if (! (entry->dir_attr & ATTR_DIRECTORY)) {	/* dir size always = 0	*/
      if (pos + size > entry->dir_filesize) {	/* check size		*/
        stoperror("Read over end of file: %llu > %lu.",
          pos + size, entry->dir_filesize);
      }
    }

    clustnum = ((u32_t)entry->dir_fstclushi << 16) + entry->dir_fstcluslo;
  }

  					/* find first cluster to read	*/
  for (i = 0; i < pos / fatprm.bytesperclus; i ++) {
    if (iseoc(clustnum) || isbad(clustnum)) {	/* can not go ahead	*/
      break;
    }
    clustnum = getnextclust(clustnum);
  }

  incluspos = pos % fatprm.bytesperclus;	/* start pos in cluster	*/
  while (size > 0) {			/* read file contents		*/
    u32_t readpos;
    u32_t readsize;

    if (iseoc(clustnum)) {		/* end of cluster chain?	*/
      if (entry->dir_attr & ATTR_DIRECTORY) {		/* directory	*/
        memset_f(dest, 0, size);	/* return empty dir entry	*/
        return;
      }
      else {				/* normal file			*/
        stoperror("End of cluster chain.");
      }
    }

    if (isbad(clustnum)) {		/* bad cluster?			*/
      stoperror("Bad cluster: %lx.", clustnum);
    }

    readpos = fatprm.dataoffs + (clustnum - 2) * fatprm.bytesperclus +
      incluspos;			/* read position in partition	*/
    readsize = MIN(fatprm.bytesperclus - incluspos, size); /* read size	*/

    readpartbytes(readpos, readsize, dest);

    size = size - readsize;		/* readed bytes			*/
    if (size > 0) {			/* if read more			*/
      dest = farptradd(dest, readsize);		/* set read address	*/
      clustnum = getnextclust(clustnum);	/* get next cluster	*/
    }
    incluspos = 0;
  }
}

/* find directory entry
find an entry in a directory
- for use only in this .c file
- stop on error
input:	pointer to directory to search in
	pointer to directory entry to return found entry
	pointer to a file name (can be a long or a short name)
output:	pointer to the founded entry
	return: 1 = found, 0 = not found
	halt on error
*/
static int findentry(direntry_t *dir, direntry_t *entry, char *fname) {
  u64_t pos;			/* position in directory	*/
  direntry_t d;
  longdirentry_t ld;
  char longname[LONGNAMESIZE];	/* long filename		*/
  u8_t checksum;
  int inlongname;

  inlongname = FALSE;
  checksum = 0;

  for (pos = 0; ; pos = pos + sizeof(direntry_t)) {
    readcont(dir, pos, sizeof(d), farptr(&d));
    if (d.dir_name[0] == DIRENTEMPTYALL) {	/* no more entries?	*/
      break;
    }
    if (d.dir_name[0] == DIRENTEMPTY) {		/* not empty?		*/
      continue;
    }

    if (d.dir_name[0] == DIRENTEMPTYMOD) {	/* change first char?	*/
      d.dir_name[0] = DIRENTEMPTY;
    }

    if ((d.dir_attr & ATTR_LONG_NAME_MASK) == ATTR_LONG_NAME) { /* long name */
      memcpy(&ld, &d, sizeof(d));

      if (ld.ldir_ord & LASTLONGENTRY) {	/* last long entry	*/
        checksum = ld.ldir_chksum;
        inlongname = TRUE;
      }
      else {					/* not last long entry	*/
        if (checksum != ld.ldir_chksum) {
          inlongname = FALSE;
        }
      }

      if (inlongname) {			/* copy long name if it exists	*/
        copylname(&ld, longname);
      }
    }
    else {					/* short name		*/
      char shortname[SHORTNAMESIZE + 2];  /* + separator + tailing zero	*/
      copysname(&d, shortname);
      if (! inlongname || getchecksum(d.dir_name) != checksum) {
        longname[0] = '\0';			/* no long name exists	*/
      }
      if (strcicmp(fname, longname) == 0 || strcicmp(fname, shortname) == 0) {
        memcpy(entry, &d, sizeof(d));		/* name equals	*/
        return TRUE;
      }
      inlongname = FALSE;
    }
  }

  return FALSE;
}

/* copy short name to string
copy a fragment of a long filename to a string
- for use only in this .c file
input:	pointer to a directory entry
	pointer to a char
output:	copied bytes at char
*/
static void copysname(direntry_t *d, char *name) {
  unsigned int i;
  unsigned int j;

  for (i = 0, j = 0; i < SHORTNAMESIZE; i ++) {
    if (d->dir_name[i] != ' ') {	/* space padded		*/
      if (i == SHORTNAMENSIZE) {	/* point before ext	*/
        name[j ++] = SHORTNAMEEXTSEP;
      }
      name[j ++] = d->dir_name[i];
    }
  }
  name[j] = '\0';			/* tailing zero		*/
}

/* copy long name to string
copy a fragment of a long filename to a string
- for use only in this .c file
input:	pointer to a long directory entry
	pointer to a char
output:	copied bytes at char
*/
static void copylname(longdirentry_t *ld, char *name) {
  unsigned int i;

  name = &name[((ld->ldir_ord & ~ LASTLONGENTRY) - 1) * LONGNAMECHARS];

  for (i = 0; i < sizeof(ld->ldir_name1) / sizeof(ld->ldir_name1[0]); i ++) {
    *name ++ = ld->ldir_name1[i];
  }
  for (i = 0; i < sizeof(ld->ldir_name2) / sizeof(ld->ldir_name2[0]); i ++) {
    *name ++ = ld->ldir_name2[i];
  }
  for (i = 0; i < sizeof(ld->ldir_name3) / sizeof(ld->ldir_name3[0]); i ++) {
    *name ++ = (u8_t)ld->ldir_name3[i];
  }

  if (ld->ldir_ord & LASTLONGENTRY) {		/* last long entry	*/
    *name = '\0';				/* tailing zero		*/
  }
}

/* get filename chekcsum
get short filename checksum
- for use only in this .c file
input:	pointer to a filename
output:	checksum
*/
static u8_t getchecksum(u8_t *name) {
  int i;
  u8_t sum;

  sum = 0;
  for (i = 0; i < SHORTNAMESIZE; i ++) {
    sum = (sum << 7) + (sum >> 1) + *name ++;
  }

  return sum;
}

/* find a directory entry
find an entry for a path
- for use only in this .c file
- stop on error
input:	pointer to path
	pointer to directory entry
output:	pointer to the founded entry
	halt on error
*/
static void getdirentry(const char *path, direntry_t *entry) {
  const char *f;
  size_t i;
  direntry_t e;
  direntry_t *pe;

  for (pe = NULL, f = path; (i = strtoken(&f, PATHSEP)); pe = &e, f = f + i) {
    char fname[i + 1];		/* walk trough the whole path	*/

    memcpy(&fname, f, i);
    fname[i] = '\0';

    if (pe != NULL) {		/* check if it is a directory	*/
      if (! (pe->dir_attr & ATTR_DIRECTORY)) {
        pe = NULL;
        break;
      }
    }

    if (! findentry(pe, &e, fname)) {	/* file not found	*/
      pe = NULL;
      break;
    }
  }

  if (pe == NULL) {
    stoperror("File not found: %s.", path);
  }
  if (pe->dir_attr & ATTR_DIRECTORY) {
    stoperror("It is a directory: %s.", path);
  }

  memcpy(entry, pe, sizeof(direntry_t));
}

/* open file
sets the global g_direntry and g_pdirentry variables to the i-node of the given
filename
- stop on error
input:	filename, pointer to zero terminated string
output:	set g_direntry
	set g_pdirentry
	halt on error
*/
void openfatfile(const char *fname) {
  g_pdirentry = &g_direntry;
  getdirentry(fname, g_pdirentry);
}

/* get file size
get the size of a file pointed by g_pdirentry
- stop on error
input:	-
output:	64 bit file size
	halt on error
*/
u64_t getfatfilesize() {
  if (g_pdirentry == NULL) {
    stoperror("No file opened before getfatfilesize.");
  }
  return g_pdirentry->dir_filesize;
}

/* read file contents
read file contents
- stop on error
input:	file byte position of starting address
	number of bytes to read
	far pointer to destination
output:	readed bytes at far pointer
	halt on error
*/
void readfatfile(u64_t pos, u32_t len, farptr_t dest) {
  if (g_pdirentry == NULL) {
    stoperror("No file opened before readext2file.");
  }
  readcont(g_pdirentry, pos, len, dest);
}
