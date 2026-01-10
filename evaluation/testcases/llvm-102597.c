int printf(const char *, ...);
__int128 a = 3, c;
char b;
int main() {
  c = 3;
  for (; c >= 0; c--) {
    b = 0;
    for (; b <= 3; b++) {
      if (c)
        break;
      a = 0;
    }
  }
  printf("%d\n", (int)a);
}

