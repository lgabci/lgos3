/* LGOS3 i386 paging	*/

#include "types.h"
#include "paging.h"

#define PG_SIZE 0x1000			/* page size		*/

#define PG_P	1			/* present value	*/
#define PG_NP	0			/* not present value	*/
#define PG_RW	1			/* read/write value	*/
#define PG_RO	0			/* read only value	*/
#define PG_U	1			/* user value		*/
#define PG_S	0			/* supervisor value	*/

#define PG_SH_PD 0x16			/* page directory shift	*/
#define PG_SH_PT 0x0c			/* page table shift	*/

#define PG_MASK_PD 0xffc00000	/* page directory addr mask	*/
#define PG_MASK_PT 0x003ff000	/* page table addr mask		*/

#define PTBL_ADDR 0xffc00000		/* page tbls lin addr	*/
#define PDIR_ADDR 0xff800000		/* page dir lin addr	*/

union u_pde {				/* page directory entry	*/
  struct s_pde {
    unsigned int p        : 1;		/* present bit		*/
    unsigned int rw       : 1;		/* read/write bit	*/
    unsigned int us       : 1;		/* user/supervisor bit	*/
    unsigned int          : 2;		/* reserved bits	*/
    unsigned int a        : 1;		/* accessed bit		*/
    unsigned int          : 3;		/* reserved bits	*/
    unsigned int avl      : 3;		/* available bits	*/
    unsigned int pg_frame : 20;		/* page frame address	*/
  } s;
  u32_t v;
} __attribute__ ((packed));
typedef union u_pde t_pde;

union u_pte {				/* page table entry	*/
  struct s_pte {
    unsigned int p        : 1;		/* present bit		*/
    unsigned int rw       : 1;		/* read/write bit	*/
    unsigned int us       : 1;		/* user/supervisor bit	*/
    unsigned int          : 2;		/* reserved bits	*/
    unsigned int a        : 1;		/* accessed bit		*/
    unsigned int d        : 1;		/* dirty bit		*/
    unsigned int          : 2;		/* reserved bits	*/
    unsigned int avl      : 3;		/* available bits	*/
    unsigned int pg_frame : 20;		/* page frame address	*/
  } s;
  u32_t v;
} __attribute__ ((packed));
typedef union u_pte t_pte;

#define PG_CNT (PG_SIZE / sizeof(t_pde))	/* page entries / page	*/

/*
//extern const void *PTABLE_ADDR;
//static t_pde *pd = (t_pde *)PTABLE_ADDR;
*/

static t_pde *get_pdbr();
static void set_pdbr(t_pde *pdbr);
static void flush_tlb();

/* get PDB register
in:	-
out:	PDBR
*/
static t_pde *get_pdbr() {
  t_pde *pdbr;

  __asm__ __volatile__(
    "        movl    %%cr3, %%eax	\n"
    : "=a" (pdbr)
  );

  return pdbr;
}

/* set PDB register
in:	PDBR
out:	-
*/
static void set_pdbr(t_pde *pdbr) {
  __asm__ __volatile__(
    "        movl    %%eax, %%cr3	\n"
    :
    : "a" (pdbr)
  );
}

/* flush TLB chache
in:	-
out:	-
*/
static void flush_tlb() {
  set_pdbr(get_pdbr());
}

/* initialize paging
in:	-
out:	-
- at start using stack above 1M
*/
void init_paging() {
  t_pde *pd;				/* temp PDBR register		*/
  t_pte *pt;				/* temp page directory pointer	*/
  unsigned int i;
  u32_t phys_addr;

  pd = get_pdbr();			/* phys addr = linear addr	*/
  phys_addr = 0;
  pt = NULL;

  for(i = 0; i < PG_CNT; i ++) {	/* get last phys page		*/
    if (pd[i].s.p == PG_P) {
      unsigned int j;

      pt = (t_pte *)((u32_t)pd[i].s.pg_frame << PG_SH_PT);
      for(j = 0; j < PG_CNT; j ++) {
        if (pt[j].s.p == PG_P &&
          phys_addr < (u32_t)pt[j].s.pg_frame << PG_SH_PT) {
          phys_addr = pt[j].s.pg_frame << PG_SH_PT;	/* ptbl entres	*/
        }
      }

      if (phys_addr < (u32_t)pd[i].s.pg_frame << PG_SH_PT) {
        phys_addr = pd[i].s.pg_frame << PG_SH_PT;	/* pdir entres	*/
      }
    }
  }

  phys_addr = phys_addr + PG_SIZE;
  pt = (t_pte *)((u32_t)pd[(phys_addr & PG_MASK_PD) >> PG_SH_PD].s.pg_frame
    << PG_SH_PT);
__asm__ __volatile__("nop\n");  /* // */
  pt[(phys_addr & PG_MASK_PT) >> PG_SH_PT].v = 0;
  pt[(phys_addr & PG_MASK_PT) >> PG_SH_PT].s.p = PG_P;
  pt[(phys_addr & PG_MASK_PT) >> PG_SH_PT].s.rw = PG_RW;
  pt[(phys_addr & PG_MASK_PT) >> PG_SH_PT].s.us = PG_S;
  pt[(phys_addr & PG_MASK_PT) >> PG_SH_PT].s.pg_frame = phys_addr >> PG_SH_PT;
__asm__ __volatile__("nop\n");  /* // */


  flush_tlb();
/*
  // ---------------------------------------------------------------------------

//  pdbr = get_pdbr();
//  pdbr[0].v = 0;
*/
  pd = (t_pde *)PDIR_ADDR;
  __asm__ __volatile__(
    "        movl       %0, %%eax	\n"
    "        movl       %1, %%ebx	\n"
    "        movl       %2, %%ecx	\n"
    "        movl       %3, %%edx	\n"
    "        hlt	\n"
    :
    : "i" (sizeof(t_pde)),
      "i" (sizeof(t_pte)),
      "m" (phys_addr),
      "m" (pt[(phys_addr & PG_MASK_PT) >> PG_SH_PT].v)
  );
/*
  // ---------------------------------------------------------------------------
*/
}
