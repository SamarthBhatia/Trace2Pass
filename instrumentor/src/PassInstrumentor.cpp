//===- PassInstrumentor.cpp - Pass instrumentation implementation --------===//
//
// Trace2Pass - Compiler Bug Detection via Pass-Level Instrumentation
//
//===----------------------------------------------------------------------===//

#include "Trace2Pass/PassInstrumentor.h"
#include "llvm/IR/Instructions.h"
#include "llvm/Support/raw_ostream.h"
#include <sstream>

using namespace llvm;
using namespace trace2pass;

//===----------------------------------------------------------------------===//
// IRSnapshot Implementation
//===----------------------------------------------------------------------===//

IRSnapshot::IRSnapshot(Function &F)
    : Hash(0), InstructionCount(0), BasicBlockCount(0) {
  // Count basic blocks
  BasicBlockCount = F.size();

  // Count instructions and build IR string
  std::string IR;
  raw_string_ostream OS(IR);

  for (BasicBlock &BB : F) {
    for (Instruction &I : BB) {
      InstructionCount++;
      I.print(OS);
      OS << "\n";
    }
  }

  IRString = OS.str();
  Hash = computeHash(F);
}

uint64_t IRSnapshot::computeHash(Function &F) {
  // Simple hash based on instruction count and BB count
  // TODO: More sophisticated hashing (consider opcode sequence, types, etc.)
  uint64_t hash = BasicBlockCount * 31 + InstructionCount * 17;

  // Hash instruction opcodes for better differentiation
  for (BasicBlock &BB : F) {
    for (Instruction &I : BB) {
      hash = hash * 37 + I.getOpcode();
    }
  }

  return hash;
}

//===----------------------------------------------------------------------===//
// IRDiffer Implementation
//===----------------------------------------------------------------------===//

IRDiffer::DiffResult IRDiffer::compare(const IRSnapshot &Before,
                                       const IRSnapshot &After) {
  DiffResult Result;

  // Check if hashes differ
  if (Before.getHash() == After.getHash()) {
    Result.HasChanges = false;
    return Result;
  }

  Result.HasChanges = true;

  // Calculate deltas
  Result.InstructionsDelta =
      static_cast<int>(After.getInstructionCount()) -
      static_cast<int>(Before.getInstructionCount());

  Result.BasicBlocksDelta =
      static_cast<int>(After.getBasicBlockCount()) -
      static_cast<int>(Before.getBasicBlockCount());

  // Build description
  std::ostringstream Desc;
  Desc << "Instructions: " << Before.getInstructionCount()
       << " -> " << After.getInstructionCount()
       << " (delta: " << Result.InstructionsDelta << "); ";
  Desc << "BasicBlocks: " << Before.getBasicBlockCount()
       << " -> " << After.getBasicBlockCount()
       << " (delta: " << Result.BasicBlocksDelta << ")";

  Result.ChangeDescription = Desc.str();

  // Check for suspicious patterns
  Result.IsSuspicious = isSuspicious(Result);

  return Result;
}

bool IRDiffer::isSuspicious(const DiffResult &Diff) {
  // Heuristics for suspicious changes
  // TODO: Refine these based on empirical data

  // Large instruction count increase (possible code bloat or redundancy)
  if (Diff.InstructionsDelta > 10) {
    return true;
  }

  // Basic block structure changed significantly
  if (std::abs(Diff.BasicBlocksDelta) > 3) {
    return true;
  }

  // Instructions disappeared (possible optimization bug)
  if (Diff.InstructionsDelta < -5) {
    return true;
  }

  return false;
}

//===----------------------------------------------------------------------===//
// TransformationLogger Implementation
//===----------------------------------------------------------------------===//

TransformationLogger &TransformationLogger::getInstance() {
  static TransformationLogger Instance;
  return Instance;
}

void TransformationLogger::logTransformation(
    const std::string &PassName,
    const std::string &FunctionName,
    const IRSnapshot &Before,
    const IRSnapshot &After,
    const IRDiffer::DiffResult &Diff) {

  if (!Enabled || !OutputStream)
    return;

  *OutputStream << "[Trace2Pass] Pass: " << PassName
                << " | Function: " << FunctionName << "\n";

  if (!Diff.HasChanges) {
    *OutputStream << "  No changes detected.\n";
    return;
  }

  *OutputStream << "  Changes: " << Diff.ChangeDescription << "\n";

  if (Diff.IsSuspicious) {
    *OutputStream << "  ⚠️  SUSPICIOUS: Potential bug indicator!\n";
    if (!Diff.SuspiciousReason.empty()) {
      *OutputStream << "  Reason: " << Diff.SuspiciousReason << "\n";
    }
  }

  *OutputStream << "  Hash: " << Before.getHash()
                << " -> " << After.getHash() << "\n";
  *OutputStream << "\n";
}

//===----------------------------------------------------------------------===//
// PassInstrumentor::FunctionPassWrapper Implementation
//===----------------------------------------------------------------------===//

template <typename PassT>
PreservedAnalyses
PassInstrumentor::FunctionPassWrapper<PassT>::run(
    Function &F, FunctionAnalysisManager &FAM) {

  // Skip declarations (no body to instrument)
  if (F.isDeclaration())
    return PreservedAnalyses::all();

  // Capture IR before pass execution
  IRSnapshot Before(F);

  // Run the actual pass
  PreservedAnalyses PA = WrappedPass.run(F, FAM);

  // Capture IR after pass execution
  IRSnapshot After(F);

  // Compare and log
  IRDiffer::DiffResult Diff = IRDiffer::compare(Before, After);

  TransformationLogger::getInstance().logTransformation(
      PassName, F.getName().str(), Before, After, Diff);

  return PA;
}

//===----------------------------------------------------------------------===//
// Explicit Template Instantiations
//===----------------------------------------------------------------------===//

// We'll add instantiations for specific passes as needed
// For now, this serves as a framework

namespace trace2pass {

// Helper function to add instrumented pass
template <typename PassT>
void PassInstrumentor::instrumentFunction(FunctionPassManager &FPM,
                                          const std::string &PassName) {
  FPM.addPass(FunctionPassWrapper<PassT>(PassName));
}

} // namespace trace2pass
