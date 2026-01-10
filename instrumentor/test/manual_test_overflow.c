#include <stdio.h>

int main() {
  printf("Testing arithmetic overflow detection...\n\n");

  // Test 1: Safe operation
  int safe = 10 * 20;
  printf("Test 1 - Safe multiply (10 * 20): %d\n", safe);

  // Test 2: Overflow!
  int overflow = 1000000 * 1000000;
  printf("Test 2 - Overflow multiply (1000000 * 1000000): %d\n", overflow);

  printf("\nCheck above for Trace2Pass overflow report!\n");
  return 0;
}
