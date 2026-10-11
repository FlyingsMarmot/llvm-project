namespace System {
template <bool B, class T, class U> struct Choose {
  template <class X, class Y> using _Select = X;
  static constexpr bool value = B;
};
struct _Task {};
using Ordinary = _Task;
}
// System macros expanded in user code must still produce uC++ keywords.
#define SYSTEM_TASK(Name) _Task Name {}
