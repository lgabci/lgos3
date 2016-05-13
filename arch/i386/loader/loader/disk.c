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

/* set status in inline asm statements
status variable must be %0
*/
// variable variable a %0 helyett
#define	SET_DISK_STATUS							   \
"	jc	.Lerror%=		\n"	/* error?		*/ \
"	xorb	%%ah, %%ah		\n"	/* no, status = 0	*/ \
"	jmp	.Lend%=			\n"				   \
".Lerror%=:				\n"	/* error		*/ \
"	orb	%%ah, %%ah		\n"				   \
"	jnz	.Lend%=			\n"	/* status == 0? */	   \
"	incb	%%ah			\n"	/* yes, set it to 1 */	   \
".Lend%=:				\n"				   \
"	movb	%%ah, %0		\n"

typedef struct {
  const u8_t errcode;			/* error code, status		*/
  const char *errtext;			/* error text			*/
} errtext_t;

typedef struct {			/* cache element	*/
  u64_t sector;				/* physical sector, LBA	*/
  u32_t readcnt;			/* counter, 0 = invalid	*/
} cachee_t;

typedef struct {
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
} driveprm_t;

typedef struct {
  int initialized;			/* initialized			*/
  u8_t partnum;				/* partition number on dev	*/
  u64_t partstart;			/* LBA partition start		*/
  u64_t partsize;			/* LBA partition size		*/
  u8_t parttype;			/* partition type		*/
} partprm_t;

typedef struct __attribute__ ((packed)) {	/* buffer for drive par	*/
  u16_t size;				/* size of buffer		*/
  u16_t flags;				/* information flags		*/
  u32_t cyls;				/* number of phys cyls		*/
  u32_t heads;				/* number of phys heads		*/
  u32_t secs;				/* sectors / track		*/
  u64_t totsecs;			/* total number of secs		*/
  u16_t bytes;				/* bytes / sector		*/
} extprms_t;

typedef struct __attribute__ ((packed)) {	/* disk address packet	*/
  u8_t size;				/* size of DAP, 10h		*/
  u8_t reserved;			/* reserved byte, 00h		*/
  u16_t seccount;			/* secs to transfer, 1		*/
  u16_t offset;				/* transfer buff offset		*/
  u16_t segment;			/* transfer buff segm.		*/
  u64_t sector;				/* sector number		*/
} dap_t;

typedef struct __attribute__ ((packed)) {	/* CHS address in MBR	*/
  u8_t head;		/* head						*/
  u8_t sec;		/* sector: 0-5 bits, cyl hi bits 6-7 bits	*/
  u8_t cyl;		/* cylinder low 8 bits				*/
} chs_t;

typedef struct __attribute__ ((packed)) {	/* MBR entry		*/
  u8_t bootflag;			/* bit 7.: bootable flag	*/
  chs_t firstchs;			/* 1.st absolute sect. in part.	*/
  u8_t type;				/* partition type		*/
  chs_t lastchs;			/* last absolute sector		*/
  u32_t firstlba;			/* LBA of 1.st absolute sector	*/
  u32_t numofsecs;			/* number of sectors		*/
} mbr_t;

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

static void diskerror(u8_t status);
static void initdisk(const char *dev);
static void readphyssec(u64_t sector, u16_t segment);
static u16_t readcachedsec(u64_t sector);
static void readdiskbytes(u64_t byteaddr, u32_t size, farptr_t dest);

/* print error message and halt
print disk error message and halt machine if status is not 0
- for use only in this .c file
input:	status of disk operation
output:	-
*/
static void diskerror(u8_t status) {
  u8_t i;
  char *text;

  if (status) {				/* if status means error	*/
    text = 0;
    for (i = 0; i < sizeof(errtexts) / sizeof(errtext_t); i ++) {
      if (errtexts[i].errcode == status) {
        text = (char *)errtexts[i].errtext;
      }
    }
    if (text == 0) {
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
"	callw	_stopfloppy		\n"	/* call asm function	*/
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
    printf("Initialize disk 0x%02x.\n", disk);
    driveprm.drive = disk;			/* slot for this disk	*/

    __asm__ __volatile__  (			/* check BIOS extension	*/
"	movb	%4, %%ah		\n"	/* AH = 0x41h		*/
"	movw	%5, %%bx		\n"	/* BX = 0x55aa		*/
"	movb	%6, %%dl		\n"	/* DL = drive		*/
"	int	%3			\n"

"	movw	%%bx, %1		\n"	/* cheksum		*/
"	movw	%%cx, %2		\n"	/* API bitmap		*/
	SET_DISK_STATUS

	: "=m" (status),		/* %0 */
	  "=m" (checksum),		/* %1 */
	  "=m" (apibitmap)		/* %2 */
	: "i" (INT_DISK),		/* %3 */
	  "i" (DISK_EXTCHK),		/* %4 */
	  "i" (0x55aa),			/* %5 */
	  "m" (disk)			/* %6 */
	: "cc", "ax", "bx", "cx", "dx"

    );
    driveprm.extbios = status == 0 && checksum == 0xaa55 && apibitmap & 0x1;

    if (driveprm.extbios) {			/* BIOS ext. found	*/
      extprms_t extprms;			/* buffer for drive params */

      extprms.size = 0x1a;			/* BIOS ext ver 1.x	*/
      extprms.flags = 0;			/* BIOS bug, must be 0	*/
      __asm__ __volatile__ (		/* ext get drive parameters	*/
"	movb	%2, %%ah		\n"
"	movb	%3, %%dl		\n"
"	leaw	%4, %%si		\n"
"	int	%1			\n"
	SET_DISK_STATUS

	: "=m" (status)			/* %0 */
	: "i" (INT_DISK),		/* %1 */
	  "i" (DISK_EXTGETPRM),		/* %2 */
	  "m" (disk),			/* %3 */
	  "m" (extprms)			/* %4 */
	: "cc", "ah", "dl", "di", "memory"
      );
      diskerror(status);			/* succesful?		*/

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
      u16_t cylsecs;
      u8_t heads;

      __asm__ __volatile__ (			/* get drive parameters	*/
"	movb	%4, %%ah		\n"	/* AH = 8		*/
"	movb	%6, %%dl		\n"	/* DL = drive		*/
"	pushw	%%es			\n"	/* save ES		*/
"	pushw	%%ds			\n"	/* BIOS bug: save DS	*/
"	int	%3			\n"
"	popw	%%ds			\n"	/* BIOS bug: restore DS	*/
"	popw	%%es			\n"	/* restore ES		*/

"	movb	%5, %%ah		\n"	/* BIOS bug:		*/
"	movb	%6, %%dl		\n"	/* must get status of	*/
"	int	%3			\n"	/* last operation	*/
"	sti				\n"	/* BIOS bug: int may disabled */

"	movw	%%cx, %1		\n"	/* max cyl & sector num	*/
"	movb	%%dh, %2		\n"	/* max head number	*/
	SET_DISK_STATUS

	: "=m" (status),		/* %0 */
	  "=m" (cylsecs),		/* %1 */
	  "=m" (heads)			/* %2 */
	: "i" (INT_DISK),		/* %3 */
	  "i" (DISK_GETPRM),		/* %4 */
	  "i" (DISK_GETSTAT),		/* %5 */
	  "m" (disk)			/* %6 */
	: "cc", "ax", "bl", "cx", "dx", "di", "si", "bp" /* BIOS bug: SI, BP */
      );
      if (status != 0 && disk == 0) {	/* unreported 360 KB floppy?	*/
        heads = 1;		/* if not exists, then first read	*/
        cylsecs = (39 << 8) + 9;	/* gets an error, and stops	*/
      }
      else {
        diskerror(status);			/* succesful?		*/
      }

      driveprm.cyls = ((cylsecs & 0xc0) << 2 | cylsecs >> 8) + 1; /* 0 based */
      driveprm.heads = heads + 1;			/* 0 based	*/
      driveprm.secs = cylsecs & 0x3f;			/* 1 based	*/
      driveprm.totsecs = driveprm.cyls * driveprm.heads * driveprm.secs;
      driveprm.bytes = 512;				/* bytes / sec	*/
    }

    if (diskcache == NULL) {				/* first time	*/
      farptr_t fp;

      fp = getbss(DISK_CACHESIZE, 0x10);
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

    printf("Total sectors: %llu, ", driveprm.totsecs);
    if (driveprm.cyls) {
      printf("CHS: %lu/%lu/%lu, ",
        driveprm.cyls, driveprm.heads, driveprm.secs);
    }
    printf("bytes/sector: %u, BIOS ext: %s.\n",
      driveprm.bytes, driveprm.extbios ? "found" : "not found");

    partprm.initialized = FALSE;	/* initialize partition		*/
    driveprm.initialized = TRUE;
  }

  if (! partprm.initialized || partprm.partnum != part) {
    if (part == 0xff) {		/* if no partition, the use whole disk	*/
      partprm.partstart = 0;
      partprm.partsize = driveprm.totsecs;
      printf("Using whole device: blocks %llu - %llu\n",
        partprm.partstart, partprm.partstart + partprm.partsize - 1);

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
        stoperror("Invalid partition signature: %02x.", mbrsign);
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

      printf("Partition %u: (0x%02x) %llu blocks %llu (CHS: %u/%u/%u) - %llu "
        "(CHS: %u/%u/%u)\n",
        part, mbrentry.type, partprm.partsize, partprm.partstart, firstcyl,
        mbrentry.firstchs.head, firstsec,
        partprm.partstart + partprm.partsize - 1,
        lastcyl, mbrentry.lastchs.head, lastsec);

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
  u8_t status;

  if (sector >= driveprm.totsecs) {
    stoperror("Read over disk: %llu (max. sector: %llu).", sector,
      driveprm.totsecs - 1);
  }

  if (driveprm.extbios) {			/* BIOS ext found	*/
    dap_t dap = {0x10, 0, 1, 0, segment, sector};	/* DAP		*/

    __asm__ __volatile__ (			/* ext. read		*/
"	movb	%2, %%ah		\n"	/* AH = 42h		*/
"	movb	%3, %%dl		\n"	/* BIOS disk ID		*/
"	leaw	%4, %%si		\n"	/* address of DAP	*/
"	int	%1			\n"
	SET_DISK_STATUS

	: "=m" (status)			/* %0 */
	: "i" (INT_DISK),		/* %1 */
	  "i" (DISK_EXTREAD),		/* %2 */
	  "m" (driveprm.drive),		/* %3 */
	  "m" (dap)
	: "cc", "ah", "dl", "si", "memory"
    );
  }
  else {					/* BIOS ext not found	*/
    u16_t cylsec;
    u8_t head;
    int i;

    head = sector / driveprm.secs % driveprm.heads;	/* head		*/
    cylsec = sector / driveprm.secs / driveprm.heads;	/* cylinder	*/
    cylsec = cylsec << 8 | (cylsec & 0x300) >> 2 | /* cyl 6 lo + 2 hi bits */
      (sector % driveprm.secs + 1);	/* sector 6 bits, 1 based	*/

    for (i = 0; i < DISK_RETRYCNT; i ++) {
      __asm__ __volatile__ (			/* read sectors		*/
"	movb	%2, %%ah		\n"	/* AH = 2		*/
"	movb	$1, %%al		\n"	/* only 1 sector	*/
"	movw	%3, %%cx		\n"	/* cyl & sector number	*/
"	movb	%4, %%dh		\n"	/* head number		*/
"	movb	%5, %%dl		\n"	/* drive number		*/
"	xorw	%%bx, %%bx		\n"	/* offset		*/
"	movw	%6, %%si		\n"	/* segment -> SI	*/
"	pushw	%%es			\n"	/* save ES		*/
"	movw	%%si, %%es		\n"	/* segment		*/
"	stc				\n"	/* BIOS bug: set CF	*/
"	int	%1			\n"
"	sti				\n"	/* BIOS bug: set IF	*/
"	popw	%%es			\n"	/* restore ES		*/
	SET_DISK_STATUS

	: "=m" (status)			/* %0 */
	: "i" (INT_DISK),		/* %1 */
	  "i" (DISK_READ),		/* %2 */
	  "m" (cylsec),			/* %3 */
	  "m" (head),			/* %4 */
	  "m" (driveprm.drive),		/* %5 */
	  "m" (segment)			/* %6 */
	: "cc", "ax", "bx", "cx", "dx", "si"
      );

      if (status) {			/* reset, if error occured	*/
        u8_t status;

        __asm__ __volatile__ (
"	movb	%2, %%ah		\n"	/* AH = 0		*/
"	movb	%3, %%dl		\n"	/* BIOS disk ID		*/
"	int	%1			\n"
	SET_DISK_STATUS

	: "=m" (status)			/* %0 */
	: "i" (INT_DISK),		/* %1 */
	  "i" (DISK_RESET),		/* %2 */
	  "m" (driveprm.drive)		/* %3 */
	: "cc", "ah", "dl"
        );
						/* reset: stop on error	*/
        diskerror(status);			/* succesful?		*/
      }
      else {			/* exit loop on succesful execution	*/
        break;
      }
    }
  }
  diskerror(status);			/* succesful?		*/
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
      { u8_t c = getcolor(); setcolor(CLR_LGREEN);  printf("[%llu] ", sector); setcolor(c); }	//
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
  { u8_t c = getcolor(); setcolor(CLR_LRED);  printf("[%llu] ", sector); setcolor(c); }	//

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
    case PARTTYPE_FAT12:		/* FAT partition	*/
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
