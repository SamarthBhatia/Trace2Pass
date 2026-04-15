// LLVM Bug #69744: LoopVectorize alias miscompile
// https://github.com/llvm/llvm-project/issues/69744
// Status: CLOSED (fixed)
//
// Expected: exits 0
// Buggy:    exits 1 (BUG detected) at -O2

#include <stdio.h>
#include <stdlib.h>

typedef struct {
  unsigned long long ref_count;
} MyObject;

static int mycount(MyObject** arr) {
  MyObject** old_arr = arr;
  while (*arr++)
    ;
  return (int)(arr - old_arr) - 1;
}

void my_inplace_repeat(MyObject** arr, int times) {
  int orig_elem_count = mycount(arr);
  int pos = orig_elem_count;
  for (int i = 1; i < times; i++) {
    for (int j = 0; j < orig_elem_count; j++) {
      MyObject* obj = arr[j];
      obj->ref_count++;
      arr[pos++] = obj;
    }
  }
  arr[pos] = 0;
}

MyObject* obj_alloc() {
  MyObject* ret = malloc(sizeof(MyObject));
  ret->ref_count = 1;
  return ret;
}

int main() {
  MyObject** arr = malloc(sizeof(MyObject*) * 1000);
  arr[0] = obj_alloc();
  arr[1] = 0;
  my_inplace_repeat(arr, 4);
  my_inplace_repeat(arr, 2);
  int count = mycount(arr);
  for (int i = 0; i < count; i++) {
    if (arr[i]->ref_count != count) {
      return 1;
    }
  }
  return 0;
}
