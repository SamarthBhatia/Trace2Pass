// GCC Bug 110726: Wrong code with 'a |= a == 0'
// https://gcc.gnu.org/bugzilla/show_bug.cgi?id=110726
// GCC 14 regression on x86_64

int main(void) {
  unsigned long long freq = 0x10080ULL;

  freq >>= 2;
  freq |= freq == 0;

  if (freq != 0x4020ULL)
      __builtin_trap();

  return 0;
}
