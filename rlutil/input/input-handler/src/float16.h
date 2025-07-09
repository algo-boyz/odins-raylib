/**
 * The IEEE 754 half-precision floating-point number implementation
 * was created to represent decimal numbers in a small memory space.
 *
 * The implementation allows for a precision of 3 digits maximum, with
 * notable precision errors if surpassed.
 *
 * It is useful to store aproximations of floating-point numbers in
 * big groups to reduce bandwidth and/or increment transfer speeds.
 */
#pragma once
#ifndef __FLOAT16_H__
#define __FLOAT16_H__

#include <stdbool.h>
#include <stdint.h>

typedef int16_t half;  // IEEE 754 half-precision floating-point number
typedef int16_t f16;   // IEEE 754 half-precision floating-point number

half f16_add(half a, half b);  // Addition of two IEEE 754 half-precision floating-point numbers
half f16_sub(half a, half b);  // Subtraction of two IEEE 754 half-precision floating-point numbers
half f16_mul(half a, half b);  // Multiplication of two IEEE 754 half-precision floating-point numbers
half f16_div(half a, half b);  // Division of two IEEE 754 half-precision floating-point numbers
half f16_neg(half a);

half itof16(int32_t i);  // Transformation from integer to half-precision floating point
int32_t f16toi(half h);  // Transformation from half-precision floating point to integer

half ftof16(float f);  // Transformation from single-precision floating point to half-precision floating point
float f16tof(half h);  // Transformation from half-precision floating point to single-precision floating point

bool f16_gte(half a, half b);  // Comparison between two half-precision floating to check if is greater than or equals
bool f16_gt(half a, half b);   // Comparison between two half-precision floating to check if is greater than
bool f16_lte(half a, half b);  // Comparison between two half-precision floating to check if is less than or equals
bool f16_lt(half a, half b);   // Comparison between two half-precision floating to check if is less than
bool f16_eq(half a, half b);   // Comparison between two half-precision floating to check if is equals
bool f16_neq(half a, half b);  // Comparison between two half-precision floating to check if is not equals

#endif  // __FLOAT16_H__
