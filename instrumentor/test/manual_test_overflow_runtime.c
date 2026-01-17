#include <stdio.h>
#include <stdlib.h>

int main(int argc, char *argv[]) {
  printf("Testing arithmetic overflow detection (runtime values)...\n\n");

  // Use argc to prevent constant folding
  int base = (argc > 1) ? atoi(argv[1]) : 1000000;

  // Test 1: Safe operation
  int safe = 10 * 20;
  printf("Test 1 - Safe multiply (10 * 20): %d\n", safe);

  // Test 2: Runtime overflow (compiler can't constant-fold this!)
  int overflow = base * base;
  printf("Test 2 - Runtime multiply (%d * %d): %d\n", base, base, overflow);

  // Test 3: Another runtime overflow
  int x = base / 10;
  int y = base / 10;
  int result = x * y * 100; // This should overflow
  printf("Test 3 - Runtime multiply chain: %d\n", result);

  printf("\nCheck above for Trace2Pass overflow reports!\n");
  return 0;
}
