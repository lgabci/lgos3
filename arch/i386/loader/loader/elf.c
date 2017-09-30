/* LGOS3 loader - ELF functions */
__asm__ (".code16gcc");				/* compile 16 bit code */

#include "console.h"
#include "disk.h"
#include "lib.h"
#include "elf.h"

#define RMENTRY "rmstart"		/* real mode entry point name	*/

					/* ELF 32 bit types		*/
typedef u32_t Elf32_Addr_t;		/* unsigned program address	*/
typedef u16_t Elf32_Half_t;		/* unsigned medium integer	*/
typedef u32_t Elf32_Off_t;		/* unsigned file offset		*/
typedef s32_t Elf32_Sword_t;		/* signed large integer		*/
typedef u32_t Elf32_Word_t;		/* unsigned large integer	*/

					/* ELF 64 bit types		*/
typedef u64_t Elf64_Addr_t;		/* unsigned program address	*/
typedef u16_t Elf64_Half_t;		/* unsigned small integer	*/
typedef u64_t Elf64_Off_t;		/* unsigned file offset		*/
typedef s32_t Elf64_Sword_t;		/* signed medium integer	*/
typedef s64_t Elf64_Sxword_t;		/* signed large integer		*/
typedef u32_t Elf64_Word_t;		/* unsigned medium integer	*/
typedef u64_t Elf64_Xword_t;		/* unsigned large integer	*/
typedef u8_t Elf64_Byte_t;		/* unsigned tiny integer	*/
typedef u16_t Elf64_Section_t;		/* section index (unsigned)	*/

					/* ELF identification		*/
#define EI_MAG0		0		/* file identification		*/
#define EI_MAG1		1		/* file identification		*/
#define EI_MAG2		2		/* file identification		*/
#define EI_MAG3		3		/* file identification		*/
#define EI_CLASS	4		/* file class			*/
#define EI_DATA		5		/* data encoding		*/
#define EI_VERSION	6		/* file version			*/
#define EI_OSABI	7		/* OS/ABI identification	*/
#define EI_ABIVERSION	8		/* ABI version			*/
#define EI_PAD		9		/* start of padding bytes	*/
#define EI_NIDENT	16		/* size of e_ident		*/

#define ELFMAG0		0x7f		/* e_ident[EI_MAG0]		*/
#define ELFMAG1		'E'		/* e_ident[EI_MAG1]		*/
#define ELFMAG2		'L'		/* e_ident[EI_MAG2]		*/
#define ELFMAG3		'F'		/* e_ident[EI_MAG3]		*/

					/* e_ident[EI_CLASS]		*/
#define ELFCLASSNONE	0		/* invalid class		*/
#define ELFCLASS32	1		/* 32-bit objects		*/
#define ELFCLASS64	2		/* 64-bit objects		*/

					/* e_ident[EI_DATA]		*/
#define ELFDATANONE	0		/* invalid data encoding	*/
#define ELFDATA2LSB	1		/* little endian		*/
#define ELFDATA2MSB	2		/* big endian			*/

					/* e_ident[EI_VERSION]		*/
#define EV_NONE		0		/* invalid version		*/
#define EV_CURRENT	1		/* current version		*/

					/* e_ident[EI_OSABI]		*/
#define ELFOSABI_SYSV	0		/* System V ABI			*/
#define ELFOSABI_HPUX	1		/* HP-UX operating system	*/
#define ELFOSABI_STANDALOLNE	255	/* standalone (embedded) system	*/

					/* e_type (object file type)	*/
#define ET_NONE		0		/* no file type			*/
#define ET_REL		1		/* relocatable file		*/
#define ET_EXEC		2		/* executable file		*/
#define ET_DYN		3		/* shared object file		*/
#define ET_CORE		4		/* core file			*/
#define ET_LOOS		0xfe00		/* environment specific		*/
#define ET_HIOS		0xfeff		/* environment specific		*/
#define ET_LOPROC	0xff00		/* processor specific		*/
#define ET_HIPROC	0xffff		/* processor specific		*/

					/* machine type			*/
#define EM_NONE		0		/* no machine			*/
#define EM_M32		1		/* AT&T WE 32100		*/
#define EM_SPARC	2		/* SPARC			*/
#define EM_386		3		/* Intel 80386			*/
#define EM_68K		4		/* Motorola 68000		*/
#define EM_88K		5		/* Motorola 88000		*/
#define EM_860		7		/* Intel 80860			*/
#define EM_MIPS		8		/* MIPS RS3000			*/
#define EM_X86_64	62		/* x86-64			*/

					/* special section indexes	*/
#define SHN_UNDEF	0		/* undefined section		*/
#define SHN_LORESERVE	0xff00		/* lower bound of reserved ind.	*/
#define SHN_LOPROC	0xff00		/* processor specific lower	*/
#define SHN_HIPROC	0xff1f		/* processor specific upper	*/
#define SHN_LOOS	0xff20		/* environment specific lower	*/
#define SHN_HIOS	0xff3f		/* environment specific upper	*/
#define SHN_ABS		0xfff1		/* absolute values' section	*/
#define SHN_COMMON	0xfff2		/* common symbols' section	*/
#define SHN_HIRESERVE	0xffff		/* upper bound of reserved ind.	*/

					/* sh_type, section type	*/
#define SHT_NULL	0		/* unused section header	*/
#define SHT_PROGBITS	1		/* contains information		*/
#define SHT_SYMTAB	2		/* contains linker symbol table	*/
#define SHT_STRTAB	3		/* contains string table	*/
#define SHT_RELA	4		/* cont. RELA reloc. entries	*/
#define SHT_HASH	5		/* contains symbol hash table	*/
#define SHT_DYNAMIC	6		/* cont. dynamic linking tables	*/
#define SHT_NOTE	7		/* contains note information	*/
#define SHT_NOBITS	8		/* contains uninitialized space	*/
#define SHT_REL		9		/* cont. REL reloc. entries	*/
#define SHT_SHLIB	10		/* reserved			*/
#define SHT_DYNSYM	11		/* cont. dynamic loader sym tab	*/
#define SHT_LOOS	0x60000000	/* environment specific use	*/
#define SHT_HIOS	0x6fffffff	/* environment specific use	*/
#define SHT_LOPROC	0x70000000	/* processor specific use	*/
#define SHT_HIPROC	0x7fffffff	/* processor specific use	*/
#define SHT_LOUSER	0x80000000	/* application specific use	*/
#define SHT_HIUSER	0xffffffff	/* application specific use	*/

					/* sh_flags, section attributes	*/
#define SHF_WRITE	1		/* writable data		*/
#define SHF_ALLOC	2		/* allocatable in memory	*/
#define SHF_EXECINSTR	4		/* executable instructions	*/
#define SHF_MASKOS	0x0f000000	/* environment specific use	*/
#define SHF_MASKPROC	0xf0000000	/* processor specific use	*/

#define STN_UNDEF	0		/* 1st symbol table entry	*/

					/* sh_info, ELF32_ST_BIND	*/
#define STB_LOCAL	0		/* not visible outside the obj.	*/
#define STB_GLOBAL	1		/* visible to all obj files	*/
#define STB_WEAK	2		/* lower precedence than global	*/
#define STB_LOOS	10		/* environment specific use	*/
#define STB_HIOS	12
#define STB_LOPROC	13		/* processor specific use	*/
#define STB_HIPROC	15

					/* sh_info, ELF32_ST_TYPE	*/
#define STT_NONE	0		/* type is not specified	*/
#define STT_OBJECT	1		/* data object			*/
#define STT_FUNC	2		/* function entry point		*/
#define STT_SECTION	3		/* associated with a section	*/
#define STT_FILE	4	/* source file associated with obj file	*/
#define STB_LOOS	10		/* environment specific use	*/
#define STB_HIOS	12
#define STB_LOPROC	13		/* processor specific use	*/
#define STB_HIPROC	15

					/* relocation types		*/
#define R_386_NONE	0
#define R_386_32	1
#define R_386_PC32	2
#define R_386_GOT32	3
#define R_386_PLT32	4
#define R_386_COPY	5
#define R_386_GLOB_DAT	6
#define R_386_JMP_SLOT	7
#define R_386_RELATIVE	8
#define R_386_GOTOFF	9
#define R_386_GOTPC	10

					/* segment types, p_type	*/
#define PT_NULL		0		/* unused entry			*/
#define PT_LOAD		1		/* loadable segment		*/
#define PT_DYNAMIC	2		/* dynamic linking tables	*/
#define PT_INTERP	3	/* program interpreter path name	*/
#define PT_NOTE		4		/* note sections		*/
#define PT_SHLIB	5		/* reserved			*/
#define PT_PHDR		6		/* program header table		*/
#define PT_LOOS		0x60000000	/* environment specific use	*/
#define PT_HIOS		0x6fffffff
#define PT_LOPROC	0x70000000	/* processor specific use	*/
#define PT_HIPROC	0x7fffffff

					/* segment attributes, p_flags	*/
#define PF_X		0x1		/* execute permission		*/
#define PF_W		0x2		/* write permission		*/
#define PF_R		0x4		/* read permission		*/
#define PF_MASKOS	0x00ff0000	/* environment specific use	*/
#define PF_MASKPROC	0xff000000	/* processor specific use	*/

					/* dynamic table entries	*/
#define DT_NULL		0		/* end of dyamic array		*/
#define DT_NEEDED	1	/* str table offset of a needed library	*/
#define DT_PLTRELSZ	2	/* total size of relocation entries	*/
#define DT_PLTGOT	3	/* addr assoc. with the linkage table	*/
#define DT_HASH		4	/* addr of the symbol hash table	*/
#define DT_STRTAB	5	/* addr of the dynamic string table	*/
#define DT_SYMTAB	6	/* addr of the dynamic symbol table	*/
#define DT_RELA		7	/* addr of a reloc table, RELA entries	*/
#define DT_RELASZ	8	/* size in bytes of DT_RELA reloc table	*/
#define DT_RELAENT	9	/* size in bytes of each DT_RELA entry	*/
#define DT_STRSZ	10	/* size in bytes of string table	*/
#define DT_SYMENT	11	/* size in bytes of each sym tab entry	*/
#define DT_INIT		12	/* addr of the initialization function	*/
#define DT_FINI		13	/* addr of the termination function	*/
#define DT_SONAME	14	/* str tab off of the name of this so	*/
#define DT_RPATH	15	/* str tab off of a sh lib search path	*/
#define DT_SYMBOLIC	16	/* modifies symbol resolution algorithm	*/
#define DT_REL		17	/* addr of a reloc table, REL entries	*/
#define DT_RELSZ	18	/* size in bytes of DT_REL reloc table	*/
#define DT_RELENT	19	/* size in bytes of each DT_REL entry	*/
#define DT_PLTREL	20	/* type of reloc entry f proc link tab	*/
#define DT_DEBUG	21	/* reserved for debugger use		*/
#define DT_TEXTREL	22	/* relocations for a non-writable seg	*/
#define DT_JUMPREL	23	/* addr of the rel in proc linkage tab	*/
#define DT_BIND_NOW	24	/* loader should process all relocs	*/
#define DT_INIT_ARRAY	25	/* ptr to an array of ptrs to init func	*/
#define DT_FINI_ARRAY	26	/* ptr to an array of ptrs to term func	*/
#define DT_INIT_ARRAYSZ	27	/* size in b of the array of init funcs	*/
#define DT_FINI_ARRAYSZ	28	/* size in b of the array of term funcs	*/
#define DT_LOOS		0x60000000	/* environment specific use	*/
#define DT_HIOS		0x6fffffff
#define DT_LOPROC	0x70000000	/* processor specific use	*/
#define DT_HIPROC	0x7fffffff

#define ELF32_ST_BIND(i)	((i) >> 4)
#define ELF32_ST_TYPE(i)	((i) & 0x0f)
#define ELF32_ST_INFO(b, t)	(((b) << 4) + ((t) & 0x0f))

#define ELF32_R_SYM(i)		((i) >> 8)
#define ELF32_R_TYPE(i)		((unsigned char)(i))
#define ELF32_R_INFO(s, t)	(((s) << 8) + (unsigned char)(t))

#define ELF64_R_SYM(i)		((i) >> 32)
#define ELF64_R_TYPE(i)		((i) & 0xffffffffL)
#define ELF64_R_INFO(s, t)	(((s) << 32) + ((t) & 0xffffffffL))

struct __attribute__ ((packed)) Elf32_Ehdr_s {	/* ELF 32 header	*/
  unsigned char e_ident[EI_NIDENT];	/* ELF identification		*/
  Elf32_Half_t e_type;			/* object file type		*/
  Elf32_Half_t e_machine;		/* machine type			*/
  Elf32_Word_t e_version;		/* object file version		*/
  Elf32_Addr_t e_entry;			/* entry point address		*/
  Elf32_Off_t e_phoff;			/* program header offset	*/
  Elf32_Off_t e_shoff;			/* section header offset	*/
  Elf32_Word_t e_flags;			/* processor specific flags	*/
  Elf32_Half_t e_ehsize;		/* ELF header size		*/
  Elf32_Half_t e_phentsize;		/* size of program header entry	*/
  Elf32_Half_t e_phnum;			/* # of program header entries	*/
  Elf32_Half_t e_shentsize;		/* size of section header entry	*/
  Elf32_Half_t e_shnum;			/* # of section header entries	*/
  Elf32_Half_t e_shstrndx;		/* sect name string table index	*/
};
typedef struct Elf32_Ehdr_s Elf32_Ehdr_t;

struct __attribute__ ((packed)) Elf64_Ehdr_s {	/* ELF 64 header	*/
  unsigned char e_ident[EI_NIDENT];	/* ELF identification		*/
  Elf64_Half_t e_type;			/* object file type		*/
  Elf64_Half_t e_machine;		/* machine type			*/
  Elf64_Word_t e_version;		/* object file version		*/
  Elf64_Addr_t e_entry;			/* entry point address		*/
  Elf64_Off_t e_phoff;			/* program header offset	*/
  Elf64_Off_t e_shoff;			/* section header offset	*/
  Elf64_Word_t e_flags;			/* processor specific flags	*/
  Elf64_Half_t e_ehsize;		/* ELF header size		*/
  Elf64_Half_t e_phentsize;		/* size of program header entry	*/
  Elf64_Half_t e_phnum;			/* # of program header entries	*/
  Elf64_Half_t e_shentsize;		/* size of section header entry	*/
  Elf64_Half_t e_shnum;			/* # of section header entries	*/
  Elf64_Half_t e_shstrndx;		/* sect name string table index	*/
};
typedef struct Elf64_Ehdr_s Elf64_Ehdr_t;

struct __attribute__ ((packed)) Elf32_Shdr_s {	/* ELF32 section header	*/
  Elf32_Word_t sh_name;			/* name of the section		*/
  Elf32_Word_t sh_type;			/* section type			*/
  Elf32_Word_t sh_flags;		/* section flags and attributes	*/
  Elf32_Addr_t sh_addr;			/* virtual memory address	*/
  Elf32_Off_t sh_offset;		/* file byte offset		*/
  Elf32_Word_t sh_size;			/* section size in bytes	*/
  Elf32_Word_t sh_link;			/* section header table index	*/
  Elf32_Word_t sh_info;			/* extra information		*/
  Elf32_Word_t sh_addralign;		/* alignment constraints	*/
  Elf32_Word_t sh_entsize;		/* fixed size entries size	*/
};
typedef struct Elf32_Shdr_s Elf32_Shdr_t;

struct __attribute__ ((packed)) Elf64_Shdr_s {	/* ELF64 section header	*/
  Elf64_Word_t sh_name;			/* name of the section		*/
  Elf64_Word_t sh_type;			/* section type			*/
  Elf64_Xword_t sh_flags;		/* section flags and attributes	*/
  Elf64_Addr_t sh_addr;			/* virtual memory address	*/
  Elf64_Off_t sh_offset;		/* file byte offset		*/
  Elf64_Xword_t sh_size;		/* section size in bytes	*/
  Elf64_Word_t sh_link;			/* section header table index	*/
  Elf64_Word_t sh_info;			/* extra information		*/
  Elf64_Xword_t sh_addralign;		/* alignment constraints	*/
  Elf64_Xword_t sh_entsize;		/* fixed size entries size	*/
};
typedef struct Elf64_Shdr_s Elf64_Shdr_t;

struct __attribute__ ((packed)) Elf32_Sym_s {	/* ELF32 sym tab entry	*/
  Elf32_Word_t st_name;			/* symbol string table index	*/
  Elf32_Addr_t st_value;		/* value of the symbol		*/
  Elf32_Word_t st_size;			/* size of the symbol		*/
  unsigned char st_info;		/* type and binding attributes	*/
  unsigned char st_other;		/* reserved			*/
  Elf32_Half_t st_shndx;		/* section header index		*/
};
typedef struct Elf32_Sym_s Elf32_Sym_t;

struct __attribute__ ((packed)) Elf64_Sym_s {	/* ELF64 sym tab entry	*/
  Elf64_Word_t st_name;			/* symbol string table index	*/
  unsigned char st_info;		/* type and binding attributes	*/
  unsigned char st_other;		/* reserved			*/
  Elf64_Half_t st_shndx;		/* section header index		*/
  Elf64_Addr_t st_value;		/* value of the symbol		*/
  Elf64_Xword_t st_size;		/* size of the symbol		*/
};
typedef struct Elf64_Sym_s Elf64_Sym_t;

struct __attribute__ ((packed)) Elf32_Rel_s {	/* ELF32 REL entry	*/
  Elf32_Addr_t r_offset;		/* address of reference		*/
  Elf32_Word_t r_info;			/* symbol ind and type of reloc	*/
};
typedef struct Elf32_Rel_s Elf32_Rel_t;

struct __attribute__ ((packed)) Elf64_Rel_s {	/* ELF64 REL entry	*/
  Elf64_Addr_t r_offset;		/* address of reference		*/
  Elf64_Xword_t r_info;			/* symbol ind and type of reloc	*/
};
typedef struct Elf64_Rel_s Elf64_Rel_t;

struct __attribute__ ((packed)) Elf32_Rela_s {	/* ELF32 RELA entry	*/
  Elf32_Addr_t r_offset;		/* address of reference		*/
  Elf32_Word_t r_info;			/* symbol ind and type of reloc	*/
  Elf32_Sword_t r_addend;		/* constant part of expression	*/
};
typedef struct Elf32_Rela_s Elf32_Rela_t;

struct __attribute__ ((packed)) Elf64_Rela_s {	/* ELF64 RELA entry	*/
  Elf64_Addr_t r_offset;		/* address of reference		*/
  Elf64_Xword_t r_info;			/* symbol ind and type of reloc	*/
  Elf64_Sxword_t r_addend;		/* constant part of expression	*/
};
typedef struct Elf64_Rela_s Elf64_Rela_t;

struct __attribute__ ((packed)) Elf32_Phdr_s {	/* ELF32 program header	*/
  Elf32_Word_t p_type;			/* type of segment		*/
  Elf32_Off_t p_offset;			/* offset in file		*/
  Elf32_Addr_t p_vaddr;			/* virtual address in memory	*/
  Elf32_Addr_t p_paddr;			/* reserved			*/
  Elf32_Word_t p_filesz;		/* size of segment in file	*/
  Elf32_Word_t p_memsz;			/* size of segment in memory	*/
  Elf32_Word_t p_flags;			/* segment attributes		*/
  Elf32_Word_t p_align;			/* alignment of segment		*/
};
typedef struct Elf32_Phdr_s Elf32_Phdr_t;

struct __attribute__ ((packed)) Elf64_Phdr_s {	/* ELF64 program header	*/
  Elf64_Word_t p_type;			/* type of segment		*/
  Elf64_Word_t p_flags;			/* segment attributes		*/
  Elf64_Off_t p_offset;			/* offset in file		*/
  Elf64_Addr_t p_vaddr;			/* virtual address in memory	*/
  Elf64_Addr_t p_paddr;			/* reserved			*/
  Elf64_Xword_t p_filesz;		/* size of segment in file	*/
  Elf64_Xword_t p_memsz;		/* size of segment in memory	*/
  Elf64_Xword_t p_align;		/* alignment of segment		*/
};
typedef struct Elf64_Phdr_s Elf64_Phdr_t;

struct __attribute__ ((packed)) Elf32_Dyn_s {	/* ELF32 dynamic struct	*/
  Elf32_Sword_t dtag;			/* type of entry		*/
  union __attribute__ ((packed)) {
    Elf32_Word_t d_val;			/* integer values		*/
    Elf32_Addr_t d_ptr;			/* program virtual addresses	*/
  } d_un;
};
typedef struct Elf32_Dyn_s Elf32_Dyn_t;

struct __attribute__ ((packed)) Elf64_Dyn_s {	/* ELF64 dynamic struct	*/
  Elf64_Sxword_t dtag;			/* type of entry		*/
  union __attribute__ ((packed)) {
    Elf64_Xword_t d_val;		/* integer values		*/
    Elf64_Addr_t d_ptr;			/* program virtual addresses	*/
  } d_un;
};
typedef struct Elf64_Dyn_s Elf64_Dyn_t;

#define ELFTYPE_NONE			0
#define ELFTYPE_I386			1
#define ELFTYPE_X86_64			2

int strtest(Elf64_Off_t offset, const char *name);
void loadprogheaders(Elf64_Off_t phoff, Elf64_Half_t phentsize,
  Elf64_Half_t phnum, farptr_t *entry);
void getsection(Elf64_Off_t shoff, Elf64_Half_t shentsize, Elf64_Half_t shnum,
  Elf64_Half_t index, Elf64_Word_t *sh_type, Elf64_Off_t *sh_offset,
  Elf64_Xword_t *sh_size, Elf64_Word_t *sh_link);
void getsym(Elf64_Off_t offset, Elf64_Half_t symesize, Elf64_Xword_t symnum,
  Elf64_Xword_t index, Elf64_Word_t *st_name, Elf64_Addr_t *st_value,
  Elf64_Xword_t *st_size, unsigned char *st_info, unsigned char *st_other,
  Elf64_Half_t *st_shndx);
Elf64_Addr_t getrmentry(Elf64_Off_t shoff, Elf64_Half_t shentsize,
  Elf64_Half_t shnum);

/* test string against file content at file offset (string table)
input:	file offset
	pointer to string
output:	1 = strings equal, 0 = strings not equal
*/
int strtest(Elf64_Off_t offset, const char *name) {
  char c;

  if (offset == 0) {
    return 0;
  }

  do {
    readfile(offset ++, 1, &c);
  }  while (*name ++ == c && c != 0);

  return *(name - 1) == c;
}

/* load program headers
input:	offset of program header table in Elf file
	size in bytes of one entry
	number of entries
	pointer to a far ptr entry to set 1st program header address
output:	-
*/
void loadprogheaders(Elf64_Off_t phoff, Elf64_Half_t phentsize,
  Elf64_Half_t phnum, farptr_t *entry) {
  union {
    Elf32_Phdr_t p32;
    Elf64_Phdr_t p64;
  } phdr;
  Elf64_Word_t p_type;			/* type of segment		*/
  Elf64_Off_t p_offset;			/* offset in file		*/
  Elf64_Addr_t p_paddr;			/* reserved			*/
  Elf64_Xword_t p_filesz;		/* size of segment in file	*/
  Elf64_Xword_t p_memsz;		/* size of segment in memory	*/
  Elf64_Half_t i;
  Elf64_Addr_t last_top;

  if (phoff == 0 || phnum == 0) {
    stoperror("No program header found.");
  }

  last_top = 0;
  for (i = 0; i < phnum; i ++) {
    readfile(phoff + i * phentsize, phentsize, &phdr);

    switch (phentsize) {			/* 32 or 64 bit Elf	*/
      case sizeof(Elf32_Phdr_t):
        p_type = phdr.p32.p_type;
        p_offset = phdr.p32.p_offset;
        p_paddr = phdr.p32.p_paddr;
        p_filesz = phdr.p32.p_filesz;
        p_memsz = phdr.p32.p_memsz;
        break;
      case sizeof(Elf64_Phdr_t):
        p_type = phdr.p64.p_type;
        p_offset = phdr.p64.p_offset;
        p_paddr = phdr.p64.p_paddr;
        p_filesz = phdr.p64.p_filesz;
        p_memsz = phdr.p64.p_memsz;
        break;
    default:
      stoperror("Bad program header entry size: %u.", phentsize);
      break;
    }
    if (i == 0) {				/* 1st prog header	*/
      last_top = p_paddr;
    }

    if (p_type == PT_LOAD) {			/* loadable segment	*/
      farptr_t fp;
      Elf64_Addr_t gap;	/* gap between this and last program headers	*/

      if (p_memsz < p_filesz) {
        stoperror("Memory size is less than file size of the segment: "
          "%llu < %llu", p_memsz, p_filesz);
      }
      gap = p_paddr - last_top;
      fp = malloc(p_memsz + gap, 1);	/* alloc mem for program header	*/
      if (i == 0) {			/* 1st prog header address	*/
        *entry = fp;
      }
      printf("0x%llx (+ 0x%llx) @ 0x%llx --> 0x%04x:%04x\n", p_filesz,
        p_memsz - p_filesz, p_offset, fp.segment, fp.offset);
      readfile_f(p_offset, p_filesz, fp);		/* read segment	*/
      memset_f(farptradd(fp, p_filesz), 0, p_memsz - p_filesz);
      last_top = p_paddr + p_memsz;
    }
    else {
      stoperror("Bad ELF file: only loadable segments are allowed in program header table.");
    }

  }
}

/* get section data
input:	offset of section table in file
	section entry size in bytes
	number section entries
	index of section
	pointer to type
	pointer to offset
	pointer to size
	pointer to link
output:	type, offset, size, link filled with data
	halts on error
*/
void getsection(Elf64_Off_t shoff, Elf64_Half_t shentsize, Elf64_Half_t shnum,
  Elf64_Half_t index, Elf64_Word_t *sh_type, Elf64_Off_t *sh_offset,
  Elf64_Xword_t *sh_size, Elf64_Word_t *sh_link) {
  union {
    Elf32_Shdr_t s32;
    Elf64_Shdr_t s64;
  } shdr;

  if (index >= shnum) {			/* we are in the table?		*/
    stoperror("Section index out of section table.");
  }

  readfile(shoff + index * shentsize, shentsize, &shdr);	/* read	*/

  switch (shentsize) {			/* 32 or 64 bits?		*/
    case sizeof(Elf32_Shdr_t):
      *sh_type = shdr.s32.sh_type;
      *sh_offset = shdr.s32.sh_offset;
      *sh_size = shdr.s32.sh_size;
      *sh_link = shdr.s32.sh_link;
      break;
    case sizeof(Elf64_Shdr_t):
      *sh_type = shdr.s64.sh_type;
      *sh_offset = shdr.s64.sh_offset;
      *sh_size = shdr.s64.sh_size;
      *sh_link = shdr.s64.sh_link;
      break;
    default:
      stoperror("Bad section header entry size: %u.", shentsize);
      break;
  }
}

/* get sym entry data
input:	offset of section table in file
	section entry size in bytes
	number section entries
	index of section
	pointer to type
	pointer to offset
	pointer to size
	pointer to link
output:	type, offset, size, link filled with data
	halts on error
*/
void getsym(Elf64_Off_t offset, Elf64_Half_t symesize, Elf64_Xword_t symnum,
  Elf64_Xword_t index, Elf64_Word_t *st_name, Elf64_Addr_t *st_value,
  Elf64_Xword_t *st_size, unsigned char *st_info, unsigned char *st_other,
  Elf64_Half_t *st_shndx) {
  union {
    Elf32_Sym_t s32;
    Elf64_Sym_t s64;
  } sym;

  if (index >= symnum) {		/* we are in the table?		*/
    stoperror("Symbol index out of symbol table.");
  }

  readfile(offset + index * symesize, symesize, &sym);		/* read	*/

  switch (symesize) {			/* 32 or 64 bits?		*/
    case sizeof(Elf32_Sym_t):
      *st_name = sym.s32.st_name;
      *st_value = sym.s32.st_value;
      *st_size = sym.s32.st_size;
      *st_info = sym.s32.st_info;
      *st_other = sym.s32.st_other;
      *st_shndx = sym.s32.st_shndx;
      break;
    case sizeof(Elf64_Sym_t):
      *st_name = sym.s64.st_name;
      *st_value = sym.s64.st_value;
      *st_size = sym.s64.st_size;
      *st_info = sym.s64.st_info;
      *st_other = sym.s64.st_other;
      *st_shndx = sym.s64.st_shndx;
      break;
    default:
      stoperror("Bad symbol entry size: %u.", symesize);
      break;
  }
}

/* get real mode entry point
input:	offset of section header table in Elf file
	size in bytes of one entry
	number of entries
output:	real mode entry point
	halts on error
*/
Elf64_Addr_t getrmentry(Elf64_Off_t shoff, Elf64_Half_t shentsize,
  Elf64_Half_t shnum) {
  if (shoff == 0 || shnum == 0) {
    stoperror("No section table found.");
  }

  Elf64_Half_t i;
  for (i = 0; i < shnum; i ++) {	/* read all sections		*/
    Elf64_Word_t sh_type;		/* section data			*/
    Elf64_Off_t sh_offset;
    Elf64_Xword_t sh_size;
    Elf64_Word_t sh_link;

    getsection(shoff, shentsize, shnum, i, &sh_type, &sh_offset, &sh_size,
      &sh_link);

    if (i == SHN_UNDEF) {		/* NULL section			*/
      if (sh_type != SHT_NULL) {
        stoperror("Bad section header.");
      }
    }
    else if (sh_type == SHT_SYMTAB) {	/* symbol table found		*/
      Elf64_Xword_t j;
      int symesize = 0;			/* sym entry size in bytes	*/
      Elf64_Word_t str_sh_type;		/* string table			*/
      Elf64_Off_t str_sh_offset;
      Elf64_Xword_t str_sh_size;
      Elf64_Word_t str_sh_link;

      if (sh_link == SHN_UNDEF) {	/* there is a string table?	*/
        stoperror("No string table for the symbol table.");
      }

      getsection(shoff, shentsize, shnum, sh_link, /* read str table	*/
        &str_sh_type, &str_sh_offset, &str_sh_size, &str_sh_link);
      if (str_sh_type != SHT_STRTAB) {
        stoperror("String table is invalid.");
      }

      switch (shentsize) {		/* Elf32 or Elf64?		*/
        default:
        case sizeof(Elf32_Shdr_t):
          symesize = sizeof(Elf32_Sym_t);
          break;
        case sizeof(Elf64_Shdr_t):
          symesize = sizeof(Elf64_Sym_t);
          break;
      }

      for (j = 0; j < sh_size / symesize; j ++) { /* check symbols	*/
        Elf64_Word_t st_name;		/* symbol string table index	*/
        Elf64_Addr_t st_value;		/* value of the symbol		*/
        Elf64_Xword_t st_size;		/* size of the symbol		*/
        unsigned char st_info;		/* type and binding attributes	*/
        unsigned char st_other;		/* reserved			*/
        Elf64_Half_t st_shndx;		/* section header index		*/

        getsym(sh_offset, symesize, sh_size / symesize,	/* get symbol	*/
          j, &st_name, &st_value, &st_size, &st_info, &st_other, &st_shndx);

        if (strtest(str_sh_offset + st_name, RMENTRY)) {
          return st_value;	/* return value, if name is equals	*/
        }
      }
    }
  }

  stoperror("Real mode entry point (%s) not found.", RMENTRY);
}

/* load Elf file into memory
input:	address of far pointer to entry point
output:	1 = loaded, 0 = not loaded
*/
int loadelf(farptr_t *entry) {
  unsigned char elftype;		/* ELF file type: i386/x86-64	*/
  Elf32_Ehdr_t ehdr32;			/* ELF32 header			*/
  Elf64_Ehdr_t ehdr64;			/* ELF64 header			*/
  Elf64_Off_t phoff;			/* program header offset	*/
  Elf64_Half_t phentsize;		/* size of program header entry	*/
  Elf64_Half_t phnum;			/* # of program header entries	*/
  Elf64_Off_t shoff;			/* section header offset	*/
  Elf64_Half_t shentsize;		/* size of section header entry	*/
  Elf64_Half_t shnum;			/* # of section header entries	*/

  readfile(0, EI_NIDENT, &ehdr32.e_ident);	/* check ELF magic val	*/
  if (ehdr32.e_ident[EI_MAG0] != ELFMAG0 ||
    ehdr32.e_ident[EI_MAG1] != ELFMAG1 ||
    ehdr32.e_ident[EI_MAG2] != ELFMAG2 ||
    ehdr32.e_ident[EI_MAG3] != ELFMAG3) {
    return 0;
  }
  printf("ELF loader.\n");

  elftype = ELFTYPE_NONE;
  if (ehdr32.e_ident[EI_CLASS] == ELFCLASS32 &&	/* read ELF header	*/
    ehdr32.e_ident[EI_DATA] == ELFDATA2LSB) {
    readfile(0, sizeof(Elf32_Ehdr_t), &ehdr32);
    if (ehdr32.e_machine == EM_386) {
      elftype = ELFTYPE_I386;
    }
  }
  else if (ehdr32.e_ident[EI_CLASS] == ELFCLASS64 &&
    ehdr32.e_ident[EI_DATA] == ELFDATA2LSB) {
    readfile(0, sizeof(Elf64_Ehdr_t), &ehdr64);
    if (ehdr64.e_machine == EM_X86_64) {
      elftype = ELFTYPE_X86_64;
    }
  }

  switch (elftype) {			/* check type and version	*/
    case ELFTYPE_I386:
      if (ehdr32.e_type != ET_EXEC) {
        stoperror("Bad ELF type.");
      }
      if (ehdr32.e_version != EV_CURRENT) {
        stoperror("Bad ELF version.");
      }
      if (ehdr32.e_ehsize != sizeof(Elf32_Ehdr_t)) {
        stoperror("Bad ELF header.");
      }
      phoff = ehdr32.e_phoff;
      phentsize = ehdr32.e_phentsize;
      phnum = ehdr32.e_phnum;
      shoff = ehdr32.e_shoff;
      shentsize = ehdr32.e_shentsize;
      shnum = ehdr32.e_shnum;
      break;
    case ELFTYPE_X86_64:
      if (ehdr64.e_type != ET_EXEC) {
        stoperror("Bad ELF type.");
      }
      if (ehdr64.e_version != EV_CURRENT) {
        stoperror("Bad ELF version.");
      }
      if (ehdr64.e_ehsize != sizeof(Elf64_Ehdr_t)) {
        stoperror("Bad ELF header.");
      }
      phoff = ehdr64.e_phoff;
      phentsize = ehdr64.e_phentsize;
      phnum = ehdr64.e_phnum;
      shoff = ehdr64.e_shoff;
      shentsize = ehdr64.e_shentsize;
      shnum = ehdr64.e_shnum;
      break;
    default:
      stoperror("Unknown type of ELF file.");
      break;
  }

  loadprogheaders(phoff, phentsize, phnum, entry);
  *entry = farptradd(*entry, getrmentry(shoff, shentsize, shnum));

  return 1;					/* successful	*/
}
