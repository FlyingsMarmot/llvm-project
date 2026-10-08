void complete() {
  int value;
}

// RUN: %clang_cc1 -fsyntax-only -code-completion-at=%s:2:3 -std=gnu++11 %s -o - | FileCheck %s

// CHECK-DAG: COMPLETION: _Actor
// CHECK-DAG: COMPLETION: _CorActor
// CHECK-DAG: COMPLETION: _Cormonitor
// CHECK-DAG: COMPLETION: _Coroutine
// CHECK-DAG: COMPLETION: _Event
// CHECK-DAG: COMPLETION: _Exception
// CHECK-DAG: COMPLETION: _Monitor
// CHECK-DAG: COMPLETION: _PeriodicTask
// CHECK-DAG: COMPLETION: _RealTimeTask
// CHECK-DAG: COMPLETION: _SporadicTask
// CHECK-DAG: COMPLETION: _Task
