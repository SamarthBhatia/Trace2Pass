// HelloPass.cpp - Simple test pass to verify LLVM environment
// This pass prints the name of every function it encounters
// Uses LLVM 21's new pass manager

#include "llvm/IR/PassManager.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Passes/PassPlugin.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;

namespace {

// New PM function pass
struct HelloPass : public PassInfoMixin<HelloPass> {
  PreservedAnalyses run(Function &F, FunctionAnalysisManager &) {
    errs() << "Hello from LLVM Pass: ";
    errs() << F.getName() << "\n";
    return PreservedAnalyses::all(); // We didn't modify anything
  }
};

} // anonymous namespace

// Register the pass with the new pass manager
extern "C" LLVM_ATTRIBUTE_WEAK ::llvm::PassPluginLibraryInfo
llvmGetPassPluginInfo() {
  return {
    LLVM_PLUGIN_API_VERSION, "HelloPass", "v0.1",
    [](PassBuilder &PB) {
      PB.registerPipelineParsingCallback(
        [](StringRef Name, FunctionPassManager &FPM,
           ArrayRef<PassBuilder::PipelineElement>) {
          if (Name == "hello") {
            FPM.addPass(HelloPass());
            return true;
          }
          return false;
        }
      );
    }
  };
}
