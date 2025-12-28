// can be compiled with clang-cl -target i386-pc-windows-msvc /EHs /O2
// O2 is required for inlining and EHs enabled basic c++ exceptions
#include "stdio.h"

struct Foo { int a{123};int b{2}; Foo(){}; ~Foo(){}; Foo(const Foo &){} __declspec(noinline) void bar(int a, int b) {}};

int g(Foo foo) {
  try {
	throw 1;
  } catch(...) {
  }
  foo.bar(0, 1); // overwrites the inalloca stack buffer with params
  printf("%d %d\n", foo.a, foo.b); // prints '0 1'
  return 0;
}

int main(int argc, char**) {
    return g(Foo());
}