#include "float16.h"

#include <stdbool.h>
#include <stdint.h>

#define F16_SIGNUM_MASK    0x8000
#define F16_EXP_MASK       0x7C00
#define F16_NO_SIGNUM_MASK 0x7FFF
#define F16_NAN_VALUE      F16_NO_SIGNUM_MASK

#define F16_MANTISSA(x)         (((x) & 1023) | (((x) & F16_EXP_MASK) == 0 ? 0 : 1024))
#define F16_EXPONENT(x)         (((x) & F16_EXP_MASK) >> 10)
#define F16_SIGNUM(x)           ((x) & F16_SIGNUM_MASK)
#define F16_UNSIGNED_VALUE(x)   ((x) & F16_NO_SIGNUM_MASK)
#define F16_SIGNED_INF_VALUE(x) (((x) & F16_SIGNUM_MASK) | F16_EXP_MASK)

#define F16_IS_ZERO(x)    (!F16_UNSIGNED_VALUE(x))
#define F16_IS_INVALID(x) (((x) & F16_EXP_MASK) == F16_EXP_MASK)
#define F16_IS_NAN(x)     (F16_UNSIGNED_VALUE(x) > F16_EXP_MASK)
#define F16_IS_INF(x)     (F16_UNSIGNED_VALUE(x) == F16_EXP_MASK)

// Arithmetic operations //

half f16_sub(half ain, half bin) {
    uint16_t a = ain;
    uint16_t b = bin;
    if (F16_SIGNUM(a ^ b)) { return f16_add(a, b ^ F16_SIGNUM_MASK); }
    uint16_t sign = F16_SIGNUM(a);
    a = a << 1;
    b = b << 1;
    if (a < b) {
        uint16_t x = a;
        a = b;
        b = x;
        sign ^= F16_SIGNUM_MASK;
    }
    uint16_t ax = a & 0xF800;
    uint16_t bx = b & 0xF800;
    if (a >= 0xf800 || b >= 0xf800) {
        if (a > 0xF800 || b > 0xF800 || a == b) { return F16_NO_SIGNUM_MASK; }
        uint16_t res = sign | F16_EXP_MASK;
        if (a == 0xf800) {
            return res;
        } else {
            return res ^ F16_SIGNUM_MASK;
        }
    }
    int exp_diff = ax - bx;
    uint16_t exp_part = ax;
    if (exp_diff != 0) {
        int shift = exp_diff >> 11;
        if (bx != 0) {
            b = ((b & 2047) | 2048) >> shift;
        } else {
            b >>= (shift - 1);
        }
    } else {
        if (bx == 0) {
            uint16_t res = (a - b) >> 1;
            if (res == 0) { return res; }
            return res | sign;
        } else {
            b = (b & 2047) | 2048;
        }
    }
    uint16_t r = a - b;
    if ((r & 0xF800) == exp_part) { return (r >> 1) | sign; }
    uint16_t am = (a & 2047) | 2048;
    uint16_t new_m = am - b;
    if (new_m == 0) { return 0; }
    while (exp_part != 0 && !(new_m & (2048))) {
        exp_part -= 0x800;
        if (exp_part != 0) { new_m <<= 1; }
    }
    return (((new_m & 2047) | exp_part) >> 1) | sign;
}

half f16_add(half a, half b) {
    if (F16_SIGNUM(a ^ b)) { return f16_sub(a, b ^ F16_SIGNUM_MASK); }
    int16_t sign = F16_SIGNUM(a);
    a &= F16_NO_SIGNUM_MASK;
    b &= F16_NO_SIGNUM_MASK;
    if (a < b) {
        int16_t x = a;
        a = b;
        b = x;
    }
    if (a >= F16_EXP_MASK || b >= F16_EXP_MASK) {
        if (a > F16_EXP_MASK || b > F16_EXP_MASK) { return F16_NAN_VALUE; }
        return F16_EXP_MASK | sign;
    }
    int16_t ax = F16_EXPONENT(a);
    int16_t bx = F16_EXPONENT(b);
    int16_t exp_diff = ax - bx;
    int16_t exp_part = ax;
    if (exp_diff != 0) {
        int shift = exp_diff >> 10;
        if (bx != 0) {
            b = ((b & 1023) | 1024) >> shift;
        } else {
            b >>= (shift - 1);
        }
    } else {
        if (bx == 0) {
            return (a + b) | sign;
        } else {
            b = (b & 1023) | 1024;
        }
    }
    int16_t r = a + b;
    if (F16_EXPONENT(r) != exp_part) {
        uint16_t am = (a & 1023) | 1024;
        uint16_t new_m = (am + b) >> 1;
        r = (exp_part + 0x400) | (1023 & new_m);
    }
    if ((uint16_t)r >= 0x7C00u) { return sign | F16_EXP_MASK; }
    return r | sign;
}

half f16_mul(half a, half b) {
    int sign = F16_SIGNUM(a ^ b);

    if (F16_IS_INVALID(a) || F16_IS_INVALID(b)) {
        if (F16_IS_NAN(a) || F16_IS_NAN(b) || F16_IS_ZERO(a) || F16_IS_ZERO(b)) { return F16_NAN_VALUE; }
        return sign | F16_EXP_MASK;
    }

    if (F16_IS_ZERO(a) || F16_IS_ZERO(b)) { return 0; }
    uint16_t m1 = F16_MANTISSA(a);
    uint16_t m2 = F16_MANTISSA(b);

    int32_t v = m1;
    v *= m2;
    int ax = F16_EXPONENT(a);
    int bx = F16_EXPONENT(b);
    ax += (ax == 0);
    bx += (bx == 0);
    int new_exp = ax + bx - 15;

    if (v & ((int32_t)1 << 21)) {
        v >>= 11;
        new_exp++;
    } else if (v & ((int32_t)1 << 20)) {
        v >>= 10;
    } else {  // denormal
        new_exp -= 10;
        while (v >= 2048) {
            v >>= 1;
            new_exp++;
        }
    }
    if (new_exp <= 0) {
        v >>= (-new_exp + 1);
        new_exp = 0;
    } else if (new_exp >= 31) {
        return F16_SIGNED_INF_VALUE(sign);
    }
    return sign | (new_exp << 10) | (v & 1023);
}

half f16_div(half a, half b) {
    int16_t sign = F16_SIGNUM(a ^ b);
    if (F16_IS_NAN(a) || F16_IS_NAN(b) || (F16_IS_INVALID(a) && F16_IS_INVALID(b)) || (F16_IS_ZERO(a) && F16_IS_ZERO(b))) {
        return F16_NAN_VALUE;
    }
    if (F16_IS_INVALID(a) || F16_IS_ZERO(b)) { return sign | F16_EXP_MASK; }
    if (F16_IS_INVALID(b) || F16_IS_ZERO(a)) { return 0; }

    uint16_t m1 = F16_MANTISSA(a);
    uint16_t m2 = F16_MANTISSA(b);
    int32_t m1_shifted = m1;
    m1_shifted <<= 10;
    int32_t v = m1_shifted / m2;
    uint16_t rem = m1_shifted % m2;

    int ax = F16_EXPONENT(a);
    int bx = F16_EXPONENT(b);
    ax += (ax == 0);
    bx += (bx == 0);
    int new_exp = ax - bx + 15;

    if (v == 0 && rem == 0) { return 0; }

    while (v < 1024 && new_exp > 0) {
        v <<= 1;
        rem <<= 1;
        if (rem >= m2) {
            v++;
            rem -= m2;
        }
        new_exp--;
    }
    while (v >= 2048) {
        v >>= 1;
        new_exp++;
    }

    if (new_exp <= 0) {
        v >>= (-new_exp + 1);
        new_exp = 0;
    } else if (new_exp >= 31) {
        return F16_SIGNED_INF_VALUE(sign);
    }
    return sign | (v & 1023) | (new_exp << 10);
}

half f16_neg(half v) { return F16_SIGNUM_MASK ^ v; }

// Integer transformations //

half itof16(int32_t sv) {
    int32_t v;
    int sig = 0;
    if (sv < 0) {
        v = -sv;
        sig = 1;
    } else {
        v = sv;
    }
    if (v == 0) { return 0; }
    int e = 25;
    while (v >= 2048) {
        v >>= 1;
        e++;
    }
    while (v < 1024) {
        v <<= 1;
        e--;
    }
    if (e >= 31) { return F16_SIGNED_INF_VALUE(sig << 15); }
    return (sig << 15) | (e << 10) | (v & 1023);
}

int32_t f16toi(half a) {
    uint16_t value = F16_MANTISSA(a);
    int16_t shift = F16_EXPONENT(a) - 25;
    if (shift > 0) {
        value <<= shift;
    } else if (shift < 0) {
        value >>= -shift;
    }
    if (F16_SIGNUM(a)) { return -(int32_t)(value); }
    return value;
}

// Single-precision floating point transformations //

half ftof16(float f) {
    uint32_t bits = *(uint32_t *)&f;
    uint16_t sign = (bits >> 16) & 0x8000;
    uint32_t exp = (bits >> 23) & 0xFF;
    uint32_t mant = bits & 0x7FFFFF;

    if (exp == 255) {  // NaN or Inf
        if (mant != 0) {
            uint16_t nan_mant = mant >> 13;
            if (nan_mant == 0) nan_mant = 1;
            return sign | 0x7C00 | nan_mant;  // NaN
        } else {
            return sign | 0x7C00;  // Infinity
        }
    }

    if (exp < 113) {  // Too small for normalized half
        if (exp < 103) {
            return sign;  // Underflow to zero
        }
        // Subnormal number
        uint32_t shift = 113 - exp;
        mant |= 0x800000;  // Add implicit 1
        uint16_t submant = mant >> (shift + 13);
        // Rounding
        if (((mant >> (shift + 12)) & 1) && ((mant >> (shift + 13)) & 1 || (mant & ((1 << (shift + 12)) - 1)))) { submant += 1; }
        return sign | submant;
    }

    // Normal case
    uint16_t hexp = exp - 112;
    uint32_t mant_rounded = mant + 0x1000;
    if (mant_rounded & 0x800000) {
        mant_rounded = 0;
        hexp += 1;
    }

    if (hexp >= 0x1F) {
        return sign | 0x7C00;  // Overflow to infinity
    }

    return sign | (hexp << 10) | (mant_rounded >> 13);
}

float f16tof(half h) {
    uint32_t sign = (h & 0x8000) << 16;
    uint32_t exp = (h & 0x7C00) >> 10;
    uint32_t mant = (h & 0x03FF);

    if (exp == 0) {
        if (mant == 0) {
            // Zero
            return *(float *)&sign;
        } else {
            // Subnormal number
            uint32_t shift = 0;
            while ((mant & 0x200) == 0) {
                mant <<= 1;
                shift++;
            }
            mant &= 0x3FF;  // Remove leading 1
            exp = 1;
            exp = 127 - 15 - shift;  // Adjust exponent for float32
            uint32_t fbits = sign | (exp << 23) | (mant << 13);
            return *(float *)&fbits;
        }
    } else if (exp == 0x1F) {
        // Inf or NaN
        if (mant == 0) return *(float *)&(uint32_t){sign | 0x7F800000};                  // Inf
        else return *(float *)&(uint32_t){sign | 0x7F800000 | (mant << 13) | 0x400000};  // NaN (qNaN)
    }

    // Normalized float16 to float32
    uint32_t fexp = exp + (127 - 15);
    uint32_t fbits = sign | (fexp << 23) | (mant << 13);
    return *(float *)&fbits;
}

// Boolean operations //

bool f16_gte(half a, half b) {
    if (F16_IS_ZERO(a) && F16_IS_ZERO(b)) { return true; }
    if (F16_IS_NAN(a) || F16_IS_NAN(b)) { return false; }
    if (!F16_SIGNUM(a)) {
        if (F16_SIGNUM(b)) { return true; }
        return a >= b;
    } else {
        if (!F16_SIGNUM(b)) { return false; }
        return F16_UNSIGNED_VALUE(a) <= F16_UNSIGNED_VALUE(b);
    }
}

bool f16_gt(half a, half b) {
    if (F16_IS_NAN(a) || F16_IS_NAN(b)) { return false; }
    if (F16_IS_ZERO(a) && F16_IS_ZERO(b)) { return false; }
    if (!F16_SIGNUM(a)) {
        if (F16_SIGNUM(b)) { return true; }
        return a > b;
    } else {
        if (!F16_SIGNUM(b)) { return false; }
        return F16_UNSIGNED_VALUE(a) < F16_UNSIGNED_VALUE(b);
    }
}

bool f16_eq(half a, half b) {
    if (F16_IS_NAN(a) || F16_IS_NAN(b)) { return false; }
    if (F16_IS_ZERO(a) && F16_IS_ZERO(b)) { return true; }
    return a == b;
}

bool f16_lte(half a, half b) {
    if (F16_IS_NAN(a) || F16_IS_NAN(b)) { return false; }
    return f16_gte(b, a);
}

bool f16_lt(half a, half b) {
    if (F16_IS_NAN(a) || F16_IS_NAN(b)) { return false; }
    return f16_gt(b, a);
}

bool f16_neq(half a, half b) { return !f16_eq(a, b); }
