extern void __aeabi_assert(const char *, const char *, int);
#define assert(e) ((e) ? (void)0 : __aeabi_assert(#e, __FILE__, __LINE__))
#include <complex.h>

union S131 {
  double _Complex M0 __attribute__((aligned(16)));
  signed _BitInt(124) M1;
};

void F94(union S131 P3) {
  assert(P3.M0 == 1.0 + 2.0 * _Complex_I);
}

int main() {
  union S131 P3 = {1.0 + 2.0 * _Complex_I};
  F94(P3);

  return 0;
}