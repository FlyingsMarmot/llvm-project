void complete(bool condition) {
  ;
}

// RUN: %clang_cc1 -fsyntax-only -code-completion-patterns -code-completion-at=%s:2:3 -std=gnu++11 %s -o - | FileCheck %s

// CHECK-DAG: COMPLETION: Pattern : _When (<#condition#>) _Accept (<#expression#>)
// CHECK-DAG: COMPLETION: Pattern : _When (<#condition#>) _Accept (<#expression#>) {
// CHECK-DAG: COMPLETION: Pattern : _When (<#condition#>) _Select (<#expression#>)
// CHECK-DAG: COMPLETION: Pattern : _When (<#condition#>) _Select (<#expression#>) {
// CHECK-DAG: COMPLETION: Pattern : _When (<#condition#>) _Timeout (<#expression#>) {
// CHECK-DAG: COMPLETION: Pattern : _When (<#condition#>) _Else {
// CHECK-NOT: COMPLETION: Pattern : _When (<#condition#>) {
