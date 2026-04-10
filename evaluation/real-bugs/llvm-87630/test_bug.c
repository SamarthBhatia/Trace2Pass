// LLVM Bug #87630: SLPVectorizer miscompile at -O3
// https://github.com/llvm/llvm-project/issues/87630
// Status: CLOSED (fixed by commit 8a0bfe4)
//
// Expected: exits 0
// Buggy:    aborts at -O3

int a, b;
short c;
char d, e;
int main() {
  int h, i = 32768;
  for (a = 0; a < 32; a++) {
    b = i ^= 1;
    i |= e;
    h = i + c;
    d |= h;
  }
  if (b != 32768)
    __builtin_abort();
  return 0;
}
