$ cat test.c
struct {
  unsigned long a;
} b;
int c, f, e, d;
int *g = &c;
void h(char aa, char bb, char i) {
j:
  for (;;) {
    unsigned int k;
    for (; b.a;)
      if (i)
        goto j;
    if (i)
      continue;
    if (g)
      break;
  }
}
int main() { h(f, e, d); }
$
$ clang-tk -mcmodel=large -O1 test.c; ./a.out
Segmentation fault (core dumped)
$
$ clang-tk -mcmodel=large -O2 test.c; ./a.out
$
$ clang-16.0.0 -mcmodel=large -O1 test.c; ./a.out
$
$ clang-tk --version
Ubuntu clang version 18.0.0 (++20230821052626+634b2fd2cac2-1~exp1~20230821172748.738)
Target: x86_64-pc-linux-gnu
Thread model: posix
$
$ clang-16.0.0 --version
clang version 16.0.0
Target: x86_64-unknown-linux-gnu
Thread model: posix