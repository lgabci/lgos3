/* LGOS3 loader - ext2 filesystem */
__asm__ (".code16gcc");				/* compile 16 bit code	*/

#include "ext2.h"
#include "disk.h"
#include "console.h"
#include "lib.h"

#define	PATHSEP			'/'	/* path separator		*/

#define	EXT2_SUPERBLK_START	0x400	/* start of 1st superblock	*/

#define	EXT2_SUPER_MAGIC	0xef53	/* Ext2 fs magic number		*/

#define	EXT2_VALID_FS		1	/* fs unmounted cleanly		*/
#define	EXT2_ERROR_FS		2	/* fs errors detected		*/

#define	EXT2_ERRORS_CONTINUE	1	/* continue as if nothing happened */
#define EXT2_ERRORS_RO		2	/* remount read-only		*/
#define	EXT2_ERRORS_PANIC	3	/* cause a kernel panic		*/

#define	EXT2_OS_LINUX		0	/* Linux			*/
#define	EXT2_OS_HURD		1	/* GNU HURD			*/
#define	EXT2_OS_MASIX		2	/* MASIX			*/
#define	EXT2_OS_FREEBSD		3	/* FreeBSD			*/
#define	EXT2_OS_LITES		4	/* Lites			*/

#define	EXT2_GOOD_OLD_REV	0	/* Revision 0			*/
#define	EXT2_DYNAMIC_REV	1	/* Revision 1			*/

#define	EXT2_GOOD_OLD_FIRST_INO	11	/* rev0: the 1.st non-reserved inode */
#define	EXT2_GOOD_OLD_INODE_SIZE		\
				128	/* rev0: inode structure size	*/

#define	EXT2_FEATURE_COMPAT_DIR_PREALLOC	\
				0x0001	/* Block pre-allocation for new dirs */
#define	EXT2_FEATURE_COMPAT_IMAGIC_INODES	\
				0x0002
#define	EXT3_FEATURE_COMPAT_HAS_JOURNAL		\
				0x0004	/* An Ext3 journal exists	*/
#define	EXT2_FEATURE_COMPAT_EXT_ATTR		\
				0x0008	/* Ext. inode attributes are present */
#define	EXT2_FEATURE_COMPAT_RESIZE_INO		\
				0x0010	/* Non-standard inode size used	*/
#define	EXT2_FEATURE_COMPAT_DIR_INDEX		\
				0x0020	/* Directory indexing (HTree)	*/

#define	EXT2_FEATURE_INCOMPAT_COMPRESSION	\
				0x0001	/* Disk/File compression is used     */
#define	EXT2_FEATURE_INCOMPAT_FILETYPE		\
				0x0002
#define	EXT3_FEATURE_INCOMPAT_RECOVER		\
				0x0004
#define	EXT3_FEATURE_INCOMPAT_JOURNAL_DEV	\
				0x0008
#define	EXT2_FEATURE_INCOMPAT_META_BG		\
				0x0010

#define	EXT2_MOUNT_INCOMPAT	/* handled this incompat feats.	*/	\
				EXT2_FEATURE_INCOMPAT_FILETYPE

#define	EXT2_FEATURE_RO_COMPAT_SPARSE_SUPER	\
				0x0001	/* Sparse Superblock		*/
#define	EXT2_FEATURE_RO_COMPAT_LARGE_FILE	\
				0x0002	/* Large file supp., 64bit file size */
#define	EXT2_FEATURE_RO_COMPAT_BTREE_DIR	\
				0x0004	/* Binary tree sorted dir. files     */

#define	EXT2_LZV1_ALG		0x00000001
#define	EXT2_LZRW3A_ALG		0x00000002
#define	EXT2_GZIP_ALG		0x00000004
#define	EXT2_BZIP2_ALG		0x00000008
#define	EXT2_LZO_ALG		0x00000010

					/* constant i-node numbers	*/
#define	EXT2_BAD_INO		1	/* bad blocks inode		*/
#define	EXT2_ROOT_INO		2	/* root directory inode		*/
#define	EXT2_ACL_IDX_INO	3	/* ACL ind. inode (deprecated?)	*/
#define	EXT2_ACL_DATA_INO	4	/* ACL data inode (deprecated?)	*/
#define	EXT2_BOOT_LOADER_INO	5	/* boot loader inode		*/
#define	EXT2_UNDEL_DIR_INO	6	/* undelete directory inode	*/

			/* i_mode values:	-- file format --	*/
#define	EXT2_S_IFMASK		0xf000	/* mode mask			*/
#define	EXT2_S_IFSOCK		0xc000	/* socket			*/
#define	EXT2_S_IFLNK		0xa000	/* symbolic link		*/
#define	EXT2_S_IFREG		0x8000	/* regular file			*/
#define	EXT2_S_IFBLK		0x6000	/* block device			*/
#define	EXT2_S_IFDIR		0x4000	/* directory			*/
#define	EXT2_S_IFCHR		0x2000	/* character device		*/
#define	EXT2_S_IFIFO		0x1000	/* fifo				*/
			/* -- process execution user/group override --	*/
#define	EXT2_S_ISUID		0x0800	/* Set process User ID		*/
#define	EXT2_S_ISGID		0x0400	/* Set process Group ID		*/
#define	EXT2_S_ISVTX		0x0200	/* sticky bit			*/
					/* 	-- access rights --	*/
#define	EXT2_S_IRUSR		0x0100	/* user read			*/
#define	EXT2_S_IWUSR		0x0080	/* user write			*/
#define	EXT2_S_IXUSR		0x0040	/* user execute			*/
#define	EXT2_S_IRGRP		0x0020	/* group read			*/
#define	EXT2_S_IWGRP		0x0010	/* group write			*/
#define	EXT2_S_IXGRP		0x0008	/* group execute		*/
#define	EXT2_S_IROTH		0x0004	/* others read			*/
#define	EXT2_S_IWOTH		0x0002	/* others write			*/
#define	EXT2_S_IXOTH		0x0001	/* others execute		*/

					/* i_flag values		*/
#define	EXT2_SECRM_FL		0x00000001	/* secure deletion	*/
#define	EXT2_UNRM_FL		0x00000002	/* record for undelete	*/
#define	EXT2_COMPR_FL		0x00000004	/* compressed file	*/
#define	EXT2_SYNC_FL		0x00000008	/* synchronous updates	*/
#define	EXT2_IMMUTABLE_FL	0x00000010	/* immutable file	*/
#define	EXT2_APPEND_FL		0x00000020	/* append only		*/
#define	EXT2_NODUMP_FL		0x00000040	/* do not dump/delete file */
#define	EXT2_NOATIME_FL		0x00000080	/* do not update .i_atime  */
				/* -- Reserved for compression usage --	*/
#define	EXT2_DIRTY_FL		0x00000100	/* Dirty (modified)	*/
#define	EXT2_COMPRBLK_FL	0x00000200	/* compressed blocks	*/
#define	EXT2_NOCOMPR_FL		0x00000400	/* access raw compressed data */
#define	EXT2_ECOMPR_FL		0x00000800	/* compression error	*/
				/* -- End of compression flags --	*/
#define	EXT2_BTREE_FL		0x00001000	/* b-tree format directory */
#define	EXT2_INDEX_FL		0x00001000	/* hash indexed directory  */
#define	EXT2_IMAGIC_FL		0x00002000	/* AFS directory	*/
#define	EXT3_JOURNAL_DATA_FL	0x00004000	/* journal file data	*/
#define	EXT2_RESERVED_FL	0x80000000	/* reserved for ext2 library */

				/* defined i-node file type values	*/
#define	EXT2_FT_UNKNOWN		0	/* Unknown File Type		*/
#define	EXT2_FT_REG_FILE	1	/* Regular File			*/
#define	EXT2_FT_DIR		2	/* Directory File		*/
#define	EXT2_FT_CHRDEV		3	/* Character Device		*/
#define	EXT2_FT_BLKDEV		4	/* Block Device			*/
#define	EXT2_FT_FIFO		5	/* Buffer File			*/
#define	EXT2_FT_SOCK		6	/* Socket File			*/
#define	EXT2_FT_SYMLINK		7	/* Symbolic Link		*/

#define	EXT2_INOD_FLBLKS	12	/* i-node: first level blocks	*/
#define	EXT2_INOD_TOTBLKS	15	/* i-node: total blocks		*/

typedef u32_t blocknum_t;		/* block number type		*/

struct ext2prm_s {			/* Ext2 file system parameters	*/
  u32_t revlevel;			/* revision level		*/
  u16_t minorrevlevel;			/* minor revision level		*/
  u32_t totalblockscount;		/* total number of blocks	*/
  u32_t blockspergroup;			/* blocks / block group		*/
  u32_t blocksize;			/* file system block size	*/
  u32_t blockgroups;			/* number of block groups	*/
  u32_t totalinodescount;		/* total number of i-nodes	*/
  u32_t inodespergroup;			/* i-node / block group		*/
  u16_t inodesize;			/* size of an i-node		*/
  u32_t fcomp;				/* compatible features		*/
  u32_t fincomp;			/* incompatible features	*/
  u32_t frocomp;			/* read only features		*/
  u16_t bgdtstart;	/* byte address of block group descriptor table	*/
};
typedef struct ext2prm_s ext2prm_t;

struct __attribute__ ((packed)) superblock_s {	/* Ext2 superblock	*/
  u32_t s_inodes_count;		/* total number of inodes		*/
  u32_t s_blocks_count;		/* total number of blocks		*/
  u32_t	s_r_blocks_count;  /* number of block reserved for superuser	*/
  u32_t s_free_blocks_count;	/* total number of free blocks		*/
  u32_t s_free_inodes_count;	/* total number of free inodes		*/
  u32_t s_first_data_block;	/* the first data block (superblock)	*/
  u32_t s_log_block_size;	/* block size = 1024 << s_log_block_size */
  u32_t s_log_frag_size;	/* fragment size = 1024 << s_log_frag_size;  */
  u32_t s_blocks_per_group;	/* total number of blocks per group	*/
  u32_t s_frags_per_group;	/* total number of fragments per group	*/
  u32_t s_inodes_per_group;	/* total number of inodes per group	*/
  u32_t s_mtime;		/* the last time the file system was mounted */
  u32_t s_wtime;		/* the last write access to the file system  */
  u16_t s_mnt_count;		/* how many time the file system was mounted */
  u16_t s_max_mnt_count;	/* max. mount count before a full check	*/
  u16_t s_magic;		/* value identifying the file system as Ext2 */
  u16_t s_state;		/* the file system state		*/
  u16_t s_errors;		/* what should do when an error is detected  */
  u16_t s_minor_rev_level;	/* the minor revision level		*/
  u32_t s_lastcheck;		/* UNIX time of the last file system check   */
  u32_t s_checkinterval;	/* max. time interval between fs checks	*/
  u32_t s_creator_os;		/* the os that created the file system	*/
  u32_t s_rev_level;		/* revision level value			*/
  u16_t s_def_resuid;		/* the default user id for reserved blocks   */
  u16_t s_def_resgid;		/* default group id for reserved blocks	*/
				/* -- EXT2_DYNAMIC_REV Specific --	*/
  u32_t s_first_ino;		/*  first inode useable for standard files   */
  u16_t s_inode_size;		/* size of the inode structure		*/
  u16_t s_block_group_nr;	/* block group hosting this superblk struct. */
  u32_t s_feature_compat;	/* bitmask of compatible features	*/
  u32_t s_feature_incompat;	/* bitmask of incompatible features	*/
  u32_t s_feature_ro_compat;	/* bitmask of "read-only" features	*/
  u8_t s_uuid[16];		/* value used as the volume id		*/
  u8_t s_volume_name[16];	/* volume name, mostly unusued		*/
  u8_t s_last_mounted[64];	/* where the file system was last mounted    */
  u32_t s_algo_bitmap;		/* used by compression algorithms	*/
				/* -- Performance Hints --		*/
  u8_t s_prealloc_blocks;    /* num of blocks should pre-allocate, reg. file */
  u8_t s_prealloc_dir_blocks;	/* num of blocks should pre-allocate, dir.   */
  u8_t __align0__[2];		/* alignment				*/
				/* -- Journaling Support --		*/
  u8_t s_journal_uuid[16];	/* the uuid of the journal superblock	*/
  u32_t s_journal_inum;		/* inode number of the journal file	*/
  u32_t s_journal_dev;		/* device number of the journal file	*/
  u32_t s_last_orphan;		/* the first inode to delete		*/
				/* -- Directory Indexing Support --	*/
  u32_t s_hash_seed[4];		/* the seeds used for the hash algorithm     */
  u8_t s_def_hash_version;	/* the default hash version used	*/
  u8_t __align1__[3];		/* padding - reserved for future expansion   */
				/* -- Other options --			*/
  u32_t s_default_mount_options; /* the default mount options		*/
  u32_t s_first_meta_bg;	/* block group ID of the 1st meta block group */
};
typedef struct superblock_s superblock_t;

struct __attribute__ ((packed)) bgdt_s {	/* block group desc	*/
  u32_t bg_block_bitmap;	/* first block of the "block bitmap"	*/
  u32_t bg_inode_bitmap;	/* first block of the "inode bitmap"	*/
  u32_t bg_inode_table;		/* first block of the "inode table"	*/
  u16_t bg_free_blocks_count;	/* the total number of free blocks	*/
  u16_t bg_free_inodes_count;	/* the total number of free inodes	*/
  u16_t bg_used_dirs_count;	/* number of inodes allocated to dir.s	*/
  u16_t bg_pad;			/* padding on a 32bit boundary		*/
  u8_t bg_reserved[12];		/* reserved space for future revisions	*/
};
typedef struct bgdt_s bgdt_t;

struct __attribute__ ((packed)) inode_s {	/* i-node structure	*/
  u16_t i_mode;			/* the format and the access rights	*/
  u16_t i_uid;			/* 16bit user id			*/
  u32_t i_size;			/* lower 32-bit of the file size	*/
  u32_t i_atime;		/* last time this inode was accessed	*/
  u32_t i_ctime;		/* when the inode was created		*/
  u32_t i_mtime;		/* last time this inode was modified	*/
  u32_t i_dtime;		/* when the inode was deleted		*/
  u16_t i_gid;			/* the group having access to this file	*/
  u16_t i_links_count;		/* how many times this inode is linked	*/
  u32_t i_blocks;		/* 512-bytes blocks reserved to inode	*/
  u32_t i_flags;		/* how the ext2 to access the data	*/
  u32_t i_osd1;			/* OS dependant value			*/
  blocknum_t i_block[EXT2_INOD_TOTBLKS];  /* blocks containing the data	*/
  u32_t i_generation;		/* the file version			*/
  u32_t i_file_acl;		/* block number of the extended attr.s	*/
  u32_t i_dir_acl;	/* rev 1: for reg. files: high 32 bits of size	*/
  u32_t i_faddr;	/* location of the file fragment, always 0	*/
  u8_t i_osd2[12];		/* OS dependant structure		*/
};
typedef struct inode_s inode_t;

struct __attribute__ ((packed)) direntry_s {	/* directory entry	*/
  u32_t inode;		/* i-node number of file entry, 0 = not used	*/
  u16_t rec_len;		/* next entry from start of this entry	*/
  u8_t name_len;		/* length of the name in bytes		*/
  u8_t file_type;		/* value used to indicate file type	*/
  u8_t name[];			/* name of the entry			*/
};
typedef struct direntry_s direntry_t;

static inode_t g_inode;			/* global i-node (opened file)	*/
static inode_t *g_pinode;		/* pointer to global i-node	*/
static ext2prm_t ext2prm;

static inode_t getinode(u32_t inode);
static blocknum_t getblocknum(const inode_t *pinode, blocknum_t blocknum);
static u64_t getisize(const inode_t *pinode);
static u16_t getdnamelen(const direntry_t *direntry);
static void readcont(const inode_t *pinode, u64_t pos, u32_t size,
  farptr_t dest);
static u32_t getinodenum(const char *fpath);

/* initialize Ext2 parameters
initialize Ext2 parameters: blocksize, blockgroups, inodesize, fcomp,
                            fincomp, frocomp, bgdtstart
- stop on error
input:	-
output:	0 - error, 1 - initialized
*/
int initext2() {
  superblock_t sblk;

  readpartbytes(EXT2_SUPERBLK_START,		/* read superblock	*/
    sizeof(sblk), farptr(&sblk));

  if (sblk.s_magic != EXT2_SUPER_MAGIC) {	/* check magic value	*/
    return 0;					/* Not an Ext2 fs	*/
  }
  if (sblk.s_rev_level > EXT2_DYNAMIC_REV) {	/* check fs version	*/
    stoperror("Unknown Ext2 version: %lu.%u.", sblk.s_rev_level,
      sblk.s_minor_rev_level);
  }

  ext2prm.revlevel = sblk.s_rev_level;
  ext2prm.minorrevlevel = sblk.s_minor_rev_level;

  ext2prm.totalblockscount = sblk.s_blocks_count;
  ext2prm.blockspergroup = sblk.s_blocks_per_group;
  ext2prm.totalinodescount = sblk.s_inodes_count;
  ext2prm.inodespergroup = sblk.s_inodes_per_group;
  ext2prm.blocksize = 1024 << sblk.s_log_block_size;
  ext2prm.blockgroups = (sblk.s_blocks_count + sblk.s_blocks_per_group - 1) /
    sblk.s_blocks_per_group;

  {			/* check if number of block groups is OK	*/
    u32_t blockgroups2;
    blockgroups2 = (sblk.s_inodes_count + sblk.s_inodes_per_group - 1) /
      sblk.s_inodes_per_group;
    if (ext2prm.blockgroups != blockgroups2) {
      stoperror("Blocks count / blocks per group (%lu) not equals inodes "
        "count / inodes per block (%lu).", ext2prm.blockgroups, blockgroups2);
    }
  }

  if (ext2prm.revlevel == EXT2_DYNAMIC_REV) {	/* EXT2_DYNAMIC_REV	*/
    ext2prm.inodesize = sblk.s_inode_size;
    ext2prm.fcomp = sblk.s_feature_compat;
    ext2prm.fincomp = sblk.s_feature_incompat;
    ext2prm.frocomp = sblk.s_feature_ro_compat;
  }
  else {					/* EXT2_GOOD_OLD_REV	*/
    ext2prm.inodesize = EXT2_GOOD_OLD_INODE_SIZE;
    ext2prm.fcomp = 0;
    ext2prm.fincomp = 0;
    ext2prm.frocomp = 0;
  }
  ext2prm.bgdtstart =	/* 2. block on a 1KiB block filesystem, 1. on larger */
    ext2prm.blocksize == 0x400 ? 0x800 : ext2prm.blocksize;

  if (ext2prm.revlevel == EXT2_DYNAMIC_REV) {
    if ((sblk.s_feature_incompat & ~EXT2_MOUNT_INCOMPAT) != 0) {
      stoperror("Unimplemented incompatible features: 0x%08lx.",
        sblk.s_feature_incompat & ~EXT2_MOUNT_INCOMPAT);
    }
  }

  g_pinode = NULL;		/* no file opened			*/
  return 1;			/* successful Ext2 initialization	*/
}

/* get an i-node
read an i-node from the file system
- for use only in this .c file
- stop on error
input:	i-node number
output:	i-node
	halts machine on error
*/
static inode_t getinode(u32_t inodenum) {
  u32_t blkgroupnum;
  u32_t localinodenum;
  bgdt_t bgdt;
  u8_t bitmap;
  inode_t inode;

  if (inodenum < 1 || inodenum > ext2prm.totalinodescount) {
    stoperror("I-node number %u is not in valid i-node range (1 - %u).",
      inodenum, ext2prm.totalinodescount);	/* check i-node number	*/
  }

  	/* number of block group and local i-node in block group	*/
  blkgroupnum = (inodenum - 1) / ext2prm.inodespergroup;
  localinodenum = (inodenum - 1) % ext2prm.inodespergroup;

  readpartbytes(ext2prm.bgdtstart + blkgroupnum * sizeof(bgdt_t),
    sizeof(bgdt_t), farptr(&bgdt));		/* read block group	*/

  readpartbytes(bgdt.bg_inode_bitmap * ext2prm.blocksize +
    localinodenum / 8, 1, farptr(&bitmap));	/* check i-node bitmap	*/
  if ((bitmap & 1 << localinodenum % 8) == 0) {
    stoperror("I-node is free: %lu.", inodenum);
  }

  readpartbytes(bgdt.bg_inode_table * ext2prm.blocksize +  /* read i-node */
    localinodenum * ext2prm.inodesize, sizeof(inode_t), farptr(&inode));

  return inode;
}

/* get block number
get the block number of a giventh block of a file (of an i-node)
- for use only in this .c file
- stop on error
input:	pointer to the i-node
	block number, 0 if not exists
output:	number of block in device (partition)
*/
static blocknum_t getblocknum(const inode_t *pinode, blocknum_t blocknum) {
  int i;			/* loop variable			*/
  int j;			/* loop variable			*/
  blocknum_t entriesperblock;	/* block entries in one fs block	*/
  blocknum_t entries;		/* block entries on current level	*/
  blocknum_t entry[EXT2_INOD_TOTBLKS - EXT2_INOD_FLBLKS + 1];	/* entries */

  if (blocknum < EXT2_INOD_FLBLKS) {		/* direct blocks	*/
    return (*pinode).i_block[blocknum];
  }

  blocknum = blocknum - EXT2_INOD_FLBLKS;	/* indirect blocks	*/
  entries = 1;
  entriesperblock = ext2prm.blocksize / sizeof(blocknum_t);
  for (i = 0; i < EXT2_INOD_TOTBLKS - EXT2_INOD_FLBLKS; i ++) {
    entries = entries * entriesperblock;	/* entries on this level */

    if (blocknum >= entries) {		/* it is beyond this block	*/
      blocknum = blocknum - entries;
    }
    else {				/* it is in this block		*/
      for (j = 0; j <= i; j ++) {
        entry[i - j + 1] = blocknum % entriesperblock; /* entry on this level */
        blocknum = blocknum / entriesperblock;
      }
      entry[0] = i;
      break;
    }
  }

  if (i < EXT2_INOD_TOTBLKS - EXT2_INOD_FLBLKS) {	/* entry is found  */
    blocknum_t retblock;

    for (j = 0; j <= i + 1; j ++) {
      if (j == 0) {			/* direct block level in i-node	*/
        retblock = (*pinode).i_block[entry[0] + EXT2_INOD_FLBLKS];
      }
      else {				/* indirect level in blocks	*/
        readpartbytes(retblock * ext2prm.blocksize + entry[j] *
          sizeof(blocknum_t), sizeof(blocknum_t), farptr(&retblock));
      }
      if (retblock == 0) {			/* no block found	*/
        return 0;
      }
    }

    return retblock;				/* found		*/
  }

  return 0;					/* block not found	*/
}

/* get file size
get file size in bytes from i-node
- for use only in this .c file
- stop on error
input:	pointer to the i-node
output:	64 bit file size
*/
static u64_t getisize(const inode_t *pinode) {
  return (u64_t)pinode->i_size				/* low 32 bits	*/
         | (ext2prm.frocomp & EXT2_FEATURE_RO_COMPAT_LARGE_FILE /* large */
            && (pinode->i_mode & EXT2_S_IFMASK) == EXT2_S_IFREG	/* regular */
              ? (u64_t)pinode->i_dir_acl << 32		/* upper 32 bit	*/
              : 0				/* else upper 32 bit	*/
           );
}

/* get directory entry name length
get directory entry name length in bytes from direnctory entry
- for use only in this .c file
- stop on error
input:	pointer to the directory entry
output:	16 bit length
*/
static u16_t getdnamelen(const direntry_t *direntry) {
  return (u16_t)direntry->name_len			/* low 8 bits	*/
    | (ext2prm.fincomp & EXT2_FEATURE_INCOMPAT_FILETYPE
    ? 0						/* don't use file_type	*/
    : (u16_t)direntry->file_type << 8);	/* file_type: upper 8 bits	*/
}

/* read contents
read file or directory contents
- for use only in this .c file
- stop on error
input:	pointer to the i-node
	file byte position of starting address
	number of bytes to read
	far pointer to destination
output:	readed bytes at far pointer
	halt on error
*/
static void readcont(const inode_t *pinode, u64_t pos, u32_t size,
  farptr_t dest) {

  if ((pinode->i_mode & EXT2_S_IFMASK) != EXT2_S_IFLNK &&
    (pinode->i_mode & EXT2_S_IFMASK) != EXT2_S_IFREG &&
    (pinode->i_mode & EXT2_S_IFMASK) != EXT2_S_IFDIR) {
    stoperror("Read attempt on not a regular file or directory or symlink.");
  }

  if (pos + size > getisize(pinode)) {	/* don't read beyond end of file */
    stoperror("Read over end of file: %llu > %llu.",
      pos + size, getisize(pinode));
  }

  if ((pinode->i_mode & EXT2_S_IFMASK) == EXT2_S_IFLNK &&
    getisize(pinode) < sizeof(pinode->i_block)) {
    /* if symlink length < 60 bytes, then it stored in the i-node	*/
    memcpy_f(dest, farptr((u8_t *)pinode->i_block + pos), size);
  }
  else {
    u32_t inblkpos;				/* pos within fs block	*/
    u32_t readsize;				/* read this many bytes	*/

    inblkpos = pos % ext2prm.blocksize;
    for (; size > 0; size = size - readsize) {	/* read fs blocks	*/
      blocknum_t blocknum;

      readsize = MIN(ext2prm.blocksize - inblkpos, size);  /* read size	*/
      blocknum = getblocknum(pinode, pos / ext2prm.blocksize);

      if (blocknum > 0) {		/* if block exist, then read	*/
        readpartbytes(blocknum * ext2prm.blocksize + inblkpos, readsize, dest);
      }
      else {				/* sparse block			*/
        memset_f(dest, 0, readsize);	/* fill with zeros		*/
      }

      pos = pos + readsize;
      dest = farptradd(dest, readsize);

      inblkpos = 0;		/* next read at beginning of block	*/
    }
  }
}

/* get inode number
get the i-node number of a file (added with full path)
- for use only in this .c file
- stop on error
input:	filename, pointer to zero terminated string
output:	i-node number of the file
	halt on error
*/
static u32_t getinodenum(const char *fpath) {
  u32_t inodenum;
  inode_t inode;
  const char *f;
  size_t fpathlen;
  size_t i;

  inodenum = EXT2_ROOT_INO;		/* root i-node			*/
  inode = getinode(inodenum);		/* directory i-node		*/

  fpathlen = strlen(fpath);
  for (f = fpath; (i = strtoken(&f, PATHSEP)); f = f + i) {
    char fname[i + 1];			/* walk trough the whole path	*/
    int foundflg;

    memcpy(&fname, f, i);
    fname[i] = '\0';

    foundflg = FALSE;
    if ((inode.i_mode & EXT2_S_IFMASK) == EXT2_S_IFDIR) {	/* dir?	*/
      u32_t isize;		/* i-node size, directory always 32 bit	*/
      u32_t dirpos;		/* position in directory entry		*/
      direntry_t direntry;	/* directory entry			*/

      isize = getisize(&inode);		/* read entries			*/
      for (dirpos = 0; dirpos < isize; dirpos = dirpos + direntry.rec_len) {
        readcont(&inode, dirpos, sizeof(direntry_t), farptr(&direntry));
        if (getdnamelen(&direntry) == i) {	/* dir. entry name len	*/
          char tempname[i + 1];			/* read dir entry name	*/

          readcont(&inode, dirpos + sizeof(direntry_t), i, farptr(&tempname));
          tempname[i] = '\0';
          if (strcmp(fname, tempname) == 0) {	/* dir. entry name equals */
            inodenum = direntry.inode;	/* i-node num of next level	*/
            inode = getinode(inodenum);		/* directory i-node	*/

            if ((inode.i_mode & EXT2_S_IFMASK) == EXT2_S_IFLNK) {
              char firstchr;			/* first char of symlink  */
              u32_t symlen;	/* symlink length, always 32 bit only	*/
              u32_t newpathlen;

              symlen = getisize(&inode);	/* symlink length	*/
              readcont(&inode, 0, 1, farptr(&firstchr));  /* first char	*/
              if (firstchr == PATHSEP) {	/* absolute symlink	*/
                newpathlen = fpathlen - (f - fpath) - i + symlen;
              }
              else {				/* relative symlink	*/
                newpathlen = fpathlen - i + symlen;
              }

              {
                char newpath[newpathlen + 1];	/* new path		*/
                char *symcont;			/* read symlink here	*/

                if (firstchr == PATHSEP) {	/* absolute symlink	*/
                  symcont = newpath;
                }
                else {				/* relative symlink	*/
                  memcpy(newpath, fpath, f - fpath);
                  symcont = &newpath[f - fpath];
                }

                readcont(&inode, 0, symlen, farptr(symcont));
                strcpy(&symcont[symlen], &fpath[f - fpath + i]);

                return getinodenum(newpath);
              }
            }

            foundflg = TRUE;			/* found the entry	*/
            break;				/* dir. entry found	*/
          }
        }
      }
    }

    if (! foundflg) {		/* entry not found in dir i-node	*/
      stoperror("File not found: %s.", fpath);
    }
  }

  if ((inode.i_mode & EXT2_S_IFMASK) != EXT2_S_IFREG) {	/* not a regular */
    stoperror("Not a regular file: %s.", fpath);
  }

  return inodenum;
}

/* open file
sets the global g_inode and g_pinode variables to the i-node of the given
filename
- stop on error
input:	filename, pointer to zero terminated string
output:	set g_inode
	set g_pinode
	halt on error
*/
void openext2file(const char *fname) {
  g_inode = getinode(getinodenum(fname));
  g_pinode = &g_inode;
}

/* get file size
get the size of a file pointed by g_inode
- stop on error
input:	-
output:	64 bit file size
	halt on error
*/
u64_t getext2filesize() {
  if (g_pinode == NULL) {
    stoperror("No file opened before getext2filesize.");
  }
  return getisize(g_pinode);
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
void readext2file(u64_t pos, u32_t len, farptr_t dest) {
  if (g_pinode == NULL) {
    stoperror("No file opened before readext2file.");
  }
  readcont(g_pinode, pos, len, dest);
}
