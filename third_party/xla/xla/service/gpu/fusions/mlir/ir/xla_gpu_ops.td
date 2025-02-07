/* Copyright 2024 The OpenXLA Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
==============================================================================*/


#ifndef XLA_SERVICE_GPU_FUSIONS_MLIR_OPS
#define XLA_SERVICE_GPU_FUSIONS_MLIR_OPS

include "mlir/IR/AttrTypeBase.td"
include "mlir/IR/DialectBase.td"
include "mlir/IR/OpBase.td"
include "mlir/IR/SymbolInterfaces.td"
include "mlir/Interfaces/CallInterfaces.td"
include "mlir/Interfaces/InferTypeOpInterface.td"
include "mlir/Interfaces/SideEffectInterfaces.td"

def XlaGpuDialect : Dialect {
  let name = "xla_gpu";

  let description = [{
    This dialect contains ops required for lowering HLO to LLVM.
  }];

  let cppNamespace = "::xla::gpu";
}

class XLAGPU_Op<string mnemonic, list<Trait> traits = []> :
      Op<XlaGpuDialect, mnemonic, traits> {
}

def XLAGPU_AllocateSharedOp : XLAGPU_Op<"allocate_shared"> {
  let summary = "Allocates a shared memory tile.";

  let description = [{
    Allocates a shared memory tensor. The tensor is shared among all threads in
    a block.

    ```mlir
    %shared = xla_gpu.allocate_shared : tensor<32x32xf32>
    ```
  }];

  let results = (outs AnyStaticShapeTensor:$result);

  let assemblyFormat = "attr-dict `:` type($result)";
}

def XLAGPU_SyncThreadsOp : XLAGPU_Op<"sync_threads", [
   TypesMatchWith<"result type matches type of dest",
                   "operands", "results", "$_self">]> {
  let summary = "Synchronizes threads.";

  let description = [{
    Synchronizes threads, taking any number of distributed tensors and returning
    the synchronized state.
  }];

  let arguments = (ins Variadic<AnyRankedTensor>:$operands);
  let results = (outs Variadic<AnyRankedTensor>:$results);

  let assemblyFormat = "operands attr-dict `:` type($operands)";
}

def XLAGPU_AtomicRMWOp : XLAGPU_Op<"atomic_rmw",
    [Pure,
     TypesMatchWith<"result type matches type of dest",
                    "input", "result", "$_self">]> {
  let summary = "Atomically updates an element of a tensor.";

  let description = [{
    Reads an element from a tensor, computes the updated value for it, and
    writes back the result.
  }];

  let arguments = (ins AnyRankedTensor:$input, Variadic<Index>:$indices);
  let results = (outs AnyRankedTensor:$result);
  // The region takes the current value in the tensor as an argument and yields
  // the updated value.
  let regions = (region SizedRegion<1>:$computation);

  let assemblyFormat = [{
    $input `[` $indices `]` `:` type($input) $computation attr-dict
  }];
}

def XLAGPU_YieldOp : XLAGPU_Op<"yield",
    [HasParent<"::xla::gpu::AtomicRMWOp">, Terminator]> {
  let summary = "Terminator for atomic_rmw ops.";
  let arguments = (ins AnyType:$result);

  let assemblyFormat = "$result attr-dict `:` type($result)";
}

def XLAGPU_PureCallOp : XLAGPU_Op<"pure_call",
    [Pure, CallOpInterface, DeclareOpInterfaceMethods<SymbolUserOpInterface>]> {
  let summary = "Function call without side effects.";
  let arguments = (ins FlatSymbolRefAttr:$callee, Variadic<AnyType>:$operands);
  let results = (outs Variadic<AnyType>);
  let builders = [
    OpBuilder<(ins "mlir::func::FuncOp":$callee, CArg<"mlir::ValueRange", "{}">:$operands), [{
      $_state.addOperands(operands);
      $_state.addAttribute("callee", mlir::SymbolRefAttr::get(callee));
      $_state.addTypes(callee.getFunctionType().getResults());
    }]>];
  let assemblyFormat = [{
    $callee `(` $operands `)` attr-dict `:` functional-type($operands, results)
  }];

  let extraClassDeclaration = [{
    operand_range getArgOperands() {
      return getOperands();
    }

    mlir::MutableOperandRange getArgOperandsMutable() {
      return getOperandsMutable();
    }

    mlir::CallInterfaceCallable getCallableForCallee() {
      return (*this)->getAttrOfType<mlir::SymbolRefAttr>("callee");
    }

    void setCalleeFromCallable(mlir::CallInterfaceCallable callee) {
      (*this)->setAttr("callee", callee.get<mlir::SymbolRefAttr>());
    }
  }];
}

#endif // MLIR_HLO_DIALECT_MHLO_IR_HLO_OPS
