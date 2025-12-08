//===- PassInstrumentor.h - Wrapper for LLVM passes instrumentation ------===//
//
// Trace2Pass - Compiler Bug Detection via Pass-Level Instrumentation
//
//===----------------------------------------------------------------------===//
//
// This file defines the PassInstrumentor class which wraps LLVM optimization
// passes to detect potential compiler bugs by comparing IR before and after
// pass execution.
//
//===----------------------------------------------------------------------===//

#ifndef TRACE2PASS_PASS_INSTRUMENTOR_H
#define TRACE2PASS_PASS_INSTRUMENTOR_H

#include "llvm/IR/Function.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/PassManager.h"
#include "llvm/Support/raw_ostream.h"
#include <memory>
#include <string>

namespace trace2pass {

/// IRSnapshot - Captures the state of IR for comparison
class IRSnapshot {
public:
  explicit IRSnapshot(llvm::Function &F);

  /// Compute a hash of the IR state
  uint64_t getHash() const { return Hash; }

  /// Get instruction count
  size_t getInstructionCount() const { return InstructionCount; }

  /// Get basic block count
  size_t getBasicBlockCount() const { return BasicBlockCount; }

  /// Get the captured IR as string (for detailed comparison)
  std::string getIRString() const { return IRString; }

private:
  uint64_t Hash;
  size_t InstructionCount;
  size_t BasicBlockCount;
  std::string IRString;

  uint64_t computeHash(llvm::Function &F);
};

/// IRDiffer - Compares two IR snapshots and identifies changes
class IRDiffer {
public:
  struct DiffResult {
    bool HasChanges = false;
    bool IsSuspicious = false;
    int InstructionsDelta = 0;
    int BasicBlocksDelta = 0;
    std::string ChangeDescription;
    std::string SuspiciousReason;
  };

  /// Compare two IR snapshots
  static DiffResult compare(const IRSnapshot &Before, const IRSnapshot &After);

private:
  /// Check if changes look suspicious (potential bug indicators)
  static bool isSuspicious(const DiffResult &Diff);
};

/// TransformationLogger - Logs pass transformations for analysis
class TransformationLogger {
public:
  static TransformationLogger &getInstance();

  /// Log a transformation
  void logTransformation(const std::string &PassName,
                         const std::string &FunctionName,
                         const IRSnapshot &Before,
                         const IRSnapshot &After,
                         const IRDiffer::DiffResult &Diff);

  /// Enable/disable logging
  void setEnabled(bool Enable) { Enabled = Enable; }

  /// Set output stream
  void setOutputStream(llvm::raw_ostream &OS) { OutputStream = &OS; }

private:
  TransformationLogger() = default;
  bool Enabled = true;
  llvm::raw_ostream *OutputStream = &llvm::errs();
};

/// PassInstrumentor - Main class that wraps passes for instrumentation
///
/// Usage:
///   PassInstrumentor::instrument<SomePass>(FPM, "SomePass");
///
class PassInstrumentor {
public:
  /// Instrument a function pass
  template <typename PassT>
  static void instrumentFunction(llvm::FunctionPassManager &FPM,
                                 const std::string &PassName);

  /// Instrument a module pass
  template <typename PassT>
  static void instrumentModule(llvm::ModulePassManager &MPM,
                               const std::string &PassName);

private:
  /// Wrapper that captures before/after state for a function pass
  template <typename PassT>
  class FunctionPassWrapper : public llvm::PassInfoMixin<FunctionPassWrapper<PassT>> {
  public:
    explicit FunctionPassWrapper(const std::string &Name) : PassName(Name) {}

    llvm::PreservedAnalyses run(llvm::Function &F,
                                llvm::FunctionAnalysisManager &FAM);

  private:
    std::string PassName;
    PassT WrappedPass;
  };
};

} // namespace trace2pass

#endif // TRACE2PASS_PASS_INSTRUMENTOR_H
