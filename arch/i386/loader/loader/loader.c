/* LGOS3 loader */

#include "console.h"
#include "disk.h"
#include "lib.h"
#include "init.h"
#include "multiboot.h"
#include "elf.h"

#define MAXCMDLENGTH	0x200		/* max kernel cmd length	*/

void loadkernel() __attribute__ ((noreturn));	/* load & start kernel	*/

#define CFGLEN	0x100			/* max lenght of cfg path	*/
static char ldrcfgpath[CFGLEN] = "\0 ";	/* cfg path -> .data		*/

/* read kernel
read loader config file (kernel path & parameters)
read kernel
jump to kernel & pass parameters
- halt on error
input:	-
output:	-
*/
void loadkernel() {
  u32_t cfsize;				/* size of config file	*/

  initvideo();
  setcolor(CLR_BLUE << 4 | CLR_YELLOW);
  printf("  -= LGOS 3 loader =-  \n");

  if (strlen(ldrcfgpath) == 0) {	/* empty cfg file name	*/
    stoperror("Loader config file name is empty.\n");
  }

  setcolor(CLR_GREEN);
  printf("loader config: %s\n", ldrcfgpath);

  openfile(ldrcfgpath);			/* open config file	*/
  cfsize = getfilesize();		/* get config file size	*/
  if (cfsize >= MAXCMDLENGTH) {		/* too long?		*/
    stoperror("Kernel command parameter is too long: %lu > %u.",
      cfsize, MAXCMDLENGTH - 1);
  }

  {					/* read config file	*/
    char path[cfsize + 1];		/* kernel path		*/
    char *params;			/* kernel parameters	*/

    readfile(0, cfsize, &path);		/* read path & params	*/
    path[cfsize] = '\0';		/* tailing zero		*/

    params = strchr(path, ' ');		/* find params		*/
    if (params == NULL) {		/* not found parameters	*/
      params = "";
    }
    else {				/* found parameters	*/
      char *s;

      *params = '\0';			/* end of kernel path	*/
      params ++;			/* beginning of params	*/
      s = strchr(params, '\n');		/* cut newline char	*/
      if (s != NULL) {
        *s = '\0';
      }
    }
    printf("kernel       : %s %s\n", path, params);

    openfile(path);			/* open kernel		*/
    {
      int i;
      int lfsize;
      farptr_t entry;
      int loaded = 0;

      int (*loadfv[])(farptr_t *) = {&loadmb, &loadelf};

      lfsize = sizeof(loadfv) / sizeof(loadfv[0]);
      for (i = 0; i < lfsize; i ++) {		/* try file formats	*/
        if ((*loadfv[i])(&entry)) {		/* load kernel		*/
          loaded = 1;
          break;				/* successful		*/
        }
      }

      if (! loaded) {				/* successful load?	*/
        stoperror("Can not load kernel.");	/* no, stop		*/
      }

      stopfloppy();				/* stop floppy motors	*/
      printf("Starting kernel @ 0x%04x:%04x ...\n",
        entry.segment, entry.offset);		/* jump to kernel	*/

      __asm__ __volatile__ (
        "       ljmp    *%[entry]	\n"
        :
        : [entry] "m" (entry)
      );
    }
  }
  __builtin_unreachable();			/* asm noreturn		*/
}
