#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>
#include <ctype.h>
#include <wctype.h>
#include <stdio.h>

namespace std {
template <class, int b> struct c { static const bool f = b; };
template <bool d> using e = c<bool, d>;
template <class a, class g> using h = e<__is_same(a, g)>;
void ab();
inline namespace ad {
template <class, class> concept i = requires { ab; };
template <class a, class g> concept aa = h<a, g>::f;
template <class a, class g> concept j = aa<g, a>;
template <bool, class, class> using ah = int;
template <class, class> using ae = int;
template <class, class> using af = decltype(0);
template <class, class, class, class> struct ag;
template <class aj, class ai> using aq = af<ae<aj, ai>, ae<ai, aj>>;
template <class ak, class al, class aj, class ai> requires requires {
  typename aq<aj, ai>;
}
struct ag<ak, al, aj, ai>;
template <class a> concept am = requires { a{}; };
template <class a> concept an = i<a, a>;
template <class a> concept ao = i<a, a>;
template <class a> constexpr bool ap = __is_object(a);
} // namespace ad
struct n {
  template <class g> using k = g;
};
template <class, class g> using ar = n::k<g>;
template <class a> concept as = am<a>;
namespace ad {
template <class a> a *addressof(a &);
template <class at> concept au = requires(at aw) { aw; };
template <class at> concept ax = requires(at aw) { aw; };
struct {
  template <class a> auto operator()(a &&ay) { return ay.az(); }
} az;
template <size_t...> struct o;
template <class ba, ba... bb> struct bc {
  template <size_t> using l = o<bb...>;
};
template <size_t bd, size_t be>
using m = __make_integer_seq<bc, size_t, bd>::template l<be>;
template <class...> class tuple;
template <size_t...> struct o {};
template <size_t bd, size_t be = 0> struct q { typedef m<bd, be> ac; };
template <class...> struct bf {};
template <class> struct bg;
template <class... a> struct bg<tuple<a...>> : c<size_t, sizeof...(a)> {};
template <class, class> struct bh;
template <template <class...> class s, class... av, size_t... bi>
struct bh<s<av...>, o<bi...>> {
  template <class a> using p = bf<ar<a, __type_pack_element<bi, av>>...>;
};
template <class a, size_t bd = bg<a>::f> struct bj {
  using bk = a;
  using r = bh<bk, typename q<bd>::ac>;
  using ac = r::template p<a>;
};
int piecewise_construct;
template <size_t, class> class v {
public:
  template <class a> v(a) {}
};
template <class...> struct w;
template <size_t... t, class... a> struct w<o<t...>, a...> : v<t, a>... {
  template <size_t... x, class... y> w(o<x...>, bf<y...>) : v<x, y>(0)... {}
};
template <class... a> class tuple {
  w<typename q<sizeof...(a)>::ac, a...> bl;

public:
  template <class... g>
  tuple(g...) : bl(typename q<sizeof...(g)>::ac(), typename bj<tuple>::ac()) {}
};
template <class... a> tuple(a...) -> tuple<a...>;
template <class a, class s> a bm(s) { return a(); }
template <class a, class s> a bn(s ay) { return bm<a>(ay); }
template <class a> concept bo = ax<a>;
template <class z> class bp {
  z u() { return static_cast<z &>(*this); }

public:
  template <bo bq> auto operator[](bq br) { return az(u())[br]; }
};
struct bs {
} unreachable_sentinel;
template <class a> concept bt = ap<a>;
namespace ranges {
template <bt> class bu;
template <class a> concept bv = ao<a>;
template <bt a> requires bv<a> class bu<a> {
  a bw;

public:
  bu(...) {}
  a &operator*() { return bw; }
};
template <class a> concept bx = au<a>;
template <an a, as by = bs>
requires(ap<a> &&j<a, a> && (bx<by> || j<by, bs>)) class repeat_view
    : public bp<repeat_view<a>> {
  class bz;

public:
  template <class... ca>
  repeat_view(int, tuple<> cb, tuple<ca...> cc)
      : ce(bn<a>(cb)), cf(bn<by>(cc)) {}
  bz az() { return addressof(*ce); }
  bu<a> ce;
  [[__no_unique_address__]] by cf;
};
template <an a, as by>
requires(ap<a> &&j<a, a> &&
         (bx<by> || j<by, bs>)) class repeat_view<a, by>::bz {
  friend repeat_view;
  using cg = ah<j<by, bs>, ptrdiff_t, by>;
  bz(a *ch) : ce(ch) {}

public:
  using cd = cg;
  a operator*() { return *ce; }
  a operator[](cd) { return **this; }
  a *ce;
};
} // namespace ranges
} // namespace ad
} // namespace std


struct A {
  int x = 111;
  int y = 222;

  constexpr A() = default;
  constexpr A(int _x, int _y) : x(_x), y(_y) {}
};

int main(int, char**) {
  std::ranges::repeat_view<A> rv(std::piecewise_construct, std::tuple{}, std::tuple{std::unreachable_sentinel});
  printf("rv[0].x = %d - %s\n", rv[0].x, rv[0].x == 111 ? "ok" : "incorrect");
  if (rv[0].x != 111)
    return 1;

  return 0;
}