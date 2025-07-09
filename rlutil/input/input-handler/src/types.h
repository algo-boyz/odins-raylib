#pragma once
#ifndef __TYPES_H__
#define __TYPES_H__

#include <stdbool.h>  // bool, true, false
#include <stddef.h>   // malloc
#include <stdint.h>   // int8_t, int16_t, int32_t, int64_t, uint8_t, uint16_t, uint32_t, uint64_t
#include <stdlib.h>   // uintptr_t, ptrdiff_t, size_t
#include <uchar.h>    // char16_t

typedef char byte;  // Byte type

typedef uintptr_t uptr;  // Unsigned pointer type

typedef ptrdiff_t size;  // Signed size type
typedef size_t usize;    // Unsigned size type

typedef char c8;       // 8 bit char type (UTF-8)
typedef char16_t c16;  // 16 bit char type (UTF-16) (Win32: wchar_t)

typedef int8_t i8;    // 8 bit integer type
typedef int16_t i16;  // 16 bit integer type
typedef int32_t i32;  // 32 bit integer type
typedef int64_t i64;  // 64 bit integer type

typedef uint8_t u8;    // 8 bit unsigned integer type
typedef uint16_t u16;  // 16 bit unsigned integer type
typedef uint32_t u32;  // 32 bit unsigned integer type
typedef uint64_t u64;  // 64 bit unsigned integer type

typedef float f32;   // 32 bit float type
typedef double f64;  // 64 bit float type

#define max(a, b)             (((a) > (b)) ? (a) : (b))                                    // Gets the maximum value between two values
#define min(a, b)             (((a) < (b)) ? (a) : (b))                                    // Gets the minimum value between two values
#define minmax(v, _min, _max) (((v) < (_min)) ? (_min) : (((v) > (_max)) ? (_max) : (v)))  // Limits a value between a minimum and a maximum

#define reserve_t(type)         (type*)malloc(sizeof(type))      // Allocates a new element in the heap
#define reserve_a(type, n)      (type*)malloc(sizeof(type) * n)  // Allocates a new array of elements in the heap
#define reserve_zero(type)      (type*)calloc(1, sizeof(type))   // Allocates a new element in the heap and zeroes it
#define reserve_zero_a(type, n) (type*)calloc(n, sizeof(type))   // Allocates a new array of elements in the heap and zeroes it

#endif  // __TYPES_H__
