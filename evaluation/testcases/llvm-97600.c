#include "csmith.h"
uint32_t c = 0;
int32_t *d = &c;
void f(int32_t *o) {
  uint8_t n;
  for (n = 190; n; n += 1) {
    *o = 0;
    if (*d)
      break;
  }
}
int main() {
  for (int b = 0; b <= 1; b++) {
    uint64_t j[2];
    int i;
    for (i = 0; i < 2; i++)
      j[i] = 1;
    f(&c);
    safe_add_func_int32_t_s_s(0, j[1]);
    *d = 7;
  }
  printf("%d\n", c);
  return 0;
}
