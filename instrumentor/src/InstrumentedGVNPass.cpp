//===- InstrumentedGVNPass.cpp - Instrumented GVN Pass -------------------===//
//
// Trace2Pass - Test instrumentation on GVN
//
//===----------------------------------------------------------------------===//

#include "Trace2Pass/PassInstrumentor.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/PassManager.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Passes/PassPlugin.h"
#include "llvm/Transforms/Scalar/GVN.h"

using namespace llvm;
using namespace trace2pass;

namespace {

/// Wrapper that instruments GVN pass
struct InstrumentedGVNPass : public PassInfoMixin<InstrumentedGVNPass> {

  PreservedAnalyses run(Function &F, FunctionAnalysisManager &FAM) {
    // Skip declarations
    if (F.isDeclaration())
      return PreservedAnalyses::all();

    // Capture IR before GVN
    IRSnapshot Before(F);

    // Run GVN
    GVNPass GVN;
    PreservedAnalyses PA = GVN.run(F, FAM);

    // Capture IR after GVN
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
llvm::PassPluginLibraryInfo getInstrumentedGVNPluginInfo() {
  return {LLVM_PLUGIN_API_VERSION, "InstrumentedGVN", LLVM_VERSION_STRING,
          [](PassBuilder &PB) {
            PB.registerPipelineParsingCallback(
                [](StringRef Name, FunctionPassManager &FPM,
                   ArrayRef<PassBuilder::PipelineElement>) {
                  if (Name == "instrumented-gvn") {
                    FPM.addPass(InstrumentedGVNPass());
                    return true;
                  }
                  return false;
                });
          }};
}

extern "C" LLVM_ATTRIBUTE_WEAK ::llvm::PassPluginLibraryInfo
llvmGetPassPluginInfo() {
  return getInstrumentedGVNPluginInfo();
}
