#include <stdio.h>
#include <setjmp.h>

extern int bar(void**);

typedef struct aFlag {
  int flg;
} aFlag;

extern jmp_buf buf;

void foo() {
  volatile void *kPtr = ((void*)0);
  static int trace = 0;
  if(setjmp(buf) == 0) {
    bar((void **)&kPtr);
  } else {
    trace++;
    if (kPtr != ((void*)0)) // This code is getting removed in GVN pass
      ((aFlag *)kPtr)->flg |= 0x0001;
  }
  printf("trace: %d\n", trace);
}

