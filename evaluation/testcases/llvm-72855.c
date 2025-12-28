% cat a.c
int printf(const char *, ...);
int a;
int *g = &a, *m = &a, *n = &a;
short o;
int p(char *b, long c, long *d) {
  char *e = b;
  long f = *d;
  for (; c && f; --c, ++f, ++e)
    ;
  return e - b;
}
int t(long h, long i) {
  char j;
  long k[] = {i};
  int l = p(&j, h, k);
  return l;
}
long q(int *r) {
  *m = 4;
  for (;;)
    for (; *r >= 0;) {
      *g = *n % 5 == 1;
      for (;;)
        for (; t(*n + 5, 3124342948) <= 5;)
          return 0;
    }
}
int main() {
  int s = a;
  q(&s);
  printf("%d\n", o);
}
%
% clang -O0 -fsanitize=address,undefined a.c && ./a.out
0
% clang -O1 a.c && ./a.out
Timeout
%