// RUN: mlir-opt -transform-interpreter -cse -split-input-file %s | FileCheck %s

func.func @gemm_fill_fusion(%arg0 : tensor<?x?xf32>, %arg1 : tensor<?x?xf32>) -> tensor<?x?xf32> {
  %c0 = arith.constant 0 : index
  %c1 = arith.constant 1 : index
  %cst = arith.constant 0.0 : f32
  %d0 = tensor.dim %arg0, %c0 : tensor<?x?xf32>
  %d1 = tensor.dim %arg1, %c1 : tensor<?x?xf32>
  %init = tensor.empty(%d0, %d1) : tensor<?x?xf32>
  %fill = linalg.fill ins(%cst : f32) outs(%init : tensor<?x?xf32>) -> tensor<?x?xf32>
  %gemm = linalg.matmul ins(%arg0, %arg1 : tensor<?x?xf32>, tensor<?x?xf32>)
      outs(%fill : tensor<?x?xf32>) -> tensor<?x?xf32>
  return %gemm : tensor<?x?xf32>
}

module attributes {transform.with_named_sequence} {
  transform.named_sequence @__transform_main(%arg1 : !transform.any_op {transform.readonly}) {
    %matmul = transform.structured.match ops{["linalg.matmul"]} in %arg1
      : (!transform.any_op) -> !transform.any_op
    %a, %b, %c = transform.structured.fuse %matmul [10, 20]
      : (!transform.any_op) -> (!transform.any_op, !transform.any_op, !transform.any_op)
    transform.yield
  }
}
//      CHECK: func.func @gemm_fill_fusion(
// CHECK-SAME:     %[[ARG0:[a-zA-Z0-9]+]]: tensor<?x?xf32>
// CHECK-SAME:     %[[ARG1:[a-zA-Z0-9]+]]: tensor<?x?xf32>)
//      CHECK:   %[[INIT:.+]] = tensor.empty
//      CHECK:   scf.for %[[IV0:[a-zA-Z0-9]+]] =
// CHECK-SAME:       iter_args(%[[ITERARG0:.+]] = %[[INIT]])
//      CHECK:     scf.for %[[IV1:[a-zA-Z0-9]+]] =
// CHECK-SAME:         iter_args(%[[ITERARG1:.+]] = %[[ITERARG0]])
//  CHECK-DAG:       %[[LHS_TILE:.+]] = tensor.extract_slice %[[ARG0]][%[[IV0]], 0]
//  CHECK-DAG:       %[[RHS_TILE:.+]] = tensor.extract_slice %[[ARG1]][0, %[[IV1]]]
//  CHECK-DAG:       %[[INIT_TILE:.+]] = tensor.extract_slice %[[ITERARG1]][%[[IV0]], %[[IV1]]]
//      CHECK:       %[[FILL_TILE:.+]] = linalg.fill
// CHECK-SAME:           outs(%[[INIT_TILE]] :
//      CHECK:       %[[GEMM_TILE:.+]] = linalg.matmul
// CHECK-SAME:           ins(%[[LHS_TILE]], %[[RHS_TILE]] :
// CHECK-SAME:           outs(%[[FILL_TILE]] :
//      CHECK:       %[[INSERT:.+]] = tensor.insert_slice %[[GEMM_TILE]] into %[[ITERARG1]][%[[IV0]], %[[IV1]]]
//      CHECK:       scf.yield %[[INSERT]]

// -----

func.func @gemm_generic_fusion(%arg0 : tensor<?x?xf32>, %arg1 : tensor<?x?xf32>,
    %arg2 : tensor<?xf32>) -> tensor<?x?xf32> {
  %c0 = arith.constant 0 : index
  %c1 = arith.constant 1 : index
  %cst = arith.constant 0.0 : f32
  %d0 = tensor.dim %arg0, %c0 : tensor<?x?xf32>
  %d1 = tensor.dim %arg1, %c1 : tensor<?x?xf32>
  %init = tensor.empty(%d0, %d1) : tensor<?x?xf32>
  %fill = linalg.fill ins(%cst : f32) outs(%init : tensor<?x?xf32>) -> tensor<?x?xf32>
  %gemm = linalg.matmul ins(%arg0, %arg1 : tensor<?x?xf32>, tensor<?x?xf32>)
      outs(%fill : tensor<?x?xf32>) -> tensor<?x?xf32>
  %generic = linalg.generic {
      indexing_maps = [affine_map<(d0, d1) -> (d0, d1)>, affine_map<(d0, d1) -> (d1)>, affine_map<(d0, d1) -> (d0, d1)>],
      iterator_types = ["parallel", "parallel"]}
      ins(%gemm, %arg2 : tensor<?x?xf32>, tensor<?xf32>) outs(%init : tensor<?x?xf32>) {
    ^bb0(%b0 : f32, %b1 : f32, %b2 : f32):
      %add = arith.addf %b0, %b1 : f32
      linalg.yield %add : f32
  } -> tensor<?x?xf32>
  return %generic : tensor<?x?xf32>
}

module attributes {transform.with_named_sequence} {
  transform.named_sequence @__transform_main(%arg1 : !transform.any_op {transform.readonly}) {
    %generic = transform.structured.match ops{["linalg.generic"]} in %arg1
      : (!transform.any_op) -> !transform.any_op
    %a, %b, %c = transform.structured.fuse %generic [10, 20]
      : (!transform.any_op) -> (!transform.any_op, !transform.any_op, !transform.any_op)
    transform.yield
  }
}
//      CHECK: func.func @gemm_generic_fusion(
// CHECK-SAME:     %[[ARG0:[a-zA-Z0-9]+]]: tensor<?x?xf32>
// CHECK-SAME:     %[[ARG1:[a-zA-Z0-9]+]]: tensor<?x?xf32>,
// CHECK-SAME:     %[[ARG2:[a-zA-Z0-9]+]]: tensor<?xf32>)
//      CHECK:   %[[INIT:.+]] = tensor.empty
//      CHECK:   scf.for %[[IV0:[a-zA-Z0-9]+]] =
// CHECK-SAME:       iter_args(%[[ITERARG0:.+]] = %[[INIT]])
//      CHECK:     scf.for %[[IV1:[a-zA-Z0-9]+]] =
// CHECK-SAME:         iter_args(%[[ITERARG1:.+]] = %[[ITERARG0]])
//  CHECK-DAG:       %[[LHS_TILE:.+]] = tensor.extract_slice %[[ARG0]][%[[IV0]], 0]
//  CHECK-DAG:       %[[RHS_TILE:.+]] = tensor.extract_slice %[[ARG1]][0, %[[IV1]]]
//  CHECK-DAG:       %[[INIT_TILE:.+]] = tensor.extract_slice %[[INIT]][%[[IV0]], %[[IV1]]]
//      CHECK:       %[[FILL_TILE:.+]] = linalg.fill
// CHECK-SAME:           outs(%[[INIT_TILE]] :
//      CHECK:       %[[GEMM_TILE:.+]] = linalg.matmul
// CHECK-SAME:           ins(%[[LHS_TILE]], %[[RHS_TILE]] :
// CHECK-SAME:           outs(%[[FILL_TILE]] :
//  CHECK-DAG:       %[[BIAS_TILE:.+]] = tensor.extract_slice %[[ARG2]][%[[IV1]]]
//  CHECK-DAG:       %[[OUTS_TILE:.+]] = tensor.extract_slice %[[ITERARG1]][%[[IV0]], %[[IV1]]]
//      CHECK:       %[[GENERIC_TILE:.+]] = linalg.generic
// CHECK-SAME:           ins(%[[GEMM_TILE]], %[[BIAS_TILE]] :
// CHECK-SAME:           outs(%[[OUTS_TILE]] :
//      CHECK:       %[[INSERT:.+]] = tensor.insert_slice %[[GENERIC_TILE]] into %[[ITERARG1]][%[[IV0]], %[[IV1]]]
//      CHECK:       scf.yield %[[INSERT]]

// -----

func.func @gemm_gemm_fusion(%lhs0 : tensor<?x?xf32>, %rhs0 : tensor<?x?xf32>, %rhs1 : tensor<?x?xf32>) -> tensor<?x?xf32> {
  %c0 = arith.constant 0 : index
  %c1 = arith.constant 1 : index
  %cst = arith.constant 0.0 : f32
  %d0 = tensor.dim %lhs0, %c0 : tensor<?x?xf32>
  %d1 = tensor.dim %rhs0, %c1 : tensor<?x?xf32>
  %init0 = tensor.empty(%d0, %d1) : tensor<?x?xf32>
  %fill0 = linalg.fill ins(%cst : f32) outs(%init0 : tensor<?x?xf32>) -> tensor<?x?xf32>
  %gemm0 = linalg.matmul
      ins(%lhs0, %rhs0 : tensor<?x?xf32>, tensor<?x?xf32>) outs(%fill0 : tensor<?x?xf32>) -> tensor<?x?xf32>
  %d2 = tensor.dim %rhs1, %c1 : tensor<?x?xf32>
  %init1 = tensor.empty(%d0, %d2) : tensor<?x?xf32>
  %fill1 = linalg.fill ins(%cst : f32) outs(%init1 : tensor<?x?xf32>) -> tensor<?x?xf32>
  %gemm1 = linalg.matmul  
      ins(%gemm0, %rhs1 : tensor<?x?xf32>, tensor<?x?xf32>) outs(%fill1 : tensor<?x?xf32>) -> tensor<?x?xf32>
  return %gemm1 : tensor<?x?xf32>
}

module attributes {transform.with_named_sequence} {
  transform.named_sequence @__transform_main(%arg1 : !transform.any_op {transform.readonly}) {
    %matmuls = transform.structured.match ops{["linalg.matmul"]} in %arg1
      : (!transform.any_op) -> !transform.any_op
    %mm1, %mm2 = transform.split_handle %matmuls
      : (!transform.any_op) -> (!transform.any_op, !transform.any_op)
    %a, %b = transform.structured.fuse %mm2 [10]
      : (!transform.any_op) -> (!transform.any_op, !transform.any_op)
    transform.yield
  }
}
//      CHECK: func.func @gemm_gemm_fusion(
// CHECK-SAME:     %[[LHS0:[a-zA-Z0-9]+]]: tensor<?x?xf32>
// CHECK-SAME:     %[[RHS0:[a-zA-Z0-9]+]]: tensor<?x?xf32>,
// CHECK-SAME:     %[[RHS1:[a-zA-Z0-9]+]]: tensor<?x?xf32>)
//  CHECK-DAG:   %[[C0:.+]] = arith.constant 0 : index
//  CHECK-DAG:   %[[C1:.+]] = arith.constant 1 : index
//  CHECK-DAG:   %[[D0:.+]] = tensor.dim %[[LHS0]], %[[C0]]
//  CHECK-DAG:   %[[D1:.+]] = tensor.dim %[[RHS0]], %[[C1]]
//  CHECK-DAG:   %[[INIT0:.+]] = tensor.empty(%[[D0]], %[[D1]])
//  CHECK-DAG:   %[[D2:.+]] = tensor.dim %[[RHS1]], %[[C1]]
//      CHECK:   %[[INIT1:.+]] = tensor.empty(%[[D0]], %[[D2]])
//      CHECK:   scf.for %[[IV:[a-zA-Z0-9]+]] =
// CHECK-SAME:       iter_args(%[[ITERARG:.+]] = %[[INIT1]])
//  CHECK-DAG:     %[[LHS0_TILE:.+]] = tensor.extract_slice %[[LHS0]][%[[IV]], 0]
//  CHECK-DAG:     %[[RHS0_TILE:.+]] = tensor.extract_slice %[[RHS0]][0, 0]
//  CHECK-DAG:     %[[INIT0_TILE:.+]] = tensor.extract_slice %[[INIT0]][%[[IV]], 0]
//      CHECK:     %[[FILL0_TILE:.+]] = linalg.fill
// CHECK-SAME:         outs(%[[INIT0_TILE]] :
//      CHECK:     %[[GEMM0_TILE:.+]] = linalg.matmul
// CHECK-SAME:         ins(%[[LHS0_TILE]], %[[RHS0_TILE]] :
// CHECK-SAME:         outs(%[[FILL0_TILE]] :
//  CHECK-DAG:     %[[RHS1_TILE:.+]] = tensor.extract_slice %[[RHS1]][0, 0]
//  CHECK-DAG:     %[[INIT1_TILE:.+]] = tensor.extract_slice %[[ITERARG]][%[[IV]], 0]
//      CHECK:     %[[FILL1_TILE:.+]] = linalg.fill
// CHECK-SAME:         outs(%[[INIT1_TILE]] :
//      CHECK:     %[[GEMM1_TILE:.+]] = linalg.matmul
// CHECK-SAME:         ins(%[[GEMM0_TILE]], %[[RHS1_TILE]] :
// CHECK-SAME:         outs(%[[FILL1_TILE]] :
//      CHECK:     %[[INSERT:.+]] = tensor.insert_slice %[[GEMM1_TILE]] into %[[ITERARG]][%[[IV]], 0]
//      CHECK:     scf.yield %[[INSERT]]

// -----

func.func @gemm_transpose_fusion(%arg0 : tensor<?x?xf32>, %arg1 : tensor<?x?xf32>) -> tensor<?x?xf32> {
  %c0 = arith.constant 0 : index
  %c1 = arith.constant 1 : index
  %cst = arith.constant 0.0 : f32
  %d0 = tensor.dim %arg0, %c0 : tensor<?x?xf32>
  %d1 = tensor.dim %arg1, %c1 : tensor<?x?xf32>
  %init0 = tensor.empty(%d0, %d1) : tensor<?x?xf32>
  %fill = linalg.fill ins(%cst : f32) outs(%init0 : tensor<?x?xf32>) -> tensor<?x?xf32>
  %gemm = linalg.matmul ins(%arg0, %arg1 : tensor<?x?xf32>, tensor<?x?xf32>)
      outs(%fill : tensor<?x?xf32>) -> tensor<?x?xf32>
  %init1 = tensor.empty(%d1, %d0) : tensor<?x?xf32>
  %transpose = linalg.generic {
      indexing_maps = [affine_map<(d0, d1) -> (d0, d1)>, affine_map<(d0, d1) -> (d1, d0)>],
      iterator_types = ["parallel", "parallel"]}
      ins(%gemm : tensor<?x?xf32>) outs(%init1 : tensor<?x?xf32>) {
    ^bb0(%b0 : f32, %b1 : f32):
      linalg.yield %b0 : f32
  } -> tensor<?x?xf32>
  return %transpose : tensor<?x?xf32>
}

module attributes {transform.with_named_sequence} {
  transform.named_sequence @__transform_main(%arg1 : !transform.any_op {transform.readonly}) {
    %generic = transform.structured.match ops{["linalg.generic"]} in %arg1
      : (!transform.any_op) -> !transform.any_op
    %a, %b, %c = transform.structured.fuse %generic [10, 20]
      : (!transform.any_op) -> (!transform.any_op, !transform.any_op, !transform.any_op)
    transform.yield
  }
}
//      CHECK: func.func @gemm_transpose_fusion(
// CHECK-SAME:     %[[ARG0:[a-zA-Z0-9]+]]: tensor<?x?xf32>
// CHECK-SAME:     %[[ARG1:[a-zA-Z0-9]+]]: tensor<?x?xf32>)
//  CHECK-DAG:   %[[C0:.+]] = arith.constant 0 : index
//  CHECK-DAG:   %[[C1:.+]] = arith.constant 1 : index
//  CHECK-DAG:   %[[D0:.+]] = tensor.dim %[[ARG0]], %[[C0]]
//  CHECK-DAG:   %[[D1:.+]] = tensor.dim %[[ARG1]], %[[C1]]
//  CHECK-DAG:   %[[INIT0:.+]] = tensor.empty(%[[D0]], %[[D1]])
//  CHECK-DAG:   %[[INIT1:.+]] = tensor.empty(%[[D1]], %[[D0]])
//      CHECK:   scf.for %[[IV0:[a-zA-Z0-9]+]] =
// CHECK-SAME:       iter_args(%[[ITERARG0:.+]] = %[[INIT1]])
//      CHECK:     scf.for %[[IV1:[a-zA-Z0-9]+]] =
// CHECK-SAME:         iter_args(%[[ITERARG1:.+]] = %[[ITERARG0]])
//  CHECK-DAG:       %[[LHS_TILE:.+]] = tensor.extract_slice %[[ARG0]][%[[IV0]], 0]
//  CHECK-DAG:       %[[RHS_TILE:.+]] = tensor.extract_slice %[[ARG1]][0, %[[IV1]]]
//  CHECK-DAG:       %[[INIT0_TILE:.+]] = tensor.extract_slice %[[INIT0]][%[[IV0]], %[[IV1]]]
//      CHECK:       %[[FILL_TILE:.+]] = linalg.fill
// CHECK-SAME:           outs(%[[INIT0_TILE]] :
//      CHECK:       %[[GEMM_TILE:.+]] = linalg.matmul
// CHECK-SAME:           ins(%[[LHS_TILE]], %[[RHS_TILE]] :
// CHECK-SAME:           outs(%[[FILL_TILE]] :
//  CHECK-DAG:       %[[OUTS_TILE:.+]] = tensor.extract_slice %[[ITERARG1]][%[[IV1]], %[[IV0]]]
//      CHECK:       %[[GENERIC_TILE:.+]] = linalg.generic
// CHECK-SAME:           ins(%[[GEMM_TILE]] :
// CHECK-SAME:           outs(%[[OUTS_TILE]] :
//      CHECK:       %[[INSERT:.+]] = tensor.insert_slice %[[GENERIC_TILE]] into %[[ITERARG1]][%[[IV1]], %[[IV0]]]
//      CHECK:       scf.yield %[[INSERT]]

// -----

func.func @interchange_matmul_fusion(%arg0 : tensor<?x?xf32>, %arg1 : tensor<?x?xf32>) -> tensor<?x?xf32> {
  %c0 = arith.constant 0 : index
  %c1 = arith.constant 1 : index
  %d0 = tensor.dim %arg0, %c0 : tensor<?x?xf32>
  %d1 = tensor.dim %arg1, %c1 : tensor<?x?xf32>
  %cst = arith.constant 0.0 : f32
  %0 = tensor.empty(%d0, %d1) : tensor<?x?xf32>
  %1 = linalg.fill ins(%cst : f32) outs(%0 : tensor<?x?xf32>) -> tensor<?x?xf32>
  %2 = linalg.matmul ins(%arg0, %arg1 : tensor<?x?xf32>, tensor<?x?xf32>)
      outs(%1 : tensor<?x?xf32>) -> tensor<?x?xf32>
  %3 = linalg.generic {
      indexing_maps = [affine_map<(d0, d1) -> (d0, d1)>, affine_map<(d0, d1) -> (d0, d1)>],
      iterator_types = ["parallel", "parallel"]}
      ins(%2 : tensor<?x?xf32>) outs(%0 : tensor<?x?xf32>) {
      ^bb0(%b0 : f32, %b1 : f32):
        %4 = arith.addf %b0, %b0 : f32
        linalg.yield %4 : f32
      } -> tensor<?x?xf32>
  return %3 : tensor<?x?xf32>
}

module attributes {transform.with_named_sequence} {
  transform.named_sequence @__transform_main(%arg1 : !transform.any_op {transform.readonly}) {
    %generic = transform.structured.match ops{["linalg.generic"]} in %arg1
      : (!transform.any_op) -> !transform.any_op
    %a, %b, %c = transform.structured.fuse %generic [10, 20] interchange[1, 0]
      : (!transform.any_op) -> (!transform.any_op, !transform.any_op, !transform.any_op)
    transform.yield
  }
}
//      CHECK: func.func @interchange_matmul_fusion(
// CHECK-SAME:     %[[ARG0:[a-zA-Z0-9]+]]: tensor<?x?xf32>
// CHECK-SAME:     %[[ARG1:[a-zA-Z0-9]+]]: tensor<?x?xf32>)
//      CHECK:   %[[INIT:.+]] = tensor.empty
//      CHECK:   scf.for %[[IV0:[a-zA-Z0-9]+]] =
// CHECK-SAME:       iter_args(%[[ITERARG0:.+]] = %[[INIT]])
//      CHECK:     scf.for %[[IV1:[a-zA-Z0-9]+]] =
// CHECK-SAME:         iter_args(%[[ITERARG1:.+]] = %[[ITERARG0]])
//  CHECK-DAG:       %[[LHS_TILE:.+]] = tensor.extract_slice %[[ARG0]][%[[IV1]], 0]
//  CHECK-DAG:       %[[RHS_TILE:.+]] = tensor.extract_slice %[[ARG1]][0, %[[IV0]]]
//  CHECK-DAG:       %[[INIT_TILE:.+]] = tensor.extract_slice %[[INIT]][%[[IV1]], %[[IV0]]]
//      CHECK:       %[[FILL_TILE:.+]] = linalg.fill
// CHECK-SAME:           outs(%[[INIT_TILE]] :
//      CHECK:       %[[GEMM_TILE:.+]] = linalg.matmul
// CHECK-SAME:           ins(%[[LHS_TILE]], %[[RHS_TILE]] :
// CHECK-SAME:           outs(%[[FILL_TILE]] :
//      CHECK:       %[[INIT_TILE_2:.+]] = tensor.extract_slice %[[ITERARG1]][%[[IV1]], %[[IV0]]]
//      CHECK:       %[[GENERIC_TILE:.+]] = linalg.generic
// CHECK-SAME:           ins(%[[GEMM_TILE]] :
// CHECK-SAME:           outs(%[[INIT_TILE_2]] :
//      CHECK:       %[[INSERT:.+]] = tensor.insert_slice %[[GENERIC_TILE]] into %[[ITERARG1]][%[[IV1]], %[[IV0]]]
//      CHECK:       scf.yield %[[INSERT]]

// -----

func.func @matmul_plus_matmul(%arg0: tensor<?x?xf32>, %arg1: tensor<?x?xf32>,
                         %arg2: tensor<?x?xf32>) -> tensor<?x?xf32>{
  %c0 = arith.constant 0 : index
  %c1 = arith.constant 1 : index
  %0 = tensor.dim %arg2, %c0 : tensor<?x?xf32>
  %1 = tensor.dim %arg2, %c1 : tensor<?x?xf32>
  %2 = linalg.matmul ins(%arg0, %arg1 : tensor<?x?xf32>, tensor<?x?xf32>)
    outs(%arg2 : tensor<?x?xf32>) -> tensor<?x?xf32>
  %3 = tensor.dim %2, %c0 : tensor<?x?xf32>
  %4 = tensor.dim %2, %c1 : tensor<?x?xf32>
  %5 = tensor.empty(%3, %4) : tensor<?x?xf32>
  %6 = linalg.generic
    {indexing_maps = [affine_map<(d0, d1) -> (d0, d1)>,
                      affine_map<(d0, d1) -> (d0, d1)>,
                      affine_map<(d0, d1) -> (d0, d1)>],
     iterator_types = ["parallel", "parallel"]}
    ins(%2, %2 : tensor<?x?xf32>, tensor<?x?xf32>)
    outs(%5 : tensor<?x?xf32>) {
    ^bb0(%arg3 : f32, %arg4 : f32, %arg5 : f32) :
      %7 = arith.addf %arg3, %arg4 : f32
      linalg.yield %7 : f32
    } -> tensor<?x?xf32>
  return %6 : tensor<?x?xf32>
}

module attributes {transform.with_named_sequence} {
  transform.named_sequence @__transform_main(%arg1 : !transform.any_op {transform.readonly}) {
    %generic = transform.structured.match ops{["linalg.generic"]} in %arg1
      : (!transform.any_op) -> !transform.any_op
    %a, %b, %c = transform.structured.fuse %generic [10, 20]
      : (!transform.any_op) -> (!transform.any_op, !transform.any_op, !transform.any_op)
    transform.yield
  }
}
//       CHECK: func @matmul_plus_matmul
//  CHECK-SAME:   %[[ARG0:[a-zA-Z0-9_]+]]: tensor<?x?xf32>
//  CHECK-SAME:   %[[ARG1:[a-zA-Z0-9_]+]]: tensor<?x?xf32>
//  CHECK-SAME:   %[[ARG2:[a-zA-Z0-9_]+]]: tensor<?x?xf32>
//       CHECK:   %[[RESULT:.+]] = scf.for %[[IV0:[a-zA-Z0-9_]+]]
//  CHECK-SAME:     iter_args(%[[ARG4:.+]] = %{{[a-zA-Z0-9_]+}})
//       CHECK:     %[[YIELD:.+]] = scf.for %[[IV1:[a-zA-Z0-9_]+]]
//  CHECK-SAME:       iter_args(%[[ARG6:.+]] = %[[ARG4]])
//   CHECK-DAG:       %[[ST_ARG0:.+]] = tensor.extract_slice %[[ARG0]][%[[IV0]], 0]
//   CHECK-DAG:       %[[ST_ARG1:.+]] = tensor.extract_slice %[[ARG1]][0, %[[IV1]]]
//   CHECK-DAG:       %[[ST_ARG2:.+]] = tensor.extract_slice %[[ARG2]][%[[IV0]], %[[IV1]]]
//       CHECK:       %[[MATMUL:.+]] = linalg.matmul
//  CHECK-SAME:         ins(%[[ST_ARG0]], %[[ST_ARG1]] :
//  CHECK-SAME:         outs(%[[ST_ARG2]] :
//       CHECK:       %[[ST_ARG6:.+]] = tensor.extract_slice %[[ARG6]][%[[IV0]], %[[IV1]]]
//       CHECK:       %[[ST_RESULT:.+]] = linalg.generic
//  CHECK-SAME:         ins(%[[MATMUL]], %[[MATMUL]] :
//  CHECK-SAME:         outs(%[[ST_ARG6]] :
//       CHECK:       %[[UPDATE:.+]] = tensor.insert_slice %[[ST_RESULT]]
//  CHECK-SAME:         into %[[ARG6]][%[[IV0]], %[[IV1]]]
//       CHECK:       scf.yield %[[UPDATE]]
//       CHECK:     scf.yield %[[YIELD]]
//       CHECK:   return %[[RESULT]]

// -----

func.func @matmul_plus_transpose_matmul(%arg0: tensor<?x?xf32>, %arg1: tensor<?x?xf32>,
                         %arg2: tensor<?x?xf32>) -> tensor<?x?xf32>{
  %c0 = arith.constant 0 : index
  %c1 = arith.constant 1 : index
  %0 = tensor.dim %arg2, %c0 : tensor<?x?xf32>
  %1 = tensor.dim %arg2, %c1 : tensor<?x?xf32>
  %2 = linalg.matmul ins(%arg0, %arg1 : tensor<?x?xf32>, tensor<?x?xf32>)
    outs(%arg2 : tensor<?x?xf32>) -> tensor<?x?xf32>
  %3 = tensor.dim %2, %c0 : tensor<?x?xf32>
  %4 = tensor.dim %2, %c1 : tensor<?x?xf32>
  %5 = tensor.empty(%3, %4) : tensor<?x?xf32>
  %6 = linalg.generic
    {indexing_maps = [affine_map<(d0, d1) -> (d0, d1)>,
                      affine_map<(d0, d1) -> (d1, d0)>,
                      affine_map<(d0, d1) -> (d0, d1)>],
     iterator_types = ["parallel", "parallel"]}
    ins(%2, %2 : tensor<?x?xf32>, tensor<?x?xf32>)
    outs(%5 : tensor<?x?xf32>) {
    ^bb0(%arg3 : f32, %arg4 : f32, %arg5 : f32) :
      %7 = arith.addf %arg3, %arg4 : f32
      linalg.yield %7 : f32
    } -> tensor<?x?xf32>
  return %6 : tensor<?x?xf32>
}

module attributes {transform.with_named_sequence} {
  transform.named_sequence @__transform_main(%arg1 : !transform.any_op {transform.readonly}) {
    %generic = transform.structured.match ops{["linalg.generic"]} in %arg1
      : (!transform.any_op) -> !transform.any_op
    %a, %b, %c = transform.structured.fuse %generic [10, 20]
      : (!transform.any_op) -> (!transform.any_op, !transform.any_op, !transform.any_op)
    transform.yield
  }
}
//       CHECK: func @matmul_plus_transpose_matmul
//  CHECK-SAME:   %[[ARG0:[a-zA-Z0-9_]+]]: tensor<?x?xf32>
//  CHECK-SAME:   %[[ARG1:[a-zA-Z0-9_]+]]: tensor<?x?xf32>
//  CHECK-SAME:   %[[ARG2:[a-zA-Z0-9_]+]]: tensor<?x?xf32>
//       CHECK:   %[[RESULT:.+]] = scf.for %[[IV0:[a-zA-Z0-9_]+]]
//  CHECK-SAME:     iter_args(%[[ARG4:.+]] = %{{[a-zA-Z0-9_]+}})
//       CHECK:     %[[YIELD:.+]] = scf.for %[[IV1:[a-zA-Z0-9_]+]]
//  CHECK-SAME:       iter_args(%[[ARG6:.+]] = %[[ARG4]])
//   CHECK-DAG:       %[[ST_ARG0:.+]] = tensor.extract_slice %[[ARG0]][%[[IV0]], 0]
//   CHECK-DAG:       %[[ST_ARG1:.+]] = tensor.extract_slice %[[ARG1]][0, %[[IV1]]]
//   CHECK-DAG:       %[[ST_ARG2:.+]] = tensor.extract_slice %[[ARG2]][%[[IV0]], %[[IV1]]]
//       CHECK:       %[[LHS:.+]] = linalg.matmul
//  CHECK-SAME:         ins(%[[ST_ARG0]], %[[ST_ARG1]]
//  CHECK-SAME:           : tensor<?x?xf32>, tensor<?x?xf32>)
//  CHECK-SAME:         outs(%[[ST_ARG2]] : tensor<?x?xf32>)
//   CHECK-DAG:       %[[STR_ARG0:.+]] = tensor.extract_slice %[[ARG0]][%[[IV1]], 0]
//   CHECK-DAG:       %[[STR_ARG1:.+]] = tensor.extract_slice %[[ARG1]][0, %[[IV0]]]
//   CHECK-DAG:       %[[STR_ARG2:.+]] = tensor.extract_slice %[[ARG2]][%[[IV1]], %[[IV0]]]
//       CHECK:       %[[RHS:.+]] = linalg.matmul
//  CHECK-SAME:         ins(%[[STR_ARG0]], %[[STR_ARG1]] :
//  CHECK-SAME:         outs(%[[STR_ARG2]] :
//       CHECK:       %[[ST_ARG6:.+]] = tensor.extract_slice %[[ARG6]][%[[IV0]], %[[IV1]]]
//       CHECK:       %[[ST_RESULT:.+]] = linalg.generic
//  CHECK-SAME:         ins(%[[LHS]], %[[RHS]] :
//  CHECK-SAME:         outs(%[[ST_ARG6]] :
//       CHECK:       %[[UPDATE:.+]] = tensor.insert_slice %[[ST_RESULT]]
//  CHECK-SAME:         into %[[ARG6]][%[[IV0]], %[[IV1]]]
//       CHECK:       scf.yield %[[UPDATE]]
//       CHECK:     scf.yield %[[YIELD]]
//       CHECK:   return %[[RESULT]]

// -----

func.func @matmul_sequence_fusion(%arg0: tensor<?x?xf32>, %arg1: tensor<?x?xf32>,
    %arg2: tensor<?x?xf32>, %arg3: tensor<?x?xf32>, %arg4: tensor<?x?xf32>,
    %arg5: tensor<?x?xf32>, %arg6: tensor<?x?xf32>) -> tensor<?x?xf32> {
  %0 = linalg.matmul ins(%arg0, %arg1 : tensor<?x?xf32>, tensor<?x?xf32>)
    outs(%arg2 : tensor<?x?xf32>) -> tensor<?x?xf32> // [M, N0] * [N0, N1]
  %1 = linalg.matmul ins(%0, %arg3 : tensor<?x?xf32>, tensor<?x?xf32>)
    outs(%arg4 : tensor<?x?xf32>) -> tensor<?x?xf32> // [M, N1] * [N1, N2]
  %2 = linalg.matmul ins(%1, %arg5 : tensor<?x?xf32>, tensor<?x?xf32>)
    outs(%arg6 : tensor<?x?xf32>) -> tensor<?x?xf32> // [M, N2] * [N2, N3]
  return %2 : tensor<?x?xf32>
}

module attributes {transform.with_named_sequence} {
  transform.named_sequence @__transform_main(%arg1 : !transform.any_op {transform.readonly}) {
    %matmuls = transform.structured.match ops{["linalg.matmul"]} in %arg1
      : (!transform.any_op) -> !transform.any_op
    %mm1, %mm2, %mm3 = transform.split_handle %matmuls
      : (!transform.any_op) -> (!transform.any_op, !transform.any_op, !transform.any_op)
    %a, %b = transform.structured.fuse %mm3 [10]
      : (!transform.any_op) -> (!transform.any_op, !transform.any_op)
    transform.yield
  }
}
//       CHECK: #[[MAP:.+]] = affine_map<(d0)[s0] -> (-d0 + s0, 10)>
//       CHECK: func @matmul_sequence_fusion(
//  CHECK-SAME:   %[[ARG0:[a-zA-Z0-9_]+]]: tensor<?x?xf32>
//  CHECK-SAME:   %[[ARG1:[a-zA-Z0-9_]+]]: tensor<?x?xf32>
//  CHECK-SAME:   %[[ARG2:[a-zA-Z0-9_]+]]: tensor<?x?xf32>
//  CHECK-SAME:   %[[ARG3:[a-zA-Z0-9_]+]]: tensor<?x?xf32>
//  CHECK-SAME:   %[[ARG4:[a-zA-Z0-9_]+]]: tensor<?x?xf32>
//  CHECK-SAME:   %[[ARG5:[a-zA-Z0-9_]+]]: tensor<?x?xf32>
//  CHECK-SAME:   %[[ARG6:[a-zA-Z0-9_]+]]: tensor<?x?xf32>) -> tensor<?x?xf32> {
//   CHECK-DAG:   %[[C0:.+]] = arith.constant 0 : index
//   CHECK-DAG:   %[[C1:.+]] = arith.constant 1 : index
//   CHECK-DAG:   %[[ORIG_GEMM1:.+]] = linalg.matmul ins(%[[ARG0]], %[[ARG1]] :
//   CHECK-DAG:   %[[ORIG_GEMM2:.+]] = linalg.matmul ins(%[[ORIG_GEMM1]], %[[ARG3]] :
//   CHECK-DAG:   %[[M:.+]] = tensor.dim %[[ORIG_GEMM2]], %[[C0]]
//   CHECK-DAG:   %[[N2:.+]] = tensor.dim %[[ORIG_GEMM2]], %[[C1]]
//   CHECK-DAG:   %[[N3:.+]] = tensor.dim %[[ARG5]], %[[C1]]
//       CHECK:   %[[R0:.+]] = scf.for %[[IV:[a-zA-Z0-9_]+]] =
//  CHECK-SAME:       iter_args(%[[ARG8:.+]] = %[[ARG6]]) -> (tensor<?x?xf32>) {
//   CHECK-DAG:     %[[N1:.+]] = tensor.dim %[[ORIG_GEMM1]], %[[C1]]
//   CHECK-DAG:     %[[N0:.+]] = tensor.dim %[[ARG0]], %[[C1]]
//   CHECK-DAG:     %[[TILE_M:.+]] = affine.min #[[MAP]](%[[IV]])[%[[M]]]
//   CHECK-DAG:     %[[SLICE_ARG0:.+]] = tensor.extract_slice %[[ARG0]][%[[IV]], 0] [%[[TILE_M]], %[[N0]]]
//   CHECK-DAG:     %[[SLICE_ARG1:.+]] = tensor.extract_slice %[[ARG1]][0, 0] [%[[N0]], %[[N1]]]
//   CHECK-DAG:     %[[SLICE_ARG2:.+]] = tensor.extract_slice %[[ARG2]][%[[IV]], 0] [%[[TILE_M]], %[[N1]]]
//   CHECK-DAG:     %[[TILE_GEMM1:.+]] = linalg.matmul ins(%[[SLICE_ARG0]], %[[SLICE_ARG1]] :
//  CHECK-SAME:         outs(%[[SLICE_ARG2]] :
//   CHECK-DAG:     %[[SLICE_ARG3:.+]] = tensor.extract_slice %[[ARG3]][0, 0] [%[[N1]], %[[N2]]]
//   CHECK-DAG:     %[[SLICE_ARG4:.+]] = tensor.extract_slice %[[ARG4]][%[[IV]], 0] [%[[TILE_M]], %[[N2]]]
//   CHECK-DAG:     %[[TILE_GEMM2:.+]] = linalg.matmul ins(%[[TILE_GEMM1]], %[[SLICE_ARG3]] :
//  CHECK-SAME:         outs(%[[SLICE_ARG4]] :
//   CHECK-DAG:     %[[SLICE_ARG5:.+]] = tensor.extract_slice %[[ARG5]][0, 0] [%[[N2]], %[[N3]]]
//   CHECK-DAG:     %[[SLICE_ARG6:.+]] = tensor.extract_slice %[[ARG8]][%[[IV]], 0] [%[[TILE_M]], %[[N3]]]
//   CHECK-DAG:     %[[TILE_GEMM3:.+]] = linalg.matmul
//  CHECK-SAME:         ins(%[[TILE_GEMM2]], %[[SLICE_ARG5]] :
//  CHECK-SAME:         outs(%[[SLICE_ARG6]] :
//       CHECK:     %[[UPDATE:.+]] = tensor.insert_slice %[[TILE_GEMM3]] into %[[ARG8]][%[[IV]], 0] [%[[TILE_M]], %[[N3]]]
//       CHECK:     scf.yield %[[UPDATE]]

// -----

func.func @reduction_sequence(%arg0: tensor<30x3xf32>) -> tensor<30x3xf32> {
  %cst = arith.constant 0.000000e+00 : f32
  %cst_0 = arith.constant 0xFF800000 : f32
  %0 = tensor.empty() : tensor<30xf32>
  %1 = linalg.fill ins(%cst_0 : f32) outs(%0 : tensor<30xf32>) -> tensor<30xf32>
  %2 = linalg.generic {
      indexing_maps = [affine_map<(d0, d1) -> (d0, d1)>, affine_map<(d0, d1) -> (d0)>],
      iterator_types = ["parallel", "reduction"]}
      ins(%arg0 : tensor<30x3xf32>) outs(%1 : tensor<30xf32>) {
    ^bb0(%arg1: f32, %arg2: f32):
      %8 = arith.maximumf %arg2, %arg1 : f32
      linalg.yield %8 : f32
    } -> tensor<30xf32>
  %3 = tensor.empty() : tensor<30x3xf32>
  %4 = linalg.fill ins(%cst : f32) outs(%0 : tensor<30xf32>) -> tensor<30xf32>
  %5:2 = linalg.generic {
      indexing_maps = [affine_map<(d0, d1) -> (d0, d1)>, affine_map<(d0, d1) -> (d0)>,
                       affine_map<(d0, d1) -> (d0)>, affine_map<(d0, d1) -> (d0, d1)>],
      iterator_types = ["parallel", "reduction"]}
      ins(%arg0, %2 : tensor<30x3xf32>, tensor<30xf32>) outs(%4, %3 : tensor<30xf32>, tensor<30x3xf32>) {
    ^bb0(%arg1: f32, %arg2: f32, %arg3: f32, %arg4: f32):
      %8 = arith.subf %arg1, %arg2 : f32
      %9 = math.exp %8 : f32
      %10 = arith.addf %arg3, %9 : f32
      linalg.yield %10, %9 : f32, f32
    } -> (tensor<30xf32>, tensor<30x3xf32>)
  %6 = linalg.generic {
      indexing_maps = [affine_map<(d0, d1) -> (d0, d1)>, affine_map<(d0, d1) -> (d0)>,
                       affine_map<(d0, d1) -> (d0, d1)>],
      iterator_types = ["parallel", "parallel"]}
      ins(%5#1, %5#0 : tensor<30x3xf32>, tensor<30xf32>) outs(%3 : tensor<30x3xf32>) {
    ^bb0(%arg1: f32, %arg2: f32, %arg3: f32):
      %8 = arith.divf %arg1, %arg2 : f32
      linalg.yield %8 : f32
    } -> tensor<30x3xf32>
  return %6 : tensor<30x3xf32>
}

module attributes {transform.with_named_sequence} {
  transform.named_sequence @__transform_main(%arg1 : !transform.any_op {transform.readonly}) {
    %generics = transform.structured.match ops{["linalg.generic"]} in %arg1
      : (!transform.any_op) -> !transform.any_op
    %generic1, %generic2, %generic3 = transform.split_handle %generics
      : (!transform.any_op) -> (!transform.any_op, !transform.any_op, !transform.any_op)
    %a, %b = transform.structured.fuse %generic3 [10]
      : (!transform.any_op) -> (!transform.any_op, !transform.any_op)
    transform.yield
  }
}
//       CHECK: func @reduction_sequence(%[[ARG0:.+]]: tensor<30x3xf32>)
//   CHECK-DAG:   %[[INIT0:.+]] = tensor.empty() : tensor<30xf32>
//   CHECK-DAG:   %[[INIT1:.+]] = tensor.empty() : tensor<30x3xf32>
//       CHECK:   %[[RESULT:[a-zA-Z0-9]+]] = scf.for %[[IV:[a-zA-Z0-9]+]]
//  CHECK-SAME:       iter_args(%[[ITERARG0:[a-zA-Z0-9]+]] = %[[INIT1]])
//   CHECK-DAG:     %[[ARG0_SLICE:.+]] = tensor.extract_slice %[[ARG0]][%[[IV]], 0]
//   CHECK-DAG:     %[[INIT0_SLICE:.+]] = tensor.extract_slice %[[INIT0]][%[[IV]]]
//       CHECK:     %[[FILL0:.+]] = linalg.fill
//  CHECK-SAME:         outs(%[[INIT0_SLICE]] :
//       CHECK:     %[[GENERIC0:.+]] = linalg.generic
//  CHECK-SAME:         ins(%[[ARG0_SLICE]] :
//  CHECK-SAME:         outs(%[[FILL0]] :
//       CHECK:     %[[FILL1:.+]] = linalg.fill
//  CHECK-SAME:         outs(%[[INIT0_SLICE]] :
//       CHECK:     %[[INIT1_SLICE:.+]] = tensor.extract_slice %[[INIT1]][%[[IV]], 0]
//       CHECK:     %[[GENERIC1:.+]]:2 = linalg.generic
//  CHECK-SAME:         ins(%[[ARG0_SLICE]], %[[GENERIC0]] :
//  CHECK-SAME:         outs(%[[FILL1]], %[[INIT1_SLICE]] :
//       CHECK:     %[[ITERARG0_SLICE:.+]] = tensor.extract_slice %[[ITERARG0]][%[[IV]], 0]
//       CHECK:     %[[GENERIC2:.+]] = linalg.generic
//  CHECK-SAME:         ins(%[[GENERIC1]]#1, %[[GENERIC1]]#0 :
//  CHECK-SAME:         outs(%[[ITERARG0_SLICE]] :
//   CHECK-DAG:     %[[INSERTSLICE:.+]] = tensor.insert_slice %[[GENERIC2]] into %[[ITERARG0]][%[[IV]], 0]
//       CHECK:     scf.yield %[[INSERTSLICE]]
//       CHECK:   return %[[RESULT]]

// -----

func.func @pad_producer_fusion(%arg0 : tensor<10xf32>) -> tensor<16xf32> {
  %0 = tensor.empty() : tensor<10xf32>
  %1 = linalg.generic {
      indexing_maps = [affine_map<(d0) -> (d0)>, affine_map<(d0) -> (d0)>],
      iterator_types = ["parallel"]}
      ins(%arg0 : tensor<10xf32>) outs(%0 : tensor<10xf32>) {
    ^bb0(%b0 : f32, %b1 : f32):
      %2 = arith.addf %b0, %b0: f32
      linalg.yield %2 : f32
  } -> tensor<10xf32>
  %cst = arith.constant 0.0 : f32
  %2 = tensor.pad %1 low[4] high[2] {
    ^bb0(%arg1 : index):
      tensor.yield %cst : f32
  } : tensor<10xf32> to tensor<16xf32>
  return %2 : tensor<16xf32>
}
module attributes {transform.with_named_sequence} {
  transform.named_sequence @__transform_main(%arg1 : !transform.any_op {transform.readonly}) {
    %generic = transform.structured.match ops{["linalg.generic"]} in %arg1
      : (!transform.any_op) -> !transform.any_op
    %pad = transform.structured.match ops{["tensor.pad"]} in %arg1
      : (!transform.any_op) -> !transform.any_op
    %a, %b = transform.structured.fuse %pad [8]
      : (!transform.any_op) -> (!transform.any_op, !transform.any_op)
    transform.yield
  }
}
// CHECK-LABEL: func @pad_producer_fusion
//  CHECK-SAME:     %[[ARG0:.+]]: tensor<10xf32>
//       CHECK:   %[[FOR_RESULT:.+]] = scf.for
//       CHECK:     %[[IF_RESULT:.+]] = scf.if
//       CHECK:     else
//       CHECK:       %[[SLICE:.+]] = tensor.extract_slice %[[ARG0]]
//       CHECK:       %[[GENERIC:.+]] = linalg.generic
//  CHECK-SAME:           ins(%[[SLICE]] :
//       CHECK:       %[[PAD:.+]] = tensor.pad %[[GENERIC]]
//       CHECK:       %[[CAST:.+]] = tensor.cast %[[PAD]]
//       CHECK:       scf.yield %[[CAST]]
//       CHECK:     %[[INSERT_SLICE:.+]] = tensor.insert_slice %[[IF_RESULT]]
//       CHECK:     scf.yield %[[INSERT_SLICE]]
//       CHECK:   return %[[FOR_RESULT]]

// -----

func.func @imperfect_unpack_producer_fusion(%source: tensor<1x1x288x8x4xf32>, %dest: tensor<1x2x1152xf32>) -> tensor<1x2x1152xf32> {
  %0 = tensor.unpack %source
      outer_dims_perm = [0, 1, 2]
      inner_dims_pos = [1, 2]
      inner_tiles = [8, 4] into %dest
      : tensor<1x1x288x8x4xf32> -> tensor<1x2x1152xf32>
  %1 = tensor.empty() : tensor<1x2x1152xf32>
  %cst = arith.constant 1.0 : f32
  %2 = linalg.generic {indexing_maps = [affine_map<(d0, d1, d2) -> (d0, d1, d2)>,
                                        affine_map<(d0, d1, d2) -> (d0, d1, d2)>],
                       iterator_types = ["parallel", "parallel", "parallel"]}
                       ins(%0 : tensor<1x2x1152xf32>)
                       outs(%1 : tensor<1x2x1152xf32>) {
  ^bb0(%in: f32, %out: f32):
    %7 = arith.addf %in, %cst : f32
    linalg.yield %7 : f32
  } -> tensor<1x2x1152xf32>
  return %2 : tensor<1x2x1152xf32>
}

module attributes {transform.with_named_sequence} {
  transform.named_sequence @__transform_main(%arg1 : !transform.any_op {transform.readonly}) {
    %matmul = transform.structured.match ops{["linalg.generic"]} in %arg1
      : (!transform.any_op) -> !transform.any_op
    %a, %b = transform.structured.fuse %matmul [0, 1, 0]
      : (!transform.any_op) -> (!transform.any_op, !transform.any_op)
    transform.yield
  }
}

// CHECK-LABEL: func @imperfect_unpack_producer_fusion
//  CHECK-SAME:     %[[ARG0:.+]]: tensor<1x1x288x8x4xf32>
//  CHECK-SAME:     %[[ARG1:.+]]: tensor<1x2x1152xf32>
//       CHECK:   %[[FOR_RESULT:.+]] = scf.for{{.*}}iter_args(%[[ITER_ARG:.+]] = {{.*}})
//       CHECK:     %[[SLICE:.+]] = tensor.extract_slice %[[ARG0]]
//       CHECK:     %[[UNPACK:.+]] = tensor.unpack %[[SLICE]]
//   CHECK-DAG:     %[[UNPACK_SLICE:.+]] = tensor.extract_slice %[[UNPACK]]
//   CHECK-DAG:     %[[INIT_SLICE:.+]] = tensor.extract_slice %[[ITER_ARG]]
//       CHECK:     %[[GENERIC:.+]] = linalg.generic
//  CHECK-SAME:         ins(%[[UNPACK_SLICE]]
//  CHECK-SAME:         outs(%[[INIT_SLICE]]
//       CHECK:     %[[INSERT_SLICE:.+]] = tensor.insert_slice %[[GENERIC]] into %[[ITER_ARG]]
//       CHECK:     scf.yield %[[INSERT_SLICE]]
//       CHECK:   return %[[FOR_RESULT]]
