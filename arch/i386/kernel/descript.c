/* LGOS3 i386 descriptors	*/

#include "types.h"
#include "descript.h"

union u_desc {
  struct {
    unsigned int limit0_15  : 16;
    unsigned int base0_15   : 16;
    unsigned int base16_23  : 8;
    unsigned int a          : 1;
    unsigned int w          : 1;
    unsigned int e          : 1;
    unsigned int data       : 1;
    unsigned int us         : 1;
    unsigned int dpl        : 2;
    unsigned int p          : 1;
    unsigned int limit16_19 : 4;
    unsigned int avl        : 1;
    unsigned int            : 1;
    unsigned int b          : 1;
    unsigned int g          : 1;
    unsigned int base24_31  : 8;
  } s_data;
  struct {
    unsigned int limit0_15  : 16;
    unsigned int base0_15   : 16;
    unsigned int base16_23  : 8;
    unsigned int a          : 1;
    unsigned int r          : 1;
    unsigned int c          : 1;
    unsigned int exec       : 1;
    unsigned int us         : 1;
    unsigned int dpl        : 2;
    unsigned int p          : 1;
    unsigned int limit16_19 : 4;
    unsigned int avl        : 1;
    unsigned int            : 1;
    unsigned int d          : 1;
    unsigned int g          : 1;
    unsigned int base24_31  : 8;
  } s_exec;
  struct {
    unsigned int limit0_15  : 16;
    unsigned int base0_15   : 16;
    unsigned int base16_23  : 8;
    unsigned int type       : 4;
    unsigned int us         : 1;
    unsigned int dpl        : 2;
    unsigned int p          : 1;
    unsigned int limit16_19 : 4;
    unsigned int avl        : 1;
    unsigned int            : 2;
    unsigned int g          : 1;
    unsigned int base24_31  : 8;
  } s_system;
} __attribute__ ((packed));
typedef struct s_desc t_desc;
