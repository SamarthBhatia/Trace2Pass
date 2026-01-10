#include <stdio.h>
#include <stdlib.h>

void* buf[20];
attribute((noinline))
void foo(void)
{
  printf("Calling longjmp from inside function foo\n");
  __builtin_longjmp(buf, 1);
 printf("This point should never be reached\n");
}

int main(void)
{
  int *local_var = malloc(sizeof(int));
  *local_var = 10;
  printf("local_val=%d \n", *local_var);
  if (__builtin_setjmp(buf) == 0)
  {
    *local_var = 20;
     printf("Calling function foo local_var=%d \n", *local_var);
     foo();
  }
  printf("longjmp has been called local_val=%d \n", *local_var);
}

