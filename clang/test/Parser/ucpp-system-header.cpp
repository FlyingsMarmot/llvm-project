// RUN: %clang_cc1 -std=c++20 -fcxx-exceptions -fsyntax-only -verify -isystem %S/Inputs/ucpp-system %s
// expected-no-diagnostics
#include <keywords.h>

static_assert(System::Choose<true, int, long>::value);
System::Ordinary ordinary_system_identifier;
_Task UserTask {};
_Coroutine UserCoroutine {};
void user_select(bool first, bool second) {
  _Select(first) {} or _Select(second) {}
}
SYSTEM_TASK(UserMacroTask);
