// LLVM #70470: InstCombine trunc/sext fold at -O1
// Fix: 2228b35
int a, b, e, g;
short c, d, f, h = ~1;
int main() {
  for (a = -30; a != -2; a += 7) {
    f = a;
    e = (unsigned)f > -1U >> 16 ? f : 0;
    c = 1;
    b = e;
    for (; g < 4; g++) {
      int i = -c, j = i / ~(d ^ 1);
      if (b) d = (1 - i) ^ 1;
      c = h;
      b = j;
    }
  }
  return 0;
}
