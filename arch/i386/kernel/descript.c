/* LGOS3 i386 descriptors	*/

#include "types.h"
#include "descript.h"

union u_desc {
  struct {
    u16_t limit0_15;
    u16_t base0_15;
    u8_t base16_23;
    u8_t a          : 1;
    u8_t w          : 1;
    u8_t e          : 1;
    u8_t data       : 1;
    u8_t us         : 1;
    u8_t dpl        : 2;
    u8_t p          : 1;
    u8_t limit16_19 : 4;
    u8_t avl        : 1;
    u8_t            : 1;
    u8_t b          : 1;
    u8_t g          : 1;
    u8_t base24_31;
  } s_data;
  struct {
    u16_t limit0_15;
    u16_t base0_15;
    u8_t base16_23;
    u8_t a          : 1;
    u8_t r          : 1;
    u8_t c          : 1;
    u8_t exec       : 1;
    u8_t us         : 1;
    u8_t dpl        : 2;
    u8_t p          : 1;
    u8_t limit16_19 : 4;
    u8_t avl        : 1;
    u8_t            : 1;
    u8_t d          : 1;
    u8_t g          : 1;
    u8_t base24_31;
  } s_exec;
  struct {
    u16_t limit0_15;
    u16_t base0_15;
    u8_t base16_23;
    u8_t type       : 4;
    u8_t us         : 1;
    u8_t dpl        : 2;
    u8_t p          : 1;
    u8_t limit16_19 : 4;
    u8_t avl        : 1;
    u8_t            : 2;
    u8_t g          : 1;
    u8_t base24_31;
  } s_system;
} __attribute__ ((packed));
typedef struct s_desc t_desc;
