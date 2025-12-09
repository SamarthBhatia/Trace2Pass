//===- InstrumentedInstCombinePass.cpp - Instrumented InstCombine --------===//
//
// Trace2Pass - Test instrumentation on InstCombine
//
//===----------------------------------------------------------------------===//

#include "Trace2Pass/PassInstrumentor.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/PassManager.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Passes/PassPlugin.h"
#include "llvm/Transforms/InstCombine/InstCombine.h"

using namespace llvm;
using namespace trace2pass;

namespace {

/// Wrapper that instruments InstCombine pass
struct InstrumentedInstCombinePass : public PassInfoMixin<InstrumentedInstCombinePass> {

  PreservedAnalyses run(Function &F, FunctionAnalysisManager &FAM) {
    // Skip declarations
    if (F.isDeclaration())
      return PreservedAnalyses::all();

    errs() << "[Trace2Pass] Processing function: " << F.getName() << "\n";

    // Capture IR before InstCombine
    IRSnapshot Before(F);
    errs() << "  Before: " << Before.getInstructionCount() << " instructions, "
           << Before.getBasicBlockCount() << " BBs, "
           << "hash=" << Before.getHash() << "\n";

    // Run InstCombine
    InstCombinePass InstCombine;
    PreservedAnalyses PA = InstCombine.run(F, FAM);

    // Capture IR after InstCombine
    IRSnapshot After(F);
    errs() << "  After:  " << After.getInstructionCount() << " instructions, "
           << After.getBasicBlockCount() << " BBs, "
           << "hash=" << After.getHash() << "\n";

    // Compare and report
    IRDiffer::DiffResult Diff = IRDiffer::compare(Before, After);

    if (Diff.HasChanges) {
      errs() << "  ✅ Changes detected: " << Diff.ChangeDescription << "\n";

      if (Diff.IsSuspicious) {
        errs() << "  ⚠️  SUSPICIOUS transformation detected!\n";
      }
    } else {
      errs() << "  No changes\n";
    }
    errs() << "\n";

    return PA;
  }
};

} // anonymous namespace

//-----------------------------------------------------------------------------
// New PM Registration
//-----------------------------------------------------------------------------
llvm::PassPluginLibraryInfo getInstrumentedInstCombinePluginInfo() {
  return {LLVM_PLUGIN_API_VERSION, "InstrumentedInstCombine", LLVM_VERSION_STRING,
          [](PassBuilder &PB) {
            PB.registerPipelineParsingCallback(
                [](StringRef Name, FunctionPassManager &FPM,
                   ArrayRef<PassBuilder::PipelineElement>) {
                  if (Name == "instrumented-instcombine") {
                    FPM.addPass(InstrumentedInstCombinePass());
                    return true;
                  }
                  return false;
                });
          }};
}

extern "C" LLVM_ATTRIBUTE_WEAK ::llvm::PassPluginLibraryInfo
llvmGetPassPluginInfo() {
  return getInstrumentedInstCombinePluginInfo();
}
