// RUN: %clang_cc1 -std=c++20 -fcxx-exceptions -Wno-everything -fsyntax-only -verify %s
// expected-no-diagnostics

struct Queue {};

_Mutex class MutexClass {
public:
  _Mutex void entry();
  _Nomutex void helper();
};

_Nomutex<Queue> class QueuedClass {};
_Mutex _Coroutine MutexCoroutine {};
_Mutex _Task<Queue, Queue> MutexTask {};

_Coroutine Coroutine {};
_Task<Queue> Task {};
_RealTimeTask<Queue> RealTimeTask {};
_PeriodicTask<Queue, Queue> PeriodicTask {};
_SporadicTask SporadicTask {};
_Actor Actor {};
_CorActor CorActor {};
_Monitor Monitor {};
_Cormonitor Cormonitor {};
_Exception Exception {};
_Event DeprecatedEvent {};

_Mutex void MutexClass::entry() {}
_Nomutex void MutexClass::helper() {}

bool alternate_operators(bool lhs, bool rhs) {
  return (lhs and rhs) or (not lhs);
}

unsigned alternate_operator_family(unsigned lhs, unsigned rhs) {
  lhs and_eq rhs;
  lhs or_eq rhs;
  lhs xor_eq rhs;
  unsigned combined = (lhs bitand rhs) bitor (lhs xor rhs);
  return compl combined + (lhs not_eq rhs);
}

void accept_and_select(bool first, bool second) {
  _Accept(first) {} or _Accept(second) {}
  _Accept(first, second) {}
  _Accept(first || second) {}
  _When(first and second) _Accept(first) {} or
      _When(first or second) _Timeout(1) {}
  _Accept(first) {} _When(second) _Else {}

  _Select(first or second) {} and _Select(first and second) {}
  _Select(first) {} or (_When(second) _Select(second) {} and
                        _Select(first or second) {})
  _Select(first) {} or _Timeout(1) {} _Else {}
  _Select(first) {} _When(second) _Else {}

  _AcceptReturn(first);
  _AcceptReturn(first) 1;
  _AcceptWait(first) 1;
  _AcceptWait(first) 1 _With 2;
}

void exception_controls() {
  _Enable;
  _Disable<Exception>;
  _Enable<Exception><DeprecatedEvent> {}
  _Disable<Exception> _Enable<DeprecatedEvent> {}
}

void exceptions(Exception &exception, int target) {
  try {
    _Throw exception;
  } _CatchResume(Exception &resumed) {
    _Resume resumed _At target;
    _ResumeTop resumed;
  } _Catch(...) {
    _Throw;
  } _Finally {
  }

  try {
  } _CatchResume(target.Exception &bound) {
  } _Catch(target.Exception &terminated) {
  }

  try {
    _Resume _At target;
  } _Finally {
  }
}

void labelled_control_flow() {
outer:
  for (;;) {
  inner:
    while (true) {
      continue outer;
      break inner;
    }
    break outer;
  }
}
