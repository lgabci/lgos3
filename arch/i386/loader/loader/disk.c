/* LGOS3 loader - disk functions */
__asm__ (".code16gcc");				/* compile 16 bit code */

#include "ext2.h"
#include "fat.h"
#include "console.h"
#include "lib.h"
#include "init.h"
#include "disk.h"

#define	INT_DISK	0x13		/* disk interrupt		*/
#define	DISK_RESET	0x00		/* reset disk system		*/
#define	DISK_GETSTAT	0x01		/* get status of last operation	*/
#define	DISK_READ	0x02		/* read sectors			*/
#define	DISK_GETPRM	0x08		/* get disk parameters		*/
#define	DISK_EXTCHK	0x41		/* int 13 extension check	*/
#define	DISK_EXTREAD	0x42		/* extended read		*/
#define	DISK_EXTGETPRM	0x48		/* extended get parameters	*/

#define	DISK_RETRYCNT	5		/* retry counts for read	*/
#define	DISK_CACHESIZE	0x10000		/* 64 KB disk cache		*/

#define	PARTTYPE_LINUX		0x83	/* Linux partition type		*/
#define	PARTTYPE_FAT12		0x01	/* FAT12			*/
#define	PARTTYPE_FAT16_32M	0x04	/* FAT16 <32MB			*/
#define	PARTTYPE_FAT16		0x06	/* FAT16			*/
#define	PARTTYPE_FAT32		0x0b	/* FAT32			*/
#define	PARTTYPE_FAT32_LBA	0x0c	/* FAT32 LBA			*/
#define	PARTTYPE_FAT16_LBA	0x0e	/* FAT16 LBA			*/

struct errtext_s {
  const u8_t errcode;			/* error code, status		*/
  const char *errtext;			/* error text			*/
};
typedef struct errtext_s errtext_t;

struct cachee_s {			/* cache element	*/
  u64_t sector;				/* physical sector, LBA	*/
  u32_t readcnt;			/* counter, 0 = invalid	*/
};
typedef struct cachee_s cachee_t;

struct driveprm_s {
  int initialized;			/* initialized		*/
  u8_t drive;				/* BIOS disk ID		*/
  int extbios;				/* extended INT13 bios	*/
  u32_t cyls;				/* number of cyls	*/
  u32_t heads;				/* number of heads	*/
  u32_t secs;				/* sectors / track	*/
  u64_t totsecs;			/* total number of secs	*/
  u16_t bytes;				/* bytes / sector	*/
  cachee_t *cacheeptr;			/* pointer to cache elements	*/
  u16_t cacheseg;			/* segment of disk cache	*/
  u16_t cacheentrynum;			/* cached sectors	*/
};
typedef struct driveprm_s driveprm_t;

struct partprm_s {
  int initialized;			/* initialized			*/
  u8_t partnum;				/* partition number on dev	*/
  u64_t partstart;			/* LBA partition start		*/
  u64_t partsize;			/* LBA partition size		*/
  u8_t parttype;			/* partition type		*/
};
typedef struct partprm_s partprm_t;

struct __attribute__ ((packed)) extprms_s {	/* buffer for drive par	*/
  u16_t size;				/* size of buffer		*/
  u16_t flags;				/* information flags		*/
  u32_t cyls;				/* number of phys cyls		*/
  u32_t heads;				/* number of phys heads		*/
  u32_t secs;				/* sectors / track		*/
  u64_t totsecs;			/* total number of secs		*/
  u16_t bytes;				/* bytes / sector		*/
};
typedef struct extprms_s extprms_t;

struct __attribute__ ((packed)) dap_s {	/* disk address packet		*/
  u8_t size;				/* size of DAP, 10h		*/
  u8_t reserved;			/* reserved byte, 00h		*/
  u16_t seccount;			/* secs to transfer, 1		*/
  u16_t offset;				/* transfer buff offset		*/
  u16_t segment;			/* transfer buff segm.		*/
  u64_t sector;				/* sector number		*/
};
typedef struct dap_s dap_t;

struct __attribute__ ((packed)) chs_s {	/* CHS address in MBR		*/
  u8_t head;		/* head						*/
  u8_t sec;		/* sector: 0-5 bits, cyl hi bits 6-7 bits	*/
  u8_t cyl;		/* cylinder low 8 bits				*/
};
typedef struct chs_s chs_t;

struct __attribute__ ((packed)) mbr_s {	/* MBR entry			*/
  u8_t bootflag;			/* bit 7.: bootable flag	*/
  chs_t firstchs;			/* 1.st absolute sect. in part.	*/
  u8_t type;				/* partition type		*/
  chs_t lastchs;			/* last absolute sector		*/
  u32_t firstlba;			/* LBA of 1.st absolute sector	*/
  u32_t numofsecs;			/* number of sectors		*/
};
typedef struct mbr_s mbr_t;

static u32_t readcnt;	/* sequential ID for reads, for cache LRU	*/

static driveprm_t driveprm = {			/* disk parameters	*/
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
};

static partprm_t partprm = {			/* partition parameters	*/
  0, 0, 0, 0, 0
};

static errtext_t errtexts[] = {		/* INT 13 BIOS status texts	*/
  {0x00, "successful completion"},
  {0x01, "invalid function in AH or invalid parameter"},
  {0x02, "address mark not found"},
  {0x03, "disk write-protected"},
  {0x04, "sector not found/read error"},
  {0x05, "reset failed"},
  {0x05, "data did not verify correctly"},
  {0x06, "disk changed (floppy)"},
  {0x07, "drive parameter activity failed"},
  {0x08, "DMA overrun"},
  {0x09, "DMA boundary error"},
  {0x0a, "bad sector detected"},
  {0x0b, "bad track detected"},
  {0x0c, "unsupported track or invalid media"},
  {0x0d, "invalid number of sectors on format"},
  {0x0e, "control data address mark detected"},
  {0x0f, "DMA arbitration level out of range"},
  {0x10, "uncorrectable CRC or ECC error on read"},
  {0x11, "data ECC corrected"},
  {0x20, "controller failure"},
  {0x31, "no media in drive"},
  {0x32, "incorrect drive type stored in CMOS"},
  {0x40, "seek failed"},
  {0x80, "timeout (not ready)"},
  {0xaa, "drive not ready"},
  {0xb0, "volume not locked in drive"},
  {0xb1, "volume locked in drive"},
  {0xb2, "volume not removable"},
  {0xb3, "volume in use"},
  {0xb4, "lock count exceeded"},
  {0xb5, "valid eject request failed"},
  {0xb6, "volume present but read protected"},
  {0xbb, "undefined error"},
  {0xcc, "write fault"},
  {0xe0, "status register error"},
  {0xff, "sense operation failed"}
};

static void *diskcache = NULL;

static void diskerror(u8_t errflg, u8_t status);
static void initdisk(const char *dev);
static void readphyssec(u64_t sector, u16_t segment);
static u16_t readcachedsec(u64_t sector);
static void readdiskbytes(u64_t byteaddr, u32_t size, farptr_t dest);

/* print error message and halt
print disk error message and halt machine if errflg is not 0
- for use only in this .c file
input:	error flag (0 = no error)
	status of disk operation
output:	-
*/
static void diskerror(u8_t errflg, u8_t status) {
  u8_t i;
  char *text;

  if (errflg) {				/* if there was an error	*/
    text = NULL;
    for (i = 0; i < sizeof(errtexts) / sizeof(errtext_t); i ++) {
      if (errtexts[i].errcode == status) {
        text = (char *)errtexts[i].errtext;
      }
    }
    if (text == NULL) {
      text = "unknown error";
    }

    stoperror("Disk error: 0x%02x (%s)", status, text);		/* stop	*/
  }
}

/* stop floppy motor
stop all floppy motors
input:	-
output:	-
*/
void stopfloppy() {
  __asm__ __volatile__ (
    "       callw   _stopfloppy		\n"	/* call asm function	*/
    :
    :
    : "al", "dx"
  );
}

/* initialize disk
get disk parameters for read functions
- for use only in this .c file
- if an error occurs, halts machine
input:	string to a device, partition: [fh]d[a-z][0-9]{1,2}
output:	-
*/
static void initdisk(const char *dev) {
  u8_t disk;
  u8_t part;
  u16_t checksum;
  u16_t apibitmap;
  u8_t errflg;					/* disk error flag	*/
  u8_t status;
  int i;

  switch (dev[0]) {
    case 'f':					/* floppy		*/
    case 'F':
      disk = 0;
      break;
    case 'h':					/* hdd			*/
    case 'H':
      disk = 0x80;
      break;
    default:
      stoperror("Invalid device: %s", dev);
      break;
  }
  switch (dev[1]) {
    case 'd':
    case 'D':
      break;
    default:
      stoperror("Invalid device: %s", dev);
      break;
  }

  if (dev[2] >= 'a' && dev[2] <= 'z') {		/* which device		*/
    disk = disk + dev[2] - 'a';
  }
  else if (dev[2] >= 'A' && dev[2] <= 'Z') {
    disk = disk + dev[2] - 'A';
  }
  else {
    stoperror("Invalid device: %s", dev);
  }

  if (dev[3] >= '0' && dev[3] <= '9') {		/* which partition	*/
    part = dev[3] - '0';
    if (dev[4] != ':' && dev[4] != '\0') {	/* end of device string	*/
      stoperror("Invalid partition: %s", dev);
    }
  }
  else if (dev[3] == ':' || dev[3] == '\0') {	/* whole device		*/
    part = 0xff;
  }
  else {
    stoperror("Invalid partition: %s", dev);
  }
  if (! driveprm.initialized || driveprm.drive != disk) {
    u32_t dummy;
    driveprm.drive = disk;			/* slot for this disk	*/

    __asm__ __volatile__  (			/* check BIOS extension	*/
      "       int     %[int_disk]		\n"
      "       movb    $0, %[errflg]		\n"
      "       adcb    $0, %[errflg]		\n"	/* error flag	*/
      "       movb    %%ah, %%al		\n"	/* status -> AL	*/
      : [errflg] "=m" (errflg),		/* error flag, CF	*/
        "=a" (status),		/* AH = status/major version	*/
        "=b" (checksum),		/* BX = 0xaa55		*/
        "=c" (apibitmap),		/* API support bitmap	*/
        "=d" (dummy)			/* DH = ext. version	*/
      : [int_disk] "i" (INT_DISK),
        "a"  ((u16_t)DISK_EXTCHK << 8),	/* AH = 0x41h		*/
        "b"  (0x55aa),			/* BX = 0x55aah		*/
        "d"  (disk)			/* DL = drive		*/
      : "cc"
    );
    driveprm.extbios = ! errflg && checksum == 0xaa55 && apibitmap & 0x1;

    if (driveprm.extbios) {			/* BIOS ext. found	*/
      extprms_t extprms;			/* buffer for drive params */

      extprms.size = 0x1a;			/* BIOS ext ver 1.x	*/
      extprms.flags = 0;			/* BIOS bug, must be 0	*/
      __asm__ __volatile__ (		/* ext get drive parameters	*/
        "       int     %[int_disk]		\n"
        "       movb    $0, %[errflg]		\n"
        "       adcb    $0, %[errflg]		\n"	/* error flag	*/
        "       movb    %%ah, %%al		\n"	/* status -> AL	*/
        : [errflg] "=m" (errflg),		/* error flag, CF	*/
          "=a" (status)				/* AH = status		*/
        : [int_disk] "i" (INT_DISK),
          "a" ((u16_t)DISK_EXTGETPRM << 8),		/* AH = 0x48	*/
          "d" (disk),					/* DL = drive	*/
          "S" (&extprms)		/* SI = buffer for drive params	*/
        : "cc", "memory"		/* memory: DS:SI buffer filled	*/
      );
      diskerror(errflg, status);		/* succesful?		*/

      if (extprms.flags & 2) {	/* cyl/head/sec information valid	*/
        driveprm.cyls = extprms.cyls;
        driveprm.heads = extprms.heads;
        driveprm.secs = extprms.secs;
      }
      else {		/* cyl/head/sec information is not valid	*/
        driveprm.cyls = 0;
        driveprm.heads = 0;
        driveprm.secs = 0;
      }
      driveprm.totsecs = extprms.totsecs;		/* total secs	*/
      driveprm.bytes = extprms.bytes;			/* bytes / sec	*/
    }
    else {				/* BIOS extension not found	*/
      u8_t errflg;				/* disk error flag	*/
      u16_t cylsecs;
      u8_t heads;
      u16_t ds;
      u16_t es;

      __asm__ __volatile__ (			/* get drive parameters	*/
        "       movw    %%ds, %[ds]	\n"	/* BIOS bug: save DS	*/
        "       movw    %%es, %[es]	\n"	/* save ES		*/
        "       int     %[int_disk]	\n"
        "       movw    %[ds], %%ds	\n"	/* BIOS bug: restore DS	*/
        "       movw    %[es], %%es	\n"	/* restore ES		*/
        "       sti			\n"	/* BIOS bug		*/
        "       movb    %%dh, %%dl	\n"	/* max head number	*/
        : "=a" (status),	/* artifical dep: order of asm blocks	*/
          "=c" (cylsecs),			/* CX = cyl & sectors	*/
          "=d" (heads),				/* DH = max head number	*/
          [ds] "=m" (ds),			/* store DS, ES		*/
          [es] "=m" (es)
        : [int_disk] "i" (INT_DISK),
          "a" ((u16_t)DISK_GETPRM << 8),	/* AH = 0x08		*/
          "d" (disk)				/* DL = drive		*/
        : "cc", "bl", "di", "si", "bp"
      );

      __asm__ __volatile__ (	/* BIOS bug: we must get last status	*/
        "       int     %[int_disk]	\n"
        "       movb    $0, %[errflg]	\n"
        "       adcb    $0, %[errflg]	\n"	/* error flag		*/
        "       orb     %%ah, %%al	\n"	/* error stat, BIOS bug	*/
	// must use errflg and status from DISK_GETPRM, not from here!
        : [errflg] "=m" (errflg),		/* error flag, CF	*/
          "=a" (status)				/* AH = status		*/
        : [int_disk] "i" (INT_DISK),
          "a" ((u16_t)DISK_GETSTAT << 8),	/* AH = 0x01		*/
          "d" (disk)				/* DL = drive		*/
        : "cc"
      );

      diskerror(errflg, status);		/* succesful?		*/

      driveprm.cyls = ((cylsecs & 0xc0) << 2 | cylsecs >> 8) + 1; /* 0 based */
      driveprm.heads = heads + 1;			/* 0 based	*/
      driveprm.secs = cylsecs & 0x3f;			/* 1 based	*/
      driveprm.totsecs = driveprm.cyls * driveprm.heads * driveprm.secs;
      driveprm.bytes = 512;				/* bytes / sec	*/
    }

    if (diskcache == NULL) {				/* first time	*/
      farptr_t fp;

      fp = malloc(DISK_CACHESIZE, 0x10);
      diskcache = (void *)(((u32_t)(fp.segment - dataseg) << 4) + fp.offset);
    }

    driveprm.cacheeptr = (cachee_t *)diskcache;		/* cache elem.s	*/
    driveprm.cacheentrynum = DISK_CACHESIZE / driveprm.bytes; /* cache entrs */

    if ((u32_t)((cachee_t *)diskcache + driveprm.cacheentrynum) > 0xffff) {
      stoperror("Can not allocate RAM for disk cache entries.");
    }

    driveprm.cacheseg = (((dataseg << 4) +		/* cache segm.	*/
      (u32_t)((cachee_t *)diskcache + driveprm.cacheentrynum) +
      driveprm.bytes - 1) & -(u32_t)driveprm.bytes) >> 4;
    readcnt = 0;					/* start sequence   */
    for (i = 0; i < driveprm.cacheentrynum; i ++) {	/* invalidate cache */
      driveprm.cacheeptr[i].readcnt = 0;
    }

    partprm.initialized = FALSE;	/* initialize partition		*/
    driveprm.initialized = TRUE;
  }

  if (! partprm.initialized || partprm.partnum != part) {
    if (part == 0xff) {		/* if no partition, the use whole disk	*/
      partprm.partstart = 0;
      partprm.partsize = driveprm.totsecs;

      partprm.parttype = 0x0;	/* init all filesystems			*/
    }
    else {			/* use a partition			*/
      mbr_t mbrentry;
      u16_t firstcyl;
      u8_t firstsec;
      u16_t lastcyl;
      u8_t lastsec;
      u16_t mbrsign;

      readdiskbytes(0x1fe, 2, farptr(&mbrsign));  /* read partition sign. */
      if (mbrsign != 0xaa55) {
        stoperror("Invalid partition signature: 0x%04x.", mbrsign);
      }

      if (part < 1 || part > 4) {	/* only valid partition number	*/
        stoperror("Invalid partition number: %u.", part);
      }

      readdiskbytes((u32_t)((mbr_t *)0x1be + part - 1), sizeof(mbr_t),
        farptr(&mbrentry));			/* read partition entry	*/

      firstcyl = mbrentry.firstchs.cyl |
        ((u16_t)mbrentry.firstchs.sec & 0xc0) << 2;
      firstsec = mbrentry.firstchs.sec & 0x3f;
      lastcyl = mbrentry.lastchs.cyl |
        ((u16_t)mbrentry.lastchs.sec & 0xc0) << 2;
      lastsec = mbrentry.lastchs.sec & 0x3f;

      if (mbrentry.firstlba > 0) {
        partprm.partstart = mbrentry.firstlba;
      }
      else {
        partprm.partstart = (firstcyl * driveprm.heads +
          mbrentry.firstchs.head) * driveprm.secs + firstsec - 1;
      }

      if (mbrentry.numofsecs > 0) {
        partprm.partsize = mbrentry.numofsecs;
      }
      else {
        partprm.partsize = (lastcyl * driveprm.heads + mbrentry.lastchs.head) *
          driveprm.secs + lastsec - 1 - partprm.partstart + 1;
      }

      switch (mbrentry.type) {
        case 0:				/* empty partition	*/
          stoperror("Empty partition.");
          break;
        default:
          partprm.parttype = mbrentry.type;
          break;
      }
    }

    switch (partprm.parttype) {
      case 0:				/* autodectect		*/
        if (initext2()) {
          partprm.parttype = PARTTYPE_LINUX;
        }
        else if (initfat()) {
          partprm.parttype = PARTTYPE_FAT16;
        }
        else {
          stoperror("Can not initialize filesystem.");
        }
        break;
      case PARTTYPE_LINUX:		/* Linux partition	*/
        if (! initext2()) {
          stoperror("Can not initialize filesystem.");
        }
        break;
      case PARTTYPE_FAT12:		/* FAT partition	*/
      case PARTTYPE_FAT16_32M:
      case PARTTYPE_FAT16:
      case PARTTYPE_FAT32:
      case PARTTYPE_FAT32_LBA:
      case PARTTYPE_FAT16_LBA:
        if (! initfat()) {
          stoperror("Can not initialize filesystem.");
        }
        break;
      default:				/* unknown partition type	*/
        stoperror("Unknown partition type: 0x%02x.", partprm.parttype);
        break;
    }

    partprm.partnum = part;
    partprm.initialized = TRUE;
  }
}

/* read physical sector
read a physical sector to a given segment address
- driveprm must be set by initdisk
- called by readcachedsec on cache miss
- if an error occurs, halts machine
- for use only in this .c file
input:	sector	64 bit sector number
	segment	16 bit segment address
output:	readed sector at segment:0
*/
static void readphyssec(u64_t sector, u16_t segment) {
  u8_t errflg;
  u8_t status;

  if (sector >= driveprm.totsecs) {
    stoperror("Read over disk: %llu (max. sector: %llu).", sector,
      driveprm.totsecs - 1);
  }

  if (driveprm.extbios) {			/* BIOS ext found	*/
    dap_t dap = {0x10, 0, 1, 0, segment, sector};	/* DAP		*/

    __asm__ __volatile__ (			/* ext. read		*/
      "       int     %[int_disk]	\n"
      "       movb    $0, %[errflg]	\n"
      "       adcb    $0, %[errflg]	\n"	/* error flag		*/
      "       movb    %%ah, %%al	\n"	/* error status		*/
        : [errflg] "=m" (errflg),		/* error flag, CF	*/
          "=a" (status)				/* AH = status		*/
        : [int_disk] "i" (INT_DISK),
          "a" ((u16_t)DISK_EXTREAD << 8),	/* AH = 0x42		*/
          "d" (driveprm.drive),			/* DL = drive		*/
          "S" (&dap)		/* SI = pointer to disk address packet	*/
        : "cc", "memory"
    );
  }
  else {					/* BIOS ext not found	*/
    u16_t cylsec;
    u8_t head;
    int i;
    u16_t dummy;

    head = sector / driveprm.secs % driveprm.heads;	/* head		*/
    cylsec = sector / driveprm.secs / driveprm.heads;	/* cylinder	*/
    cylsec = cylsec << 8 | (cylsec & 0x300) >> 2 | /* cyl 6 lo + 2 hi bits */
      (sector % driveprm.secs + 1);	/* sector 6 bits, 1 based	*/

    for (i = 0; i < DISK_RETRYCNT; i ++) {
      __asm__ __volatile__ (			/* read sectors		*/
        "       movw    %%es, %%si	\n"	/* save ES (no stack)	*/
        "       movw    %[segment], %%es	\n"	/* ES = segm	*/
        "       stc			\n"	/* BIOS bug: set CF	*/
        "       cli			\n"	/* BIOS bug: clear IF	*/
        "       int     %[int_disk]	\n"
        "       sti			\n"	/* BIOS bug: set IF	*/
        "       movw    %%si, %%es	\n"	/* restore ES		*/
        "       movb    $0, %[errflg]	\n"
        "       adcb    $0, %[errflg]	\n"	/* error flag		*/
        "       movb    %%ah, %%al	\n"	/* error status		*/
        : [errflg] "=m" (errflg),		/* error flag, CF	*/
          "=a" (status),			/* AH = status		*/
          "=d" (dummy)				/* BIOS bug		*/
        : [int_disk] "i" (INT_DISK),
          "a" ((u16_t)DISK_READ << 8 | 1),	/* AH = 0x02, AL = 0x01	*/
          "c" (cylsec),				/* CX = cyls & sectors	*/
          "d" ((u16_t)head << 8 | driveprm.drive),	/* DX = hd, drv	*/
          [segment] "m" (segment),		/* data buffer segment	*/
          "b" ((u16_t)0)
        : "cc", "si", "memory"
      );

      if (errflg) {			/* reset, if error occured	*/
        u8_t errflg;
        u8_t status;

        __asm__ __volatile__ (
          "       int     %[int_disk]	\n"
          "       movb    $0, %[errflg]	\n"
          "       adcb    $0, %[errflg]	\n"	/* error flag		*/
          "       movb    %%ah, %%al	\n"	/* error status		*/
          : [errflg] "=m" (errflg),		/* error flag, CF	*/
            "=a" (status)			/* AH = status		*/
          : [int_disk] "i" (INT_DISK),
            "a" ((u16_t)DISK_RESET << 8),	/* AH = 0x00		*/
            "d" (driveprm.drive)		/* DL = drive		*/
          : "cc"
        );
						/* reset: stop on error	*/
        diskerror(errflg, status);		/* succesful?		*/
      }
      else {			/* exit loop on succesful execution	*/
        break;
      }
    }
  }
  diskerror(errflg, status);			/* succesful?		*/
}

/* read cached sector
read sector on cache miss, return it's segment address
- calls readphyssec
- driveprm must be set by initdisk
- if an error occurs, halts machine
- for use only in this .c file
input:	64 bit sector number
output:	16 bit segment address
*/
static u16_t readcachedsec(u64_t sector) {
  int i;
  u32_t mincnt = MAX_U32;			/* LRU cnt		*/
  u32_t oldpos;					/* LRU position		*/
  u16_t retseg;

  oldpos = 0;
  for (i = 0; i < driveprm.cacheentrynum; i ++) {  /* find sector in cache */
    if (driveprm.cacheeptr[i].readcnt &&
      driveprm.cacheeptr[i].sector == sector) {	/* cache hit		*/
      driveprm.cacheeptr[i].readcnt = ++ readcnt;
//      { u8_t c = getcolor(); setcolor(CLR_LGREEN);  printf("[%llu] ", sector); setcolor(c); }	//
      return driveprm.cacheseg + (i * driveprm.bytes >> 4);
    }
    if (driveprm.cacheeptr[i].readcnt < mincnt) {
      mincnt = driveprm.cacheeptr[i].readcnt;
      oldpos = i;
    }
  }

  driveprm.cacheeptr[oldpos].readcnt = ++ readcnt;	/* cache miss	*/
  driveprm.cacheeptr[oldpos].sector = sector;
  retseg = driveprm.cacheseg + (oldpos * driveprm.bytes >> 4);
  readphyssec(sector, retseg);
//  { u8_t c = getcolor(); setcolor(CLR_LRED);  printf("[%llu] ", sector); setcolor(c); }	//

  return retseg;
}

/* read bytes from disk
read bytes from disk to far address
- halts machine on error
- for use only in this .c file
input:	byte to read from
	size in bytes to read
	pointer to read to
output:	readed bytes at far pointer
*/
static void readdiskbytes(u64_t byteaddr, u32_t size, farptr_t dest) {
  while (size > 0) {
    u32_t count;
    farptr_t source;

    source.segment = readcachedsec(byteaddr / driveprm.bytes);
    source.offset = byteaddr % driveprm.bytes;
    count = MIN((u32_t)(driveprm.bytes - source.offset), size);
    memcpy_f(dest, source, count);

    byteaddr = byteaddr + count;
    size = size - count;
    dest = farptradd(dest, count);
  }
}

/* read bytes from partition
read bytes from partition to a far address
- halts machine on error
- for use only in this .c file
input:	byte to read from
	size in bytes to read
	far pointer to read to
output:	readed bytes at far pointer
*/
void readpartbytes(u64_t byteaddr, u32_t size, farptr_t dest) {
  if (byteaddr + size >= partprm.partsize * driveprm.bytes) {	/* beyond? */
    stoperror("Read beyond end of partition: %llu >= %llu.",
      byteaddr + size, partprm.partsize * driveprm.bytes);
  }
  readdiskbytes(byteaddr + partprm.partstart * driveprm.bytes, size, dest);
}

/* open file
open a govenfile, readfile and getfilesize functions will operate on this file
- use appropiate function for partition types
- stop on error
input:	filename, pointer to zero terminated string
output:	-
	halt on error
*/
void openfile(const char *fname) {
  const char *fn;

  initdisk(fname);	/* initialize partition, if need		*/
			/* if already initialized, then it does nothing	*/

  fn = fname;				/* file name after first space	*/
  while (fn[0] != '\0') {
    if (fn ++[0] == ':') {
      break;
    }
  }
  if (fn[0] == '\0') {
    stoperror("Wrong filename: %s.", fname);
  }

  switch (partprm.parttype) {
    case PARTTYPE_LINUX:		/* Linux partition		*/
      openext2file(fn);
      break;
    case PARTTYPE_FAT12:		/* FAT partition	*/
    case PARTTYPE_FAT16_32M:
    case PARTTYPE_FAT16:
    case PARTTYPE_FAT32:
    case PARTTYPE_FAT32_LBA:
    case PARTTYPE_FAT16_LBA:
      openfatfile(fn);
      break;
    default:				/* unknown partition type	*/
      stoperror("Can not open file: %s on partition type 0x%02x.",
        fname, partprm.parttype);
      break;
  }
}

/* get file size
get the size of a file
- use appropiate function for partition types
- stop on error
input:	-
output:	64 bit file size
	halt on error
*/
u64_t getfilesize() {
  switch (partprm.parttype) {
    case PARTTYPE_LINUX:		/* Linux partition		*/
      return getext2filesize();
      break;
    case PARTTYPE_FAT12:		/* FAT partition		*/
    case PARTTYPE_FAT16_32M:
    case PARTTYPE_FAT16:
    case PARTTYPE_FAT32:
    case PARTTYPE_FAT32_LBA:
    case PARTTYPE_FAT16_LBA:
      return getfatfilesize();
      break;
    default:				/* unknown partition type	*/
      stoperror("Can not get file size on partition type: 0x%02x.",
        partprm.parttype);
      break;
  }
}

/* read file contents near
read file contents for near address
- use appropiate function for partition types
- stop on error
input:	file byte position of starting address
	number of bytes to read
	far pointer to destination
output:	readed bytes at far pointer
	halt on error
*/
void readfile(u64_t pos, u32_t len, void *dest) {
  readfile_f(pos, len, farptr(dest));
}

/* read file contents far
read file contents for far address
- use appropiate function for partition types
- stop on error
input:	file byte position of starting address
	number of bytes to read
	far pointer to destination
output:	readed bytes at far pointer
	halt on error
*/
void readfile_f(u64_t pos, u32_t len, farptr_t dest) {
  switch (partprm.parttype) {
    case PARTTYPE_LINUX:		/* Linux partition		*/
      readext2file(pos, len, dest);
      break;
    case PARTTYPE_FAT12:		/* FAT partition	*/
    case PARTTYPE_FAT16_32M:
    case PARTTYPE_FAT16:
    case PARTTYPE_FAT32:
    case PARTTYPE_FAT32_LBA:
    case PARTTYPE_FAT16_LBA:
      readfatfile(pos, len, dest);
      break;
    default:				/* unknown partition type	*/
      stoperror("Can not read file on partition type: 0x%02x.",
        partprm.parttype);
      break;
  }
}
