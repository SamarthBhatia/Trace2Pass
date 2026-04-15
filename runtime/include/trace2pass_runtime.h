#ifndef TRACE2PASS_RUNTIME_H
#define TRACE2PASS_RUNTIME_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stddef.h>
#include <stdint.h>

// Arithmetic Integrity Checks

void trace2pass_report_overflow(void* pc, const char* file, int line, const char* function,
                                 const char* expr, long long a, long long b);

void trace2pass_report_sign_conversion(void* pc, const char* file, int line, const char* function,
                                        int64_t original_value, uint64_t cast_value,
                                        uint32_t src_bits, uint32_t dest_bits);

void trace2pass_report_division_by_zero(void* pc, const char* file, int line, const char* function,
                                          const char* op_name, int64_t dividend, int64_t divisor);

void trace2pass_check_pure_consistency(void* pc, const char* file, int line, const char* function,
                                         const char* func_name, int64_t arg0, int64_t arg1,
                                         int64_t result);

// Loop Bounds Checks

void trace2pass_report_loop_bound_exceeded(void* pc, const char* file, int line, const char* function,
                                            const char* loop_name, uint64_t iteration_count,
                                            uint64_t threshold);

// Control Flow Integrity Checks

void trace2pass_report_unreachable(void* pc, const char* file, int line, const char* function,
                                     const char* message);

// Memory Bounds Checks

void trace2pass_report_bounds_violation(void* pc, const char* file, int line, const char* function,
                                         void* ptr, size_t offset, size_t size);

// Select Consistency Checks

void trace2pass_report_select_inconsistency(void* pc, const char* file, int line, const char* function,
                                             int64_t condition, int64_t true_val, int64_t false_val,
                                             int64_t actual_result);

// Range Verification Checks

void trace2pass_report_range_violation(void* pc, const char* file, int line, const char* function,
                                       int64_t actual_value, int64_t range_lo, int64_t range_hi);

// Store-Load Consistency Checks

void trace2pass_report_store_load_inconsistency(void* pc, const char* file, int line, const char* function,
                                                 int64_t stored_value, int64_t loaded_value);

// Volatile Tracking (Cross-BB Store-Load Consistency for GVN bug detection)

void trace2pass_shadow_store(void* addr, int64_t value);
void trace2pass_shadow_check(void* pc, const char* file, int line, const char* function,
                              void* addr, int64_t loaded_value);

// Cross-BB Value Propagation Checks (Opaque Memory Read)
// Detects GVN bugs that incorrectly fold loads across basic blocks

int64_t trace2pass_opaque_read(void* addr, int32_t size_bytes);
void trace2pass_report_value_propagation(void* pc, const char* file, int line,
    const char* function, void* addr, int64_t optimized_value, int64_t actual_value);

// Sampling Control

int trace2pass_should_sample(void);

// Backend Checksum (miscompilation detection)
// Accumulates a deterministic checksum of function return values.
// Compare O0 vs Ox checksums to detect backend codegen bugs.
// Controlled by TRACE2PASS_CHECKSUM_MODE env var (record/verify).

void trace2pass_accumulate_checksum(uint64_t func_hash, int64_t ret_value);

// Initialization (automatically called via constructor/destructor attributes)

void trace2pass_init(void) __attribute__((constructor));
void trace2pass_fini(void) __attribute__((destructor));

// Configuration

void trace2pass_set_sample_rate(double rate);
void trace2pass_set_output_file(const char* path);
void trace2pass_set_collector_url(const char* url);  // Set Collector API endpoint
const char* trace2pass_get_collector_url(void);      // Get current Collector URL

#ifdef __cplusplus
}
#endif

#endif // TRACE2PASS_RUNTIME_H
