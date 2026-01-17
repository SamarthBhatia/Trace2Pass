#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

// The "Strict Aliasing Ghost" Bug
// Type punning causes reordering that violates data dependencies

typedef struct {
    float x;
    float y;
} Point;

volatile int prevent_opt = 0;

uint32_t float_to_bits(float f) {
    // Type punning via pointer cast (violates strict aliasing)
    uint32_t result;
    memcpy(&result, &f, sizeof(result));
    return result;
}

void test_type_punning() {
    Point p;
    p.x = 1.0f;
    p.y = 2.0f;

    printf("Original values: x=%.1f, y=%.1f\n", p.x, p.y);

    // Type punning: treat Point* as uint32_t*
    uint32_t *bits = (uint32_t *)&p;

    // Modify through uint32_t pointer
    bits[0] = 0x3f800000; // 1.0f in IEEE 754

    // Read back through float pointer
    // Compiler may reorder this to BEFORE the modification!
    printf("After modification through uint32_t*: x=%.1f, y=%.1f\n", p.x, p.y);

    if (prevent_opt) {
        printf("x bits: 0x%08x\n", bits[0]);
    }
}

void test_union_punning() {
    // Union type punning (implementation-defined, but widely supported)
    union {
        float f;
        uint32_t u;
    } converter;

    converter.f = 3.14f;
    printf("Float value: %.2f\n", converter.f);
    printf("Bit pattern: 0x%08x\n", converter.u);

    converter.u = 0x40490fdb; // pi as float bits
    printf("After bit modification: %.6f\n", converter.f);
}

void test_strict_aliasing_violation() {
    printf("\n=== Strict Aliasing Violation Test ===\n");

    int x = 10;
    float *fp = (float *)&x;  // VIOLATION: int* and float* can't alias

    printf("Original int value: %d\n", x);

    // Modify through float pointer
    *fp = 3.14f;

    // Compiler may reorder this to read OLD value of x
    // because it assumes float* and int* don't alias
    printf("After modification through float*: %d\n", x);
    printf("Reading as float: %.2f\n", *fp);
}

int main() {
    printf("=== Strict Aliasing Ghost Test ===\n\n");

    printf("Test 1: Point type punning\n");
    test_type_punning();

    printf("\nTest 2: Union type punning (safer)\n");
    test_union_punning();

    printf("\nTest 3: Direct strict aliasing violation\n");
    test_strict_aliasing_violation();

    printf("\n=== Expected Behavior ===\n");
    printf("At -O0: All operations should work as written\n");
    printf("At -O2/-O3 with -fstrict-aliasing:\n");
    printf("  - Reads may be reordered BEFORE writes\n");
    printf("  - Modifications through one pointer type invisible to another\n");
    printf("  - Data dependencies violated\n");
    printf("\nThis is technically UB, but breaks real-world code (serialization, etc.)\n");

    return 0;
}
