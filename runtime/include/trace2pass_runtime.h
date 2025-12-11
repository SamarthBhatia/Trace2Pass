#ifndef TRACE2PASS_RUNTIME_H
#define TRACE2PASS_RUNTIME_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stddef.h>
#include <stdint.h>

// Arithmetic Integrity Checks

void trace2pass_report_overflow(void* pc, const char* expr,
                                 long long a, long long b);

void trace2pass_report_sign_mismatch(void* pc, long long signed_val,
                                      unsigned long long unsigned_val);

void trace2pass_report_sign_conversion(void* pc, int64_t original_value,
                                        uint64_t cast_value, uint32_t src_bits,
                                        uint32_t dest_bits);

void trace2pass_report_division_by_zero(void* pc, const char* op_name,
                                          int64_t dividend, int64_t divisor);

void trace2pass_check_pure_consistency(void* pc, const char* func_name,
                                         int64_t arg0, int64_t arg1,
                                         int64_t result);

// Control Flow Integrity Checks

void trace2pass_report_cfi_violation(void* pc, const char* reason);

void trace2pass_report_unreachable(void* pc, const char* message);

void trace2pass_report_inconsistency(void* pc, const char* function_name,
                                      long long arg, long long result1,
                                      long long result2);

// Memory Bounds Checks

void trace2pass_report_bounds_violation(void* pc, void* ptr,
                                         size_t offset, size_t size);

// Sampling Control

int trace2pass_should_sample(void);

// Initialization (automatically called via constructor/destructor attributes)

void trace2pass_init(void) __attribute__((constructor));
void trace2pass_fini(void) __attribute__((destructor));

// Configuration

void trace2pass_set_sample_rate(double rate);
void trace2pass_set_output_file(const char* path);

#ifdef __cplusplus
}
#endif

#endif // TRACE2PASS_RUNTIME_H
