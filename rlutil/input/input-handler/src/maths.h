#ifndef MATHS_H
#define MATHS_H

#include "types.h"

#define FPOW_TEMPLATE(type)                   \
  inline type fast_pow##type(type b, i32 e) { \
    type r = 1;                               \
    for (; e > 0; b *= b, e >>= 1)            \
      if (e & 1) r *= b;                      \
    return r;                                 \
  }

FPOW_TEMPLATE(f64)
FPOW_TEMPLATE(f32)
FPOW_TEMPLATE(i64)
FPOW_TEMPLATE(i32)
FPOW_TEMPLATE(u64)
FPOW_TEMPLATE(u32)

#endif  // MATHS_H