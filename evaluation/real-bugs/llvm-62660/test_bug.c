// LLVM #62660: LSR wrong code at -O1
// Fix: 3a57152
int a, b;
int c(int d) {
  if (d & 1) return d + 1;
  return d;
}
int main() {
  b = 1;
  for (; c(b + 67) - 67 >= 0; b--) a ^= 6;
  return 0;
}
