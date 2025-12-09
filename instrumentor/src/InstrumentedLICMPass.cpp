//===- InstrumentedLICMPass.cpp - Instrumented LICM Pass -----------------===//
//
// Trace2Pass - Test instrumentation on LICM (Loop Invariant Code Motion)
//
//===----------------------------------------------------------------------===//

#include "Trace2Pass/PassInstrumentor.h"
#include "llvm/Analysis/LoopAnalysisManager.h"
#include "llvm/Analysis/MemorySSA.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/PassManager.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Passes/PassPlugin.h"
#include "llvm/Transforms/Scalar/LICM.h"
#include "llvm/Transforms/Scalar/LoopPassManager.h"

using namespace llvm;
using namespace trace2pass;

namespace {

/// Wrapper that instruments LICM pass
/// LICM is a loop pass, but we wrap it as a function pass for consistency
struct InstrumentedLICMPass : public PassInfoMixin<InstrumentedLICMPass> {

  PreservedAnalyses run(Function &F, FunctionAnalysisManager &FAM) {
    // Skip declarations
    if (F.isDeclaration())
      return PreservedAnalyses::all();

    // Capture IR before LICM
    IRSnapshot Before(F);

    // Build a loop pass manager with LICM and MemorySSA support
    LoopPassManager LPM;
    LPM.addPass(LICMPass(LICMOptions()));

    // Use the MemorySSA-aware adaptor for loop passes
    // This ensures MemorySSA analysis is available to LICM
    PreservedAnalyses PA = createFunctionToLoopPassAdaptor(
        std::move(LPM),
        /*UseMemorySSA=*/true,
        /*UseBlockFrequencyInfo=*/false
    ).run(F, FAM);

    // Capture IR after LICM
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
llvm::PassPluginLibraryInfo getInstrumentedLICMPluginInfo() {
  return {LLVM_PLUGIN_API_VERSION, "InstrumentedLICM", LLVM_VERSION_STRING,
          [](PassBuilder &PB) {
            PB.registerPipelineParsingCallback(
                [](StringRef Name, FunctionPassManager &FPM,
                   ArrayRef<PassBuilder::PipelineElement>) {
                  if (Name == "instrumented-licm") {
                    FPM.addPass(InstrumentedLICMPass());
                    return true;
                  }
                  return false;
                });
          }};
}

extern "C" LLVM_ATTRIBUTE_WEAK ::llvm::PassPluginLibraryInfo
llvmGetPassPluginInfo() {
  return getInstrumentedLICMPluginInfo();
}
