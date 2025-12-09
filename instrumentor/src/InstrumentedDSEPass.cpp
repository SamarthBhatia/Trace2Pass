//===- InstrumentedDSEPass.cpp - Instrumented DSE Pass -------------------===//
//
// Trace2Pass - Test instrumentation on DSE (Dead Store Elimination)
//
//===----------------------------------------------------------------------===//

#include "Trace2Pass/PassInstrumentor.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/PassManager.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Passes/PassPlugin.h"
#include "llvm/Transforms/Scalar/DeadStoreElimination.h"

using namespace llvm;
using namespace trace2pass;

namespace {

/// Wrapper that instruments DSE pass
struct InstrumentedDSEPass : public PassInfoMixin<InstrumentedDSEPass> {

  PreservedAnalyses run(Function &F, FunctionAnalysisManager &FAM) {
    // Skip declarations
    if (F.isDeclaration())
      return PreservedAnalyses::all();

    // Capture IR before DSE
    IRSnapshot Before(F);

    // Run DSE
    DSEPass DSE;
    PreservedAnalyses PA = DSE.run(F, FAM);

    // Capture IR after DSE
    IRSnapshot After(F);

    // Compare and report only if changes detected
    IRDiffer::DiffResult Diff = IRDiffer::compare(Before, After);

    if (Diff.HasChanges) {
      errs() << "[Trace2Pass] " << F.getName() << ": " << Diff.ChangeDescription;
      if (Diff.IsSuspicious) {
        errs() << " ⚠️  SUSPICIOUS";
      }
      errs() << "\n";
    }

    return PA;
  }
};

} // anonymous namespace

//-----------------------------------------------------------------------------
// New PM Registration
//-----------------------------------------------------------------------------
llvm::PassPluginLibraryInfo getInstrumentedDSEPluginInfo() {
  return {LLVM_PLUGIN_API_VERSION, "InstrumentedDSE", LLVM_VERSION_STRING,
          [](PassBuilder &PB) {
            PB.registerPipelineParsingCallback(
                [](StringRef Name, FunctionPassManager &FPM,
                   ArrayRef<PassBuilder::PipelineElement>) {
                  if (Name == "instrumented-dse") {
                    FPM.addPass(InstrumentedDSEPass());
                    return true;
                  }
                  return false;
                });
          }};
}

extern "C" LLVM_ATTRIBUTE_WEAK ::llvm::PassPluginLibraryInfo
llvmGetPassPluginInfo() {
  return getInstrumentedDSEPluginInfo();
}
