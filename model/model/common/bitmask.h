#ifndef BITMASK_H
#define BITMASK_H

#include <stdint.h>

#define MASK_U32(numbits) ((UINT32_C(1) << (numbits)) - 1u)
#define MASK_U64(numbits) ((UINT64_C(1) << (numbits)) - 1u)

#endif