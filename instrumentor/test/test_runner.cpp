// test_runner.cpp - Standalone tool to test our pass directly
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/PassManager.h"
#include "llvm/IRReader/IRReader.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Support/SourceMgr.h"
#include "llvm/Support/raw_ostream.h"

// Our pass definition (copied here for testing)
#include "llvm/IR/PassManager.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;

namespace {
struct HelloPass : public PassInfoMixin<HelloPass> {
  PreservedAnalyses run(Function &F, FunctionAnalysisManager &) {
    errs() << "[HelloPass] Function: " << F.getName() << "\n";
    return PreservedAnalyses::all();
  }
};
}

int main(int argc, char **argv) {
  if (argc < 2) {
    errs() << "Usage: " << argv[0] << " <IR file>\n";
    return 1;
  }

  LLVMContext Context;
  SMDiagnostic Err;

  // Parse the input IR file
  std::unique_ptr<Module> M = parseIRFile(argv[1], Err, Context);
  if (!M) {
    Err.print(argv[0], errs());
    return 1;
  }

  // Set up the analysis managers
  LoopAnalysisManager LAM;
  FunctionAnalysisManager FAM;
  CGSCCAnalysisManager CGAM;
  ModuleAnalysisManager MAM;

  PassBuilder PB;
  PB.registerModuleAnalyses(MAM);
  PB.registerCGSCCAnalyses(CGAM);
  PB.registerFunctionAnalyses(FAM);
  PB.registerLoopAnalyses(LAM);
  PB.crossRegisterProxies(LAM, FAM, CGAM, MAM);

  // Create a function pass manager with our pass
  FunctionPassManager FPM;
  FPM.addPass(HelloPass());

  // Run the pass on each function
  errs() << "Running HelloPass on module: " << M->getName() << "\n";
  for (Function &F : *M) {
    if (!F.isDeclaration()) {
      FPM.run(F, FAM);
    }
  }

  return 0;
}
