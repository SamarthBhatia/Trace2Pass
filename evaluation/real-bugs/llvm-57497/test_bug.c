// LLVM #57497: IndVars sext at -O1
// Dup of #57187
int printf(const char *, ...);
short b[8][1] = {{}, {}, 9};
int c, d, e, h, i;
int *f = &c;
int **g = &f;
int j(int k) {
  if (k < 8) k;
  else if (k < 9) ;
  else if (k < 9 + 3) k -= 4;
  return k;
}
int main() {
l:
  **g = --b[2][0];
  e = 4;
  for (; e < 1; --e) for (; h;) ;
  if (j(e)) g = &e;
  else if (d) goto l;
  for (; i < 8; i++) printf("%d\n", b[i][0]);
  return 0;
}
