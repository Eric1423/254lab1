#ifndef _COMMON_H_
#define _COMMON_H_

#ifndef TYPE
#define TYPE float
#endif

#ifndef TILE_X
#define TILE_X 4
#endif

#ifndef TILE_Y
#define TILE_Y 4
#endif

typedef struct {
  uint32_t grid_dim[2];
  uint32_t size;
  uint64_t A_addr;
  uint64_t B_addr;
  uint64_t C_addr;
} kernel_arg_t;

#endif
