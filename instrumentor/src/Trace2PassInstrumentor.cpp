#include "llvm/IR/PassManager.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Passes/PassPlugin.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/DataLayout.h"
#include "llvm/IR/DebugInfoMetadata.h"
#include "llvm/IR/Metadata.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Support/KnownBits.h"
#include "llvm/Transforms/Utils/ModuleUtils.h"
#include "llvm/Transforms/Utils/BasicBlockUtils.h"
#include "llvm/ADT/DenseMap.h"
#include "llvm/IR/Constants.h"
// ValueTracking + supporting analyses for compile-time sign-conversion filter.
// Used to skip instrumenting casts that are provably safe (constant operand,
// known non-negative, or value provably fits within the destination width).
#include "llvm/Analysis/ValueTracking.h"
#include "llvm/Analysis/AssumptionCache.h"
#include "llvm/Analysis/SimplifyQuery.h"
#include "llvm/IR/Dominators.h"
#include <cstdlib>  // for getenv
#include <cstring>  // for strcmp

// LLVM API compatibility: getOrInsertDeclaration was added in LLVM 20,
// replacing the older getDeclaration
#if LLVM_VERSION_MAJOR < 20
#define getOrInsertDeclaration getDeclaration
#endif

using namespace llvm;

namespace {

class Trace2PassInstrumentorPass : public PassInfoMixin<Trace2PassInstrumentorPass> {
public:
  PreservedAnalyses run(Function &F, FunctionAnalysisManager &FAM);

private:
  // Instrumentation helper functions
  bool instrumentArithmeticOperations(Function &F);
  bool instrumentUnreachableCode(Function &F);
  bool instrumentMemoryAccess(Function &F);
  bool instrumentSignConversions(Function &F, AssumptionCache *AC = nullptr,
                                 DominatorTree *DT = nullptr);
  bool instrumentDivisionByZero(Function &F);
  bool instrumentPureFunctionCalls(Function &F);
  bool instrumentLoopBounds(Function &F);
  bool instrumentSelectConsistency(Function &F);
  bool instrumentRangeChecks(Function &F);
  bool instrumentStoreLoadConsistency(Function &F);
  bool instrumentVolatileConsistency(Function &F);
  bool instrumentCrossBBConsistency(Function &F);
  bool instrumentReturnChecksums(Function &F);
  bool insertOverflowCheck(IRBuilder<> &Builder, Instruction *I,
                           Value *LHS, Value *RHS);
  void insertShiftCheck(IRBuilder<> &Builder, Instruction *I,
                        Value *ShiftValue, Value *ShiftAmount);
  void insertBoundsCheck(IRBuilder<> &Builder, GetElementPtrInst *GEP);

  // Debug info extraction helper
  struct LocationInfo {
    Value *File;
    Value *Line;
    Value *Function;
  };
  LocationInfo extractLocation(IRBuilder<> &Builder, Instruction *I);

  // Build metadata injection
  void injectBuildMetadata(Module &M);

  // Runtime function declarations
  FunctionCallee getOverflowReportFunc(Module &M);
  FunctionCallee getUnreachableReportFunc(Module &M);
  FunctionCallee getBoundsViolationReportFunc(Module &M);
  FunctionCallee getSignConversionReportFunc(Module &M);
  FunctionCallee getDivisionByZeroReportFunc(Module &M);
  FunctionCallee getPureConsistencyReportFunc(Module &M);
  FunctionCallee getLoopBoundReportFunc(Module &M);
  FunctionCallee getSelectInconsistencyReportFunc(Module &M);
  FunctionCallee getRangeViolationReportFunc(Module &M);
  FunctionCallee getStoreLoadInconsistencyReportFunc(Module &M);
  FunctionCallee getShadowStoreFunc(Module &M);
  FunctionCallee getShadowCheckFunc(Module &M);
  FunctionCallee getOpaqueReadFunc(Module &M);
  FunctionCallee getValuePropagationReportFunc(Module &M);
  FunctionCallee getCrossBBCheckFunc(Module &M);
  FunctionCallee getShouldSampleFunc(Module &M);
  // Per-check sampling getters. Each returns a runtime function whose
  // sampling rate can be tuned independently of the global rate via
  // TRACE2PASS_SAMPLE_RATE_<CHECK> env vars. Used to keep the heavy
  // checks (cross_bb, sign_conversion, store_load, gep_bounds) cheap
  // even at production sampling rates.
  FunctionCallee getShouldSampleCrossBBFunc(Module &M);
  FunctionCallee getShouldSampleSignConversionFunc(Module &M);
  FunctionCallee getShouldSampleStoreLoadFunc(Module &M);
  FunctionCallee getShouldSampleGEPBoundsFunc(Module &M);
  FunctionCallee getAccumulateChecksumFunc(Module &M);

  // Cross-BB consistency helpers
  AllocaInst *findRootAlloca(Value *V);
  bool isAddressTaken(AllocaInst *AI);
  bool hasSetjmp(Function &F);

  // Statistics
  unsigned NumInstrumented = 0;
  unsigned NumUnreachableInstrumented = 0;
  unsigned NumGEPInstrumented = 0;
  unsigned NumSignConversionInstrumented = 0;
  unsigned NumDivisionByZeroInstrumented = 0;
  unsigned NumPureCallsInstrumented = 0;
  unsigned NumLoopsInstrumented = 0;
  unsigned NumSelectInstrumented = 0;
  unsigned NumRangeInstrumented = 0;
  unsigned NumStoreLoadInstrumented = 0;
  unsigned NumVolatileInstrumented = 0;
  unsigned NumCrossBBInstrumented = 0;
  unsigned NumReturnChecksumInstrumented = 0;
};

PreservedAnalyses Trace2PassInstrumentorPass::run(Function &F,
                                                    FunctionAnalysisManager &FAM) {
  // Skip declarations (no body)
  if (F.isDeclaration())
    return PreservedAnalyses::all();

  // Skip runtime library functions to avoid recursive instrumentation
  if (F.getName().starts_with("trace2pass_"))
    return PreservedAnalyses::all();

  // Inject build metadata (once per module)
  Module &M = *F.getParent();
  injectBuildMetadata(M);

  errs() << "Trace2Pass: Instrumenting function: " << F.getName() << "\n";

  // Reset counters for this function to avoid accumulation across functions
  NumInstrumented = 0;
  NumUnreachableInstrumented = 0;
  NumGEPInstrumented = 0;
  NumSignConversionInstrumented = 0;
  NumDivisionByZeroInstrumented = 0;
  NumPureCallsInstrumented = 0;
  NumLoopsInstrumented = 0;
  NumSelectInstrumented = 0;
  NumRangeInstrumented = 0;
  NumStoreLoadInstrumented = 0;
  NumVolatileInstrumented = 0;
  NumCrossBBInstrumented = 0;
  NumReturnChecksumInstrumented = 0;

  bool Modified = false;

  // Configuration: Per-check toggles for fine-grained control
  //
  // Always-on checks (production mode, ~4% overhead):
  //   Arithmetic overflow, unreachable code, division-by-zero, pure functions, shift
  //
  // Optional checks (disabled by default due to higher overhead):
  //   TRACE2PASS_ENABLE_GEP_BOUNDS=1       GEP bounds checking (~18% overhead)
  //   TRACE2PASS_ENABLE_SIGN_CONVERSION=1  Sign conversion detection (~280% overhead)
  //   TRACE2PASS_ENABLE_LOOP_BOUNDS=1      Loop iteration bounds (~12.7% overhead)
  //   TRACE2PASS_ENABLE_ALL_CHECKS=1       Enable ALL checks (overrides above)
  //
  auto envIsSet = [](const char *name) -> bool {
    const char *val = getenv(name);
    return val && strcmp(val, "1") == 0;
  };

  bool all_checks   = envIsSet("TRACE2PASS_ENABLE_ALL_CHECKS");
  bool enable_gep   = all_checks || envIsSet("TRACE2PASS_ENABLE_GEP_BOUNDS");
  bool enable_sign  = all_checks || envIsSet("TRACE2PASS_ENABLE_SIGN_CONVERSION");
  bool enable_loop  = all_checks || envIsSet("TRACE2PASS_ENABLE_LOOP_BOUNDS");
  bool enable_select    = all_checks || envIsSet("TRACE2PASS_ENABLE_SELECT_CHECK");
  bool enable_range     = all_checks || envIsSet("TRACE2PASS_ENABLE_RANGE_CHECK");
  bool enable_storeload = all_checks || envIsSet("TRACE2PASS_ENABLE_STORE_LOAD_CHECK");
  bool enable_volatile  = all_checks || envIsSet("TRACE2PASS_ENABLE_VOLATILE_TRACKING");
  bool enable_crossbb   = all_checks || envIsSet("TRACE2PASS_ENABLE_CROSS_BB_CHECK");
  bool enable_backend_checksum = all_checks || envIsSet("TRACE2PASS_ENABLE_BACKEND_CHECKSUM");

  // Always-on checks (production)
  Modified |= instrumentArithmeticOperations(F);
  Modified |= instrumentUnreachableCode(F);
  Modified |= instrumentDivisionByZero(F);
  Modified |= instrumentPureFunctionCalls(F);

  // Optional checks (individually toggleable)
  if (enable_gep)   Modified |= instrumentMemoryAccess(F);
  if (enable_sign) {
    // Fetch the analyses needed by computeKnownBits / isKnownNonNegative.
    // These let the sign-conversion pass skip casts that are provably safe at
    // compile time (constant operand, known non-negative, value fits) and
    // dramatically reduces the number of runtime check sites.
    AssumptionCache &AC = FAM.getResult<AssumptionAnalysis>(F);
    DominatorTree &DT = FAM.getResult<DominatorTreeAnalysis>(F);
    Modified |= instrumentSignConversions(F, &AC, &DT);
  }
  if (enable_loop)      Modified |= instrumentLoopBounds(F);
  if (enable_select)    Modified |= instrumentSelectConsistency(F);
  if (enable_range)     Modified |= instrumentRangeChecks(F);
  if (enable_storeload) Modified |= instrumentStoreLoadConsistency(F);
  if (enable_volatile)  Modified |= instrumentVolatileConsistency(F);
  if (enable_crossbb)   Modified |= instrumentCrossBBConsistency(F);
  if (enable_backend_checksum) Modified |= instrumentReturnChecksums(F);

  if (Modified) {
    errs() << "Trace2Pass: Instrumented " << NumInstrumented
           << " arithmetic operations";
    if (NumUnreachableInstrumented > 0) {
      errs() << ", " << NumUnreachableInstrumented << " unreachable blocks";
    }
    if (NumGEPInstrumented > 0) {
      errs() << ", " << NumGEPInstrumented << " GEP instructions";
    }
    if (NumSignConversionInstrumented > 0) {
      errs() << ", " << NumSignConversionInstrumented << " sign conversions";
    }
    if (NumDivisionByZeroInstrumented > 0) {
      errs() << ", " << NumDivisionByZeroInstrumented << " division checks";
    }
    if (NumPureCallsInstrumented > 0) {
      errs() << ", " << NumPureCallsInstrumented << " pure function calls";
    }
    if (NumLoopsInstrumented > 0) {
      errs() << ", " << NumLoopsInstrumented << " loops";
    }
    if (NumSelectInstrumented > 0) {
      errs() << ", " << NumSelectInstrumented << " select checks";
    }
    if (NumRangeInstrumented > 0) {
      errs() << ", " << NumRangeInstrumented << " range checks";
    }
    if (NumStoreLoadInstrumented > 0) {
      errs() << ", " << NumStoreLoadInstrumented << " store-load checks";
    }
    if (NumVolatileInstrumented > 0) {
      errs() << ", " << NumVolatileInstrumented << " volatile tracking checks";
    }
    if (NumCrossBBInstrumented > 0) {
      errs() << ", " << NumCrossBBInstrumented << " cross-BB consistency checks";
    }
    if (NumReturnChecksumInstrumented > 0) {
      errs() << ", " << NumReturnChecksumInstrumented << " return checksums";
    }
    errs() << " in " << F.getName() << "\n";

    // We modified the function, so we need to invalidate analyses
    return PreservedAnalyses::none();
  }

  return PreservedAnalyses::all();
}

// Extract source location from debug metadata
// Returns file, line, function as LLVM Values for passing to runtime
Trace2PassInstrumentorPass::LocationInfo
Trace2PassInstrumentorPass::extractLocation(IRBuilder<> &Builder, Instruction *I) {
  LocationInfo Loc;
  Module &M = *I->getModule();
  LLVMContext &Ctx = M.getContext();

  // Try to get debug location
  const DebugLoc &DL = I->getDebugLoc();

  if (DL) {
    // Extract full file path (directory + filename)
    // CRITICAL: DILocation stores directory and filename separately
    // Must combine them to avoid conflating files with same basename (e.g., config.c)
    StringRef Directory = DL->getDirectory();
    StringRef Filename = DL->getFilename();
    std::string FullPath;

    if (!Directory.empty() && !Filename.empty()) {
      // Combine directory and filename with path separator
      FullPath = Directory.str() + "/" + Filename.str();
    } else if (!Filename.empty()) {
      // No directory info, use filename alone
      FullPath = Filename.str();
    } else {
      // No filename at all
      FullPath = "unknown";
    }

    Loc.File = Builder.CreateGlobalString(FullPath);

    // Extract line number
    unsigned Line = DL.getLine();
    Loc.Line = ConstantInt::get(Type::getInt32Ty(Ctx), Line);

    // Extract function name from the enclosing function
    Function *F = I->getFunction();
    StringRef FuncName = F ? F->getName() : "unknown";
    Loc.Function = Builder.CreateGlobalString(FuncName);
  } else {
    // No debug info available - use placeholders
    Loc.File = Builder.CreateGlobalString("unknown");
    Loc.Line = ConstantInt::get(Type::getInt32Ty(Ctx), 0);

    // Still try to get function name even without debug info
    Function *F = I->getFunction();
    StringRef FuncName = F ? F->getName() : "unknown";
    Loc.Function = Builder.CreateGlobalString(FuncName);
  }

  return Loc;
}

// Inject build metadata as global variables for runtime consumption
// This allows the runtime to report actual optimization level and flags instead of "unknown"
void Trace2PassInstrumentorPass::injectBuildMetadata(Module &M) {
  LLVMContext &Ctx = M.getContext();

  // Check if already injected (avoid duplicates across multiple functions)
  if (M.getGlobalVariable("__trace2pass_opt_level")) {
    return;  // Already injected
  }

  std::string opt_level = "unknown";
  std::string flags = "";

  // Extract actual compilation flags from debug info (DICompileUnit)
  // The producer string contains compiler version and flags used
  if (NamedMDNode *CU_Nodes = M.getNamedMetadata("llvm.dbg.cu")) {
    for (unsigned i = 0, e = CU_Nodes->getNumOperands(); i != e; ++i) {
      if (DICompileUnit *CU = dyn_cast<DICompileUnit>(CU_Nodes->getOperand(i))) {
        // Producer string typically: "clang version X.Y.Z (flags)"
        StringRef Producer = CU->getProducer();
        if (!Producer.empty()) {
          flags = Producer.str();

          // Try to extract optimization level from flags
          // Look for -O0, -O1, -O2, -O3, -Os, -Oz in the producer string
          if (Producer.contains("-O3")) opt_level = "-O3";
          else if (Producer.contains("-O2")) opt_level = "-O2";
          else if (Producer.contains("-O1")) opt_level = "-O1";
          else if (Producer.contains("-Os")) opt_level = "-Os";
          else if (Producer.contains("-Oz")) opt_level = "-Oz";
          else if (Producer.contains("-O0")) opt_level = "-O0";
          else if (Producer.contains("-O")) opt_level = "-O?";
        }
        break;  // Only need first compile unit
      }
    }
  }

  // Fallback: Try to infer optimization level from module characteristics
  if (opt_level == "unknown") {
    // Check module flags for optimization hints
    if (M.getModuleFlag("OptLevel")) {
      if (auto *OptLevelMD = dyn_cast<ConstantAsMetadata>(M.getModuleFlag("OptLevel"))) {
        if (auto *OptLevelInt = dyn_cast<ConstantInt>(OptLevelMD->getValue())) {
          uint64_t Level = OptLevelInt->getZExtValue();
          opt_level = "-O" + std::to_string(Level);
        }
      }
    } else {
      // Heuristic: Check if functions have optnone attribute (indicates -O0)
      bool has_optnone = false;
      for (Function &F : M) {
        if (F.hasFnAttribute(Attribute::OptimizeNone)) {
          has_optnone = true;
          break;
        }
      }
      if (has_optnone) {
        opt_level = "-O0";
      }
    }
  }

  // Create global string constants (readable by runtime via extern)
  // CRITICAL: Use LinkOnceODRLinkage to avoid "multiple definition" linker errors
  // Each object file will emit these symbols, and the linker merges identical definitions
  IRBuilder<> Builder(Ctx);

  // Optimization level global
  Constant *OptLevelStr = ConstantDataArray::getString(Ctx, opt_level, true);
  GlobalVariable *OptLevelGlobal = new GlobalVariable(
      M,
      OptLevelStr->getType(),
      true,  // isConstant
      GlobalValue::LinkOnceODRLinkage,  // Allows multiple identical definitions
      OptLevelStr,
      "__trace2pass_opt_level"
  );
  OptLevelGlobal->setVisibility(GlobalValue::DefaultVisibility);

  // Compile flags global (producer string from debug info)
  Constant *FlagsStr = ConstantDataArray::getString(Ctx, flags, true);
  GlobalVariable *FlagsGlobal = new GlobalVariable(
      M,
      FlagsStr->getType(),
      true,  // isConstant
      GlobalValue::LinkOnceODRLinkage,  // Allows multiple identical definitions
      FlagsStr,
      "__trace2pass_compile_flags"
  );
  FlagsGlobal->setVisibility(GlobalValue::DefaultVisibility);

  errs() << "Trace2Pass: Injected build metadata: opt_level=" << opt_level
         << ", flags=" << (flags.empty() ? "(none)" : flags) << "\n";
}

bool Trace2PassInstrumentorPass::instrumentArithmeticOperations(Function &F) {
  bool Modified = false;
  Module &M = *F.getParent();

  // Collect instructions to instrument (to avoid iterator invalidation)
  SmallVector<Instruction *, 16> ToInstrument;

  for (BasicBlock &BB : F) {
    for (Instruction &I : BB) {
      // Look for arithmetic instructions that can overflow
      if (I.getType()->isIntegerTy()) {
        switch (I.getOpcode()) {
          case Instruction::Mul:
          case Instruction::Add:
          case Instruction::Sub:
          case Instruction::Shl:  // Left shift can overflow
          case Instruction::AShr: // Arithmetic right shift
          case Instruction::LShr: // Logical right shift
            ToInstrument.push_back(&I);
            break;
          default:
            break;
        }
      }
    }
  }

  // Instrument collected instructions
  for (Instruction *I : ToInstrument) {
    IRBuilder<> Builder(I);

    // Get operands
    Value *LHS = I->getOperand(0);
    Value *RHS = I->getOperand(1);

    // Insert overflow check (only counts if nsw/nuw flags present)
    if (insertOverflowCheck(Builder, I, LHS, RHS)) {
      Modified = true;
      NumInstrumented++;
    }
  }

  return Modified;
}

bool Trace2PassInstrumentorPass::insertOverflowCheck(IRBuilder<> &Builder,
                                                      Instruction *I,
                                                      Value *LHS, Value *RHS) {
  Module &M = *I->getModule();
  LLVMContext &Ctx = M.getContext();
  Type *IntTy = I->getType();

  // Handle shift operations separately (no intrinsic available)
  if (I->getOpcode() == Instruction::Shl ||
      I->getOpcode() == Instruction::AShr ||
      I->getOpcode() == Instruction::LShr) {
    insertShiftCheck(Builder, I, LHS, RHS);
    return true;  // Shift checks always instrument
  }

  // Determine if we should check signed or unsigned overflow
  // ONLY check when nsw/nuw flags are explicitly present
  //
  // CRITICAL: If neither flag is set, wrapping is LEGAL and we should NOT check!
  // This prevents false positives on operations like unsigned char arithmetic
  // where overflow/wrapping is intentional and correct.
  //
  // Flag semantics:
  //   nsw (no signed wrap): Optimizer assumes signed overflow won't happen
  //   nuw (no unsigned wrap): Optimizer assumes unsigned overflow won't happen
  //   No flags: Wrapping is allowed/expected - DON'T CHECK
  //
  // Example: `add i8 %x, 1` (no flags) on unsigned char is CORRECT
  //          `add nsw i8 %x, 1` would be WRONG for unsigned char
  bool checkSigned = false;
  bool checkUnsigned = false;

  if (auto *BinOp = dyn_cast<BinaryOperator>(I)) {
    // If instruction has nsw (no signed wrap) flag, check signed overflow
    // If instruction has nuw (no unsigned wrap) flag, check unsigned overflow
    checkSigned = BinOp->hasNoSignedWrap();
    checkUnsigned = BinOp->hasNoUnsignedWrap();
  }

  // If neither flag is set, don't check - wrapping is legal
  // (Previous buggy behavior: defaulted to signed, causing false positives)
  if (!checkSigned && !checkUnsigned) {
    // No overflow flags present - wrapping is legal, nothing to instrument
    return false;
  }

  // Lambda to emit a single overflow check for given signedness
  // When both nsw and nuw are present, this gets called twice
  Value *FinalResult = nullptr;
  auto emitSingleCheck = [&](bool isUnsigned) -> Value* {
    // Select the appropriate overflow intrinsic based on operation and signedness
    Intrinsic::ID IntrinsicID;
    const char *OpName;

    switch (I->getOpcode()) {
      case Instruction::Mul:
        IntrinsicID = isUnsigned ? Intrinsic::umul_with_overflow : Intrinsic::smul_with_overflow;
        OpName = isUnsigned ? "umul" : "smul";
        break;
      case Instruction::Add:
        IntrinsicID = isUnsigned ? Intrinsic::uadd_with_overflow : Intrinsic::sadd_with_overflow;
        OpName = isUnsigned ? "uadd" : "sadd";
        break;
      case Instruction::Sub:
        IntrinsicID = isUnsigned ? Intrinsic::usub_with_overflow : Intrinsic::ssub_with_overflow;
        OpName = isUnsigned ? "usub" : "ssub";
        break;
      default:
        return nullptr; // Shouldn't reach here
    }

    // Use LLVM's overflow intrinsic
    Function *OverflowIntrinsic = Intrinsic::getOrInsertDeclaration(
        &M, IntrinsicID, {IntTy});

    // Call the intrinsic
    CallInst *OverflowCall = Builder.CreateCall(OverflowIntrinsic, {LHS, RHS});

    // Extract result and overflow flag
    Value *Result = Builder.CreateExtractValue(OverflowCall, 0);
    Value *OverflowFlag = Builder.CreateExtractValue(OverflowCall, 1);

    // CRITICAL FIX: Use SplitBlockAndInsertIfThen instead of manual block splitting
    // This prevents LLVM -O2 crashes by properly handling CFG construction, PHI nodes,
    // and terminator management. Manual splicing was causing invalid IR that crashed
    // SimplifyCFG pass on large codebases like SQLite.
    Instruction *ThenTerm = SplitBlockAndInsertIfThen(OverflowFlag, I, false);

    Builder.SetInsertPoint(ThenTerm);

    // Call trace2pass_should_sample() to decide if we should report
    // Overflow can happen frequently in normal code (hash functions, checksums)
    FunctionCallee ShouldSampleFunc = getShouldSampleFunc(M);
    Value *ShouldSample = Builder.CreateCall(ShouldSampleFunc);
    Value *ShouldReport = Builder.CreateICmpNE(ShouldSample, Builder.getInt32(0), "should_report");

    // Create another split for the actual report
    Instruction *ReportTerm = SplitBlockAndInsertIfThen(ShouldReport, ThenTerm, false);

    Builder.SetInsertPoint(ReportTerm);

    // Get the runtime report function
    FunctionCallee ReportFunc = getOverflowReportFunc(M);

    // Get PC (return address)
    Function *ReturnAddrIntrinsic = Intrinsic::getOrInsertDeclaration(
        &M, Intrinsic::returnaddress);
    Value *PC = Builder.CreateCall(ReturnAddrIntrinsic,
                                    {Builder.getInt32(0)});

    // Extract source location from debug metadata
    LocationInfo Loc = extractLocation(Builder, I);

    // Create expression string based on operation
    std::string ExprStr = std::string("x ") + OpName + " y";
    Value *ExprGlobal = Builder.CreateGlobalString(ExprStr);

    // Convert operands to i64 for reporting
    Value *LHS_i64 = Builder.CreateSExtOrTrunc(LHS, Builder.getInt64Ty());
    Value *RHS_i64 = Builder.CreateSExtOrTrunc(RHS, Builder.getInt64Ty());

    // Call the report function with location metadata
    Builder.CreateCall(ReportFunc, {PC, Loc.File, Loc.Line, Loc.Function, ExprGlobal, LHS_i64, RHS_i64});

    // Reset builder to after the merge point for potential next check
    // The split created: OrigBlock -> ThenBlock -> SampleBlock -> ReportBlock -> MergeBlock
    // We want to insert the next check at the start of MergeBlock
    BasicBlock *MergeBlock = ReportTerm->getParent()->getSingleSuccessor();
    if (MergeBlock) {
      Builder.SetInsertPoint(&MergeBlock->front());
    }

    return Result;
  };

  // Emit signed overflow check if needed
  if (checkSigned) {
    FinalResult = emitSingleCheck(false);
  }

  // Emit unsigned overflow check if needed
  if (checkUnsigned) {
    Value *UnsignedResult = emitSingleCheck(true);
    // Use the unsigned result if we didn't emit a signed check
    if (!FinalResult) {
      FinalResult = UnsignedResult;
    }
    // Note: Both results should be identical at the bit level for add/sub/mul
  }

  // Replace uses of the original instruction with our computed result
  // and erase the dead instruction to keep the IR clean
  if (FinalResult) {
    I->replaceAllUsesWith(FinalResult);
    I->eraseFromParent();
  }

  return true;
}

void Trace2PassInstrumentorPass::insertShiftCheck(IRBuilder<> &Builder,
                                                    Instruction *I,
                                                    Value *ShiftValue, Value *ShiftAmount) {
  Module &M = *I->getModule();
  LLVMContext &Ctx = M.getContext();
  Type *IntTy = I->getType();

  // For shift operations, check if shift amount >= bit width
  unsigned BitWidth = IntTy->getIntegerBitWidth();
  Value *BitWidthConst = Builder.getInt32(BitWidth);

  // Convert shift amount to i32 for comparison
  Value *ShiftAmount_i32 = Builder.CreateZExtOrTrunc(ShiftAmount, Builder.getInt32Ty());

  // Check: shift_amount >= bit_width
  Value *IsInvalid = Builder.CreateICmpUGE(ShiftAmount_i32, BitWidthConst, "is_invalid_shift");

  // CRITICAL FIX: Use SplitBlockAndInsertIfThen instead of manual block splitting
  // This prevents LLVM -O2 crashes by properly handling CFG construction
  Instruction *ThenTerm = SplitBlockAndInsertIfThen(IsInvalid, I, false);

  Builder.SetInsertPoint(ThenTerm);

  // Call trace2pass_should_sample() to decide if we should report
  // Invalid shifts can happen frequently, use sampling to reduce overhead
  FunctionCallee ShouldSampleFunc = getShouldSampleFunc(M);
  Value *ShouldSample = Builder.CreateCall(ShouldSampleFunc);
  Value *ShouldReport = Builder.CreateICmpNE(ShouldSample, Builder.getInt32(0), "should_report");

  // Create another split for the actual report
  Instruction *ReportTerm = SplitBlockAndInsertIfThen(ShouldReport, ThenTerm, false);

  Builder.SetInsertPoint(ReportTerm);

  // Get the runtime report function
  FunctionCallee ReportFunc = getOverflowReportFunc(M);

  // Get PC (return address)
  Function *ReturnAddrIntrinsic = Intrinsic::getOrInsertDeclaration(
      &M, Intrinsic::returnaddress);
  Value *PC = Builder.CreateCall(ReturnAddrIntrinsic,
                                  {Builder.getInt32(0)});

  // Extract source location from debug metadata
  LocationInfo Loc = extractLocation(Builder, I);

  // Create expression string based on shift type
  const char *ShiftOpName;
  switch (I->getOpcode()) {
    case Instruction::Shl:  ShiftOpName = "shl"; break;
    case Instruction::AShr: ShiftOpName = "ashr"; break;
    case Instruction::LShr: ShiftOpName = "lshr"; break;
    default: ShiftOpName = "shift"; break;
  }
  std::string ExprStr = std::string("x ") + ShiftOpName + " y";
  Value *ExprGlobal = Builder.CreateGlobalString(ExprStr);

  // Convert operands to i64 for reporting
  Value *Value_i64 = Builder.CreateSExtOrTrunc(ShiftValue, Builder.getInt64Ty());
  Value *ShiftAmount_i64 = Builder.CreateZExtOrTrunc(ShiftAmount, Builder.getInt64Ty());

  // Call the report function with location metadata
  Builder.CreateCall(ReportFunc, {PC, Loc.File, Loc.Line, Loc.Function, ExprGlobal, Value_i64, ShiftAmount_i64});
}

FunctionCallee Trace2PassInstrumentorPass::getOverflowReportFunc(Module &M) {
  LLVMContext &Ctx = M.getContext();

  // void trace2pass_report_overflow(void* pc, const char* file, int line, const char* function,
  //                                  const char* expr, long long a, long long b)
  Type *VoidTy = Type::getVoidTy(Ctx);
  Type *VoidPtrTy = PointerType::getUnqual(Ctx);
  Type *CharPtrTy = PointerType::getUnqual(Ctx);
  Type *I32Ty = Type::getInt32Ty(Ctx);
  Type *I64Ty = Type::getInt64Ty(Ctx);

  FunctionType *FT = FunctionType::get(
      VoidTy,
      {VoidPtrTy, CharPtrTy, I32Ty, CharPtrTy, CharPtrTy, I64Ty, I64Ty},
      false);

  return M.getOrInsertFunction("trace2pass_report_overflow", FT);
}

bool Trace2PassInstrumentorPass::instrumentUnreachableCode(Function &F) {
  bool Modified = false;
  Module &M = *F.getParent();

  // Collect unreachable instructions to instrument
  SmallVector<UnreachableInst *, 8> ToInstrument;

  for (BasicBlock &BB : F) {
    for (Instruction &I : BB) {
      if (auto *UI = dyn_cast<UnreachableInst>(&I)) {
        ToInstrument.push_back(UI);
      }
    }
  }

  // Instrument collected unreachable instructions
  for (UnreachableInst *UI : ToInstrument) {
    // CRITICAL FIX: Instead of manual block splitting, insert report call BEFORE unreachable
    // This prevents LLVM -O2 crashes while still detecting unreachable code execution
    IRBuilder<> Builder(UI);

    // Call trace2pass_should_sample() to decide if we should report
    // Even though unreachable is a bug, sampling reduces overhead if hit repeatedly
    FunctionCallee ShouldSampleFunc = getShouldSampleFunc(M);
    Value *ShouldSample = Builder.CreateCall(ShouldSampleFunc);
    Value *ShouldReport = Builder.CreateICmpNE(ShouldSample, Builder.getInt32(0), "should_report");

    // Split block to conditionally execute report
    Instruction *ThenTerm = SplitBlockAndInsertIfThen(ShouldReport, UI, false);

    Builder.SetInsertPoint(ThenTerm);

    // Get the runtime report function
    FunctionCallee ReportFunc = getUnreachableReportFunc(M);

    // Get PC (return address)
    Function *ReturnAddrIntrinsic = Intrinsic::getOrInsertDeclaration(
        &M, Intrinsic::returnaddress);
    Value *PC = Builder.CreateCall(ReturnAddrIntrinsic,
                                    {Builder.getInt32(0)});

    // Extract source location from debug metadata
    LocationInfo Loc = extractLocation(Builder, UI);

    // Create message string
    std::string Message = "unreachable code executed";
    Value *MessageGlobal = Builder.CreateGlobalString(Message);

    // Call the report function with location metadata
    Builder.CreateCall(ReportFunc, {PC, Loc.File, Loc.Line, Loc.Function, MessageGlobal});

    // The unreachable instruction remains in the merge block
    // If execution reaches here and passes sampling, we report it

    Modified = true;
    NumUnreachableInstrumented++;
  }

  return Modified;
}

FunctionCallee Trace2PassInstrumentorPass::getUnreachableReportFunc(Module &M) {
  LLVMContext &Ctx = M.getContext();

  // void trace2pass_report_unreachable(void* pc, const char* file, int line, const char* function,
  //                                      const char* message)
  Type *VoidTy = Type::getVoidTy(Ctx);
  Type *VoidPtrTy = PointerType::getUnqual(Ctx);
  Type *CharPtrTy = PointerType::getUnqual(Ctx);
  Type *I32Ty = Type::getInt32Ty(Ctx);

  FunctionType *FT = FunctionType::get(
      VoidTy,
      {VoidPtrTy, CharPtrTy, I32Ty, CharPtrTy, CharPtrTy},
      false);

  return M.getOrInsertFunction("trace2pass_report_unreachable", FT);
}

bool Trace2PassInstrumentorPass::instrumentMemoryAccess(Function &F) {
  bool Modified = false;
  Module &M = *F.getParent();

  // Collect GEP instructions to instrument (to avoid iterator invalidation)
  SmallVector<GetElementPtrInst *, 16> ToInstrument;

  for (BasicBlock &BB : F) {
    for (Instruction &I : BB) {
      // Look for GetElementPtr instructions (array/pointer indexing)
      if (auto *GEP = dyn_cast<GetElementPtrInst>(&I)) {
        // FIX: Instrument ALL GEPs, including single-index (ptr[i])
        // Previously skipped single-index GEPs, which are the most common form
        ToInstrument.push_back(GEP);
      }
    }
  }

  // Instrument collected GEP instructions
  for (GetElementPtrInst *GEP : ToInstrument) {
    IRBuilder<> Builder(GEP);
    insertBoundsCheck(Builder, GEP);
    Modified = true;
    NumGEPInstrumented++;
  }

  return Modified;
}

void Trace2PassInstrumentorPass::insertBoundsCheck(IRBuilder<> &Builder,
                                                     GetElementPtrInst *GEP) {
  Module &M = *GEP->getModule();
  LLVMContext &Ctx = M.getContext();

  // LIMITATION: Currently only checking for negative indices
  // Upper-bound checking requires allocation size tracking (malloc/alloca metadata)
  // which is complex and would require interprocedural analysis.
  //
  // Current implementation:
  // - Checks: index < 0 (catches negative out-of-bounds)
  // - Missing: index >= array_size (requires size metadata)
  //
  // Future work: Track allocation sizes and check upper bounds

  // Get the pointer operand (base array/pointer)
  Value *BasePtr = GEP->getPointerOperand();

  // Get all indices
  SmallVector<Value *, 4> Indices;
  for (auto Idx = GEP->idx_begin(); Idx != GEP->idx_end(); ++Idx) {
    Indices.push_back(*Idx);
  }

  // For multi-dimensional arrays or complex GEPs, we focus on the last index
  // (the most common source of out-of-bounds access)
  if (Indices.empty())
    return;

  Value *LastIndex = Indices.back();

  // Check if index is negative (for signed indices)
  // NOTE: This catches only lower-bound violations, not upper-bound
  if (LastIndex->getType()->isIntegerTy()) {
    // Convert index to i64 for checking
    Value *Index_i64 = Builder.CreateSExtOrTrunc(LastIndex, Builder.getInt64Ty());

    // Check if index is negative
    Value *IsNegative = Builder.CreateICmpSLT(Index_i64, Builder.getInt64(0), "is_negative_index");

    // CRITICAL FIX: Use SplitBlockAndInsertIfThen instead of manual block splitting
    // This prevents LLVM -O2 crashes by properly handling CFG construction, PHI nodes,
    // and terminator management. Manual splicing was causing invalid IR that crashed
    // SimplifyCFG pass on large codebases like SQLite.
    // CRITICAL: No sampling for bounds violations - negative index is always a bug
    Instruction *ThenTerm = SplitBlockAndInsertIfThen(IsNegative, GEP, false);

    Builder.SetInsertPoint(ThenTerm);

    // Get the runtime report function
    FunctionCallee ReportFunc = getBoundsViolationReportFunc(M);

    // Get PC (return address)
    Function *ReturnAddrIntrinsic = Intrinsic::getOrInsertDeclaration(
        &M, Intrinsic::returnaddress);
    Value *PC = Builder.CreateCall(ReturnAddrIntrinsic,
                                    {Builder.getInt32(0)});

    // Extract source location from debug metadata
    LocationInfo Loc = extractLocation(Builder, GEP);

    // Cast base pointer to void*
    Value *BasePtr_void = Builder.CreatePointerCast(BasePtr,
                                                     PointerType::getUnqual(Ctx));

    // For now, we report with index as offset and 0 as size (unknown)
    // A more sophisticated implementation would track actual array sizes
    Value *Offset_u64 = Builder.CreateSExtOrTrunc(Index_i64, Builder.getInt64Ty());
    Value *Size_u64 = Builder.getInt64(0); // Unknown size

    // Call the report function with location metadata
    Builder.CreateCall(ReportFunc, {PC, Loc.File, Loc.Line, Loc.Function, BasePtr_void, Offset_u64, Size_u64});
  }
}

bool Trace2PassInstrumentorPass::instrumentSignConversions(Function &F,
                                                             AssumptionCache *AC,
                                                             DominatorTree *DT) {
  bool Modified = false;
  Module &M = *F.getParent();
  const DataLayout &DL = M.getDataLayout();

  // Counters for the per-function summary line. The runtime cost of
  // sign_conversion is dominated by the volume of instrumentation sites,
  // so reducing site count via compile-time filtering is the highest-ROI
  // optimization for this check.
  unsigned NumCandidates = 0;       // ZExt sites that match the structural filter
  unsigned NumSkippedConst = 0;     // Skipped: source operand is a constant
  unsigned NumSkippedKnownNN = 0;   // Skipped: source provably non-negative
  unsigned NumSkippedFits = 0;      // Skipped: value provably fits in dest width

  // Collect sign-changing cast instructions to instrument
  SmallVector<CastInst *, 16> SignChangingCasts;

  for (BasicBlock &BB : F) {
    for (Instruction &I : BB) {
      // Look for cast instructions
      if (CastInst *Cast = dyn_cast<CastInst>(&I)) {
        Type *SrcTy = Cast->getSrcTy();
        Type *DestTy = Cast->getDestTy();

        // Only interested in integer to integer casts
        if (!SrcTy->isIntegerTy() || !DestTy->isIntegerTy())
          continue;

        // Check if this is a sign-changing cast
        // We care about: signed → unsigned conversions where value might be negative
        bool IsSrcSigned = true;  // In LLVM IR, we assume signed unless proven otherwise
        bool IsDestUnsigned = true; // Same assumption

        // For sign-changing cast: we want to detect when a negative signed value
        // is converted to unsigned (losing the sign bit)
        // In LLVM IR, we detect this by looking at ZExt (zero extension) which
        // treats the source as unsigned, potentially losing sign information

        unsigned SrcBitWidth = SrcTy->getIntegerBitWidth();
        unsigned DestBitWidth = DestTy->getIntegerBitWidth();

        // We instrument casts that could lose sign information:
        // 1. ZExt (zero extension): treats source as unsigned
        //    - If source is negative, ZExt loses sign information
        //    - Instrument all ZExt (not just narrow→wide)
        // 2. Trunc (truncation): may lose high-order bits including sign bit
        //    - Instrument truncations that go to smaller widths
        //
        // Note: BitCast in LLVM IR is for pointer/type reinterpretation,
        // not int→uint (both are i32). Same-width signed→unsigned conversions
        // don't exist as explicit IR instructions.

        if (Cast->getOpcode() == Instruction::ZExt) {
          // ZExt: ONLY instrument narrow→wide (i8/i16 → i32/i64)
          // This is the most common sign conversion bug while avoiding false positives
          // Rationale: Smaller types more likely to have sign mismatches
          if (SrcBitWidth <= 16 && DestBitWidth >= 32) {
            ++NumCandidates;

            // Compile-time filtering via ValueTracking.
            // Each filter eliminates a category of provably-safe casts so we
            // never emit runtime checks for them. Order: cheapest checks first.
            Value *Src = Cast->getOperand(0);

            // Filter 1: source is a constant. The runtime check would always
            // produce the same answer, so it's pure overhead.
            if (isa<Constant>(Src)) {
              ++NumSkippedConst;
              continue;
            }

            // Filter 2: source provably non-negative. The cast can never lose
            // sign information because the high bit is known to be 0.
            // Build a SimplifyQuery so AC/DT context can flow into ValueTracking
            // (it is significantly more precise with these populated).
            SimplifyQuery SQ(DL, /*TLI=*/nullptr, DT, AC, Cast);
            unsigned SrcBits = Src->getType()->getIntegerBitWidth();
            KnownBits Known(SrcBits);
#if LLVM_VERSION_MAJOR >= 19
            // LLVM 19+: (V, Known, SimplifyQuery, Depth=0).
            computeKnownBits(Src, Known, SQ);
#else
            // LLVM 18: (V, Known, Depth, SimplifyQuery).
            computeKnownBits(Src, Known, /*Depth=*/0, SQ);
#endif
            if (Known.isNonNegative()) {
              ++NumSkippedKnownNN;
              continue;
            }

            // Filter 3: value provably fits within (DestBitWidth - 1) bits.
            // If the high bit of the dest can never be set, the cast cannot
            // surface a "negative becomes huge unsigned" bug.
            if (DestBitWidth > 0 &&
                Known.countMaxActiveBits() <= DestBitWidth - 1) {
              ++NumSkippedFits;
              continue;
            }

            SignChangingCasts.push_back(Cast);
          }
        }
        // Trunc and BitCast removed: too many false positives
      }
    }
  }

  // One-line filter summary to stderr so we can verify in benchmarks that
  // the filter is actually firing. Only emit if we considered at least one
  // candidate, to avoid spamming logs for functions with no casts.
  if (NumCandidates > 0) {
    unsigned Skipped = NumSkippedConst + NumSkippedKnownNN + NumSkippedFits;
    errs() << "Trace2Pass: sign_conversion in " << F.getName()
           << " — candidates=" << NumCandidates
           << ", instrumented=" << SignChangingCasts.size()
           << ", skipped=" << Skipped
           << " (const=" << NumSkippedConst
           << ", known_nn=" << NumSkippedKnownNN
           << ", fits=" << NumSkippedFits << ")\n";
  }

  // Instrument collected cast instructions
  for (CastInst *Cast : SignChangingCasts) {
    // We need to insert checks AFTER the cast completes
    // Use the safe insertion point
    Instruction *InsertPt = Cast->getNextNonDebugInstruction();
    if (!InsertPt) continue; // Skip if at end of block

    IRBuilder<> Builder(InsertPt);

    Value *OriginalValue = Cast->getOperand(0);
    Value *CastValue = Cast;

    Type *SrcTy = OriginalValue->getType();
    Type *DestTy = Cast->getType();

    // Check if source value was negative (< 0)
    Value *Zero = ConstantInt::get(SrcTy, 0);
    Value *IsNegative = Builder.CreateICmpSLT(OriginalValue, Zero, "is_negative");

    // Use LLVM's utility to safely split the block and insert conditional
    // This is what AddressSanitizer uses - it handles all the CFG complexity
    Instruction *ThenTerm = SplitBlockAndInsertIfThen(IsNegative, InsertPt, false);

    // Now check sampling in the "then" block
    Builder.SetInsertPoint(ThenTerm);

    // Use the per-check sampling rate so sign_conversion can be tuned
    // independently of the global rate (it is one of the heaviest checks).
    FunctionCallee ShouldSampleFunc = getShouldSampleSignConversionFunc(M);
    Value *ShouldSample = Builder.CreateCall(ShouldSampleFunc);
    Value *ShouldReport = Builder.CreateICmpNE(ShouldSample, Builder.getInt32(0), "should_report");

    // Create another split for the actual report
    Instruction *ReportTerm = SplitBlockAndInsertIfThen(ShouldReport, ThenTerm, false);

    // Now insert the report call in the inner "then" block
    Builder.SetInsertPoint(ReportTerm);

    // Get PC
    Function *ReturnAddrFn = Intrinsic::getOrInsertDeclaration(
        &M, Intrinsic::returnaddress);
    Value *PC = Builder.CreateCall(ReturnAddrFn, {Builder.getInt32(0)});

    // Extract source location from debug metadata
    LocationInfo Loc = extractLocation(Builder, Cast);

    // Convert values to i64
    Value *OrigValue_i64 = Builder.CreateSExtOrTrunc(OriginalValue, Builder.getInt64Ty());
    Value *CastValue_i64 = Builder.CreateZExtOrTrunc(CastValue, Builder.getInt64Ty());

    Value *SrcBits = Builder.getInt32(SrcTy->getIntegerBitWidth());
    Value *DestBits = Builder.getInt32(DestTy->getIntegerBitWidth());

    // Call runtime function with location metadata
    FunctionCallee ReportFunc = getSignConversionReportFunc(M);
    Builder.CreateCall(ReportFunc, {PC, Loc.File, Loc.Line, Loc.Function, OrigValue_i64, CastValue_i64, SrcBits, DestBits});

    Modified = true;
    NumSignConversionInstrumented++;
  }

  return Modified;
}

// Instrument division and modulo operations with zero checks
bool Trace2PassInstrumentorPass::instrumentDivisionByZero(Function &F) {
  Module &M = *F.getParent();
  std::vector<BinaryOperator*> DivOps;

  // Scan for division and modulo operations
  for (BasicBlock &BB : F) {
    for (Instruction &I : BB) {
      if (auto *BinOp = dyn_cast<BinaryOperator>(&I)) {
        unsigned Opcode = BinOp->getOpcode();
        // Check for integer division and modulo (signed and unsigned)
        if (Opcode == Instruction::SDiv || Opcode == Instruction::UDiv ||
            Opcode == Instruction::SRem || Opcode == Instruction::URem) {
          DivOps.push_back(BinOp);
        }
      }
    }
  }

  if (DivOps.empty())
    return false;

  FunctionCallee ReportFunc = getDivisionByZeroReportFunc(M);
  bool Modified = false;

  for (BinaryOperator *DivOp : DivOps) {
    Value *Divisor = DivOp->getOperand(1);

    // Build the check BEFORE the division instruction
    IRBuilder<> Builder(DivOp);

    // Create zero constant of same type as divisor
    Value *Zero = Constant::getNullValue(Divisor->getType());

    // Check if divisor == 0
    Value *IsZero = Builder.CreateICmpEQ(Divisor, Zero, "is_div_zero");

    // Split the block at the division instruction and insert our check
    // CRITICAL: No sampling for division by zero - always report if it happens
    Instruction *ThenTerm = SplitBlockAndInsertIfThen(IsZero, DivOp, false);

    Builder.SetInsertPoint(ThenTerm);

    // Get PC (return address)
    Function *ReturnAddrFn = Intrinsic::getOrInsertDeclaration(&M, Intrinsic::returnaddress);
    Value *PC = Builder.CreateCall(ReturnAddrFn, {Builder.getInt32(0)});

    // Extract source location from debug metadata
    LocationInfo Loc = extractLocation(Builder, DivOp);

    // Determine operation type
    const char *OpName;
    switch (DivOp->getOpcode()) {
      case Instruction::SDiv: OpName = "sdiv"; break;
      case Instruction::UDiv: OpName = "udiv"; break;
      case Instruction::SRem: OpName = "srem"; break;
      case Instruction::URem: OpName = "urem"; break;
      default: OpName = "unknown"; break;
    }

    Value *OpStr = Builder.CreateGlobalString(OpName, "div_op_name");

    // Sign-extend or zero-extend divisor to i64 for reporting
    Value *Dividend64, *Divisor64;
    if (DivOp->getOpcode() == Instruction::SDiv || DivOp->getOpcode() == Instruction::SRem) {
      // Signed operations: sign-extend
      Dividend64 = Builder.CreateSExtOrBitCast(DivOp->getOperand(0), Builder.getInt64Ty());
      Divisor64 = Builder.CreateSExtOrBitCast(Divisor, Builder.getInt64Ty());
    } else {
      // Unsigned operations: zero-extend
      Dividend64 = Builder.CreateZExtOrBitCast(DivOp->getOperand(0), Builder.getInt64Ty());
      Divisor64 = Builder.CreateZExtOrBitCast(Divisor, Builder.getInt64Ty());
    }

    // Call with location metadata
    Builder.CreateCall(ReportFunc, {PC, Loc.File, Loc.Line, Loc.Function, OpStr, Dividend64, Divisor64});

    Modified = true;
    NumDivisionByZeroInstrumented++;
  }

  return Modified;
}

// Instrument calls to pure functions for consistency checking
bool Trace2PassInstrumentorPass::instrumentPureFunctionCalls(Function &F) {
  Module &M = *F.getParent();
  std::vector<CallInst*> PureCalls;

  // Scan for calls to functions marked as readonly or readnone (pure/const)
  for (BasicBlock &BB : F) {
    for (Instruction &I : BB) {
      if (auto *Call = dyn_cast<CallInst>(&I)) {
        Function *Callee = Call->getCalledFunction();
        if (!Callee) continue;  // Indirect call, skip

        // Skip runtime functions
        if (Callee->getName().starts_with("trace2pass_")) continue;

        // Skip intrinsics and builtins
        if (Callee->isIntrinsic()) continue;

        // Check if function is marked as pure (readonly/readnone)
        // readonly = may read memory but doesn't write (pure)
        // readnone = doesn't access memory at all (const)
        if (Callee->doesNotAccessMemory() || Callee->onlyReadsMemory()) {
          // Additional filter: only instrument simple cases (integer args/return)
          Type *RetTy = Call->getType();
          if (RetTy->isIntegerTy() && Call->arg_size() <= 2) {
            // Check all args are integers
            bool allInts = true;
            for (Value *Arg : Call->args()) {
              if (!Arg->getType()->isIntegerTy()) {
                allInts = false;
                break;
              }
            }
            if (allInts) {
              PureCalls.push_back(Call);
            }
          }
        }
      }
    }
  }

  if (PureCalls.empty())
    return false;

  FunctionCallee ReportFunc = getPureConsistencyReportFunc(M);
  bool Modified = false;

  for (CallInst *Call : PureCalls) {
    Function *Callee = Call->getCalledFunction();
    Instruction *InsertPt = Call->getNextNonDebugInstruction();
    if (!InsertPt) continue;

    IRBuilder<> Builder(InsertPt);

    // Call trace2pass_should_sample() to decide if we should report
    FunctionCallee ShouldSampleFunc = getShouldSampleFunc(M);
    Value *ShouldSample = Builder.CreateCall(ShouldSampleFunc);
    Value *ShouldReport = Builder.CreateICmpNE(ShouldSample, Builder.getInt32(0), "should_report");

    // Split block and conditionally execute report
    Instruction *ThenTerm = SplitBlockAndInsertIfThen(ShouldReport, InsertPt, false);

    Builder.SetInsertPoint(ThenTerm);

    // Get PC (return address)
    Function *ReturnAddrFn = Intrinsic::getOrInsertDeclaration(&M, Intrinsic::returnaddress);
    Value *PC = Builder.CreateCall(ReturnAddrFn, {Builder.getInt32(0)});

    // Get function name
    Value *FuncName = Builder.CreateGlobalString(Callee->getName(), "pure_func_name");

    // Get arguments (extend to i64)
    Value *Arg0 = Builder.getInt64(0);
    Value *Arg1 = Builder.getInt64(0);

    if (Call->arg_size() >= 1) {
      Arg0 = Builder.CreateSExtOrBitCast(Call->getArgOperand(0), Builder.getInt64Ty());
    }
    if (Call->arg_size() >= 2) {
      Arg1 = Builder.CreateSExtOrBitCast(Call->getArgOperand(1), Builder.getInt64Ty());
    }

    // Get result (extend to i64)
    Value *Result = Builder.CreateSExtOrBitCast(Call, Builder.getInt64Ty());

    // Extract source location from debug metadata
    LocationInfo Loc = extractLocation(Builder, Call);

    // Call: trace2pass_check_pure_consistency(PC, file, line, function, func_name, arg0, arg1, result)
    Builder.CreateCall(ReportFunc, {PC, Loc.File, Loc.Line, Loc.Function, FuncName, Arg0, Arg1, Result});

    Modified = true;
    NumPureCallsInstrumented++;
  }

  return Modified;
}

FunctionCallee Trace2PassInstrumentorPass::getSignConversionReportFunc(Module &M) {
  LLVMContext &Ctx = M.getContext();

  // void trace2pass_report_sign_conversion(void* pc, const char* file, int line, const char* function,
  //                                         int64_t original_value, uint64_t cast_value, uint32_t src_bits, uint32_t dest_bits)
  Type *VoidTy = Type::getVoidTy(Ctx);
  Type *VoidPtrTy = PointerType::getUnqual(Ctx);
  Type *CharPtrTy = PointerType::getUnqual(Ctx);
  Type *I32Ty = Type::getInt32Ty(Ctx);
  Type *Int64Ty = Type::getInt64Ty(Ctx);
  Type *Uint64Ty = Type::getInt64Ty(Ctx); // Same as Int64 in LLVM IR
  Type *Uint32Ty = Type::getInt32Ty(Ctx);

  FunctionType *FT = FunctionType::get(
      VoidTy,
      {VoidPtrTy, CharPtrTy, I32Ty, CharPtrTy, Int64Ty, Uint64Ty, Uint32Ty, Uint32Ty},
      false);

  return M.getOrInsertFunction("trace2pass_report_sign_conversion", FT);
}

FunctionCallee Trace2PassInstrumentorPass::getBoundsViolationReportFunc(Module &M) {
  LLVMContext &Ctx = M.getContext();

  // void trace2pass_report_bounds_violation(void* pc, const char* file, int line, const char* function,
  //                                          void* ptr, size_t offset, size_t size)
  Type *VoidTy = Type::getVoidTy(Ctx);
  Type *VoidPtrTy = PointerType::getUnqual(Ctx);
  Type *CharPtrTy = PointerType::getUnqual(Ctx);
  Type *I32Ty = Type::getInt32Ty(Ctx);
  Type *SizeTy = M.getDataLayout().getIntPtrType(Ctx); // Matches size_t on any target

  FunctionType *FT = FunctionType::get(
      VoidTy,
      {VoidPtrTy, CharPtrTy, I32Ty, CharPtrTy, VoidPtrTy, SizeTy, SizeTy},
      false);

  return M.getOrInsertFunction("trace2pass_report_bounds_violation", FT);
}

FunctionCallee Trace2PassInstrumentorPass::getDivisionByZeroReportFunc(Module &M) {
  LLVMContext &Ctx = M.getContext();

  // void trace2pass_report_division_by_zero(void* pc, const char* file, int line, const char* function,
  //                                          const char* op_name, int64_t dividend, int64_t divisor)
  Type *VoidTy = Type::getVoidTy(Ctx);
  Type *VoidPtrTy = PointerType::getUnqual(Ctx);
  Type *CharPtrTy = PointerType::getUnqual(Ctx);  // const char*
  Type *I32Ty = Type::getInt32Ty(Ctx);
  Type *Int64Ty = Type::getInt64Ty(Ctx);

  FunctionType *FT = FunctionType::get(
      VoidTy,
      {VoidPtrTy, CharPtrTy, I32Ty, CharPtrTy, CharPtrTy, Int64Ty, Int64Ty},
      false);

  return M.getOrInsertFunction("trace2pass_report_division_by_zero", FT);
}

FunctionCallee Trace2PassInstrumentorPass::getPureConsistencyReportFunc(Module &M) {
  LLVMContext &Ctx = M.getContext();

  // void trace2pass_check_pure_consistency(void* pc, const char* file, int line, const char* function,
  //                                         const char* func_name, int64_t arg0, int64_t arg1, int64_t result)
  Type *VoidTy = Type::getVoidTy(Ctx);
  Type *VoidPtrTy = PointerType::getUnqual(Ctx);
  Type *CharPtrTy = PointerType::getUnqual(Ctx);  // const char*
  Type *I32Ty = Type::getInt32Ty(Ctx);
  Type *Int64Ty = Type::getInt64Ty(Ctx);

  FunctionType *FT = FunctionType::get(
      VoidTy,
      {VoidPtrTy, CharPtrTy, I32Ty, CharPtrTy, CharPtrTy, Int64Ty, Int64Ty, Int64Ty},
      false);

  return M.getOrInsertFunction("trace2pass_check_pure_consistency", FT);
}

FunctionCallee Trace2PassInstrumentorPass::getLoopBoundReportFunc(Module &M) {
  LLVMContext &Ctx = M.getContext();

  // void trace2pass_report_loop_bound_exceeded(void* pc, const char* file, int line, const char* function,
  //                                             const char* loop_name, uint64_t iteration_count, uint64_t threshold)
  Type *VoidTy = Type::getVoidTy(Ctx);
  Type *VoidPtrTy = PointerType::getUnqual(Ctx);
  Type *CharPtrTy = PointerType::getUnqual(Ctx);
  Type *I32Ty = Type::getInt32Ty(Ctx);
  Type *Uint64Ty = Type::getInt64Ty(Ctx);

  FunctionType *FT = FunctionType::get(
      VoidTy,
      {VoidPtrTy, CharPtrTy, I32Ty, CharPtrTy, CharPtrTy, Uint64Ty, Uint64Ty},
      false);

  return M.getOrInsertFunction("trace2pass_report_loop_bound_exceeded", FT);
}

FunctionCallee Trace2PassInstrumentorPass::getShouldSampleFunc(Module &M) {
  LLVMContext &Ctx = M.getContext();

  // int trace2pass_should_sample(void)
  Type *Int32Ty = Type::getInt32Ty(Ctx);

  FunctionType *FT = FunctionType::get(
      Int32Ty,
      {},  // No arguments
      false);

  return M.getOrInsertFunction("trace2pass_should_sample", FT);
}

// Per-check sampling getters. All share the same `int (void)` signature as
// the global trace2pass_should_sample; only the underlying runtime function
// differs so each check can be sampled at its own rate.
static FunctionCallee getNullaryInt32Func(Module &M, const char *name) {
  LLVMContext &Ctx = M.getContext();
  FunctionType *FT = FunctionType::get(Type::getInt32Ty(Ctx), {}, false);
  return M.getOrInsertFunction(name, FT);
}

FunctionCallee Trace2PassInstrumentorPass::getShouldSampleCrossBBFunc(Module &M) {
  return getNullaryInt32Func(M, "trace2pass_should_sample_cross_bb");
}

FunctionCallee Trace2PassInstrumentorPass::getShouldSampleSignConversionFunc(Module &M) {
  return getNullaryInt32Func(M, "trace2pass_should_sample_sign_conversion");
}

FunctionCallee Trace2PassInstrumentorPass::getShouldSampleStoreLoadFunc(Module &M) {
  return getNullaryInt32Func(M, "trace2pass_should_sample_store_load");
}

FunctionCallee Trace2PassInstrumentorPass::getShouldSampleGEPBoundsFunc(Module &M) {
  return getNullaryInt32Func(M, "trace2pass_should_sample_gep_bounds");
}

// Instrument loop iteration bounds
// Detects when loops iterate an unexpectedly high number of times
bool Trace2PassInstrumentorPass::instrumentLoopBounds(Function &F) {
  Module &M = *F.getParent();
  LLVMContext &Ctx = M.getContext();

  // Default threshold: 10 million iterations
  // This can be made configurable later
  const uint64_t LOOP_ITERATION_THRESHOLD = 10000000;

  // Identify loop headers using a simple heuristic:
  // A basic block is a loop header if it has a predecessor that comes after it in the CFG
  // (i.e., there's a back edge to this block)
  std::vector<BasicBlock*> LoopHeaders;

  for (BasicBlock &BB : F) {
    // Check if any successor branches back to this block (self-loop or back edge)
    for (BasicBlock *Pred : predecessors(&BB)) {
      // Simple heuristic: if a predecessor is the block itself or comes later in iteration,
      // this might be a loop header
      // For now, we'll just check for blocks that have back edges
      // A more sophisticated approach would use actual loop analysis

      // Check if this block dominates its predecessor (back edge characteristic)
      // For simplicity, we'll just check if the predecessor comes after us
      bool isBackEdge = false;

      // Simple check: if BB has a predecessor that is BB itself, it's a trivial loop
      if (Pred == &BB) {
        isBackEdge = true;
      } else {
        // Check if there's a path from BB to Pred (indicating a back edge)
        // For now, we'll use a simple heuristic: if Pred has a branch to BB
        // and BB comes before Pred in the function, it's likely a back edge
        for (auto it = F.begin(); it != F.end(); ++it) {
          if (&*it == &BB) {
            // BB comes first, check if Pred comes after
            for (auto it2 = it; it2 != F.end(); ++it2) {
              if (&*it2 == Pred) {
                isBackEdge = true;
                break;
              }
            }
            break;
          }
        }
      }

      if (isBackEdge) {
        LoopHeaders.push_back(&BB);
        break; // Only add this block once
      }
    }
  }

  if (LoopHeaders.empty())
    return false;

  FunctionCallee ReportFunc = getLoopBoundReportFunc(M);
  bool Modified = false;

  // Collect all loop counters for this function so we can reset them at function entry
  SmallVector<GlobalVariable *, 8> LoopCounters;

  for (BasicBlock *LoopHeader : LoopHeaders) {
    // Create a global variable to track iteration count for this loop
    // Format: __trace2pass_loop_counter_<function>_<block>
    std::string CounterName = "__trace2pass_loop_counter_" +
                               F.getName().str() + "_" +
                               LoopHeader->getName().str();

    // Create or get the global counter variable
    GlobalVariable *Counter = M.getGlobalVariable(CounterName);
    if (!Counter) {
      Counter = new GlobalVariable(
          M,
          Type::getInt64Ty(Ctx),
          false, // not constant
          GlobalValue::InternalLinkage,
          ConstantInt::get(Type::getInt64Ty(Ctx), 0), // initial value = 0
          CounterName);
    }

    // Add to list of counters to reset at function entry
    LoopCounters.push_back(Counter);

    // Insert instrumentation at the beginning of the loop header
    IRBuilder<> Builder(&*LoopHeader->getFirstInsertionPt());

// OPTION D: Make thread-safety configurable
#ifdef TRACE2PASS_ATOMIC_COUNTERS
    // Thread-safe mode: Use atomic fetch-and-add to prevent race conditions
    // Safe for multi-threaded programs but has higher overhead (~300%)
    Value *One = Builder.getInt64(1);
    Value *OldCount = Builder.CreateAtomicRMW(
        AtomicRMWInst::Add,
        Counter,
        One,
        MaybeAlign(),
        AtomicOrdering::SequentiallyConsistent
    );
    Value *NewCount = Builder.CreateAdd(OldCount, One, "loop_count_after");
#else
    // Fast mode (DEFAULT): Non-atomic operations
    // WARNING: NOT thread-safe - causes undefined behavior if multiple threads
    // execute the same loop concurrently. Only use for single-threaded programs.
    Value *CurrentCount = Builder.CreateLoad(Type::getInt64Ty(Ctx), Counter, "loop_count");
    Value *NewCount = Builder.CreateAdd(CurrentCount, Builder.getInt64(1), "loop_count_inc");
    Builder.CreateStore(NewCount, Counter);
#endif

    // Check if threshold exceeded
    Value *ThresholdVal = Builder.getInt64(LOOP_ITERATION_THRESHOLD);
    Value *ExceededThreshold = Builder.CreateICmpUGT(NewCount, ThresholdVal, "exceeds_threshold");

    // Only report once when threshold is first exceeded
    // Check if count == threshold + 1
    Value *ThresholdPlusOne = Builder.getInt64(LOOP_ITERATION_THRESHOLD + 1);
    Value *IsFirstExceedance = Builder.CreateICmpEQ(NewCount, ThresholdPlusOne, "first_exceed");

    Value *ShouldCheckReport = Builder.CreateAnd(ExceededThreshold, IsFirstExceedance, "should_check_report");

    // Split block and insert conditional report
    // CRITICAL: No sampling for loop bound exceedance - always report first occurrence
    Instruction *InsertPt = &*Builder.GetInsertPoint();
    Instruction *ThenTerm = SplitBlockAndInsertIfThen(ShouldCheckReport, InsertPt, false);

    Builder.SetInsertPoint(ThenTerm);

    // Get PC (return address)
    Function *ReturnAddrFn = Intrinsic::getOrInsertDeclaration(&M, Intrinsic::returnaddress);
    Value *PC = Builder.CreateCall(ReturnAddrFn, {Builder.getInt32(0)});

    // Create loop identifier string
    std::string LoopId = F.getName().str() + ":" + LoopHeader->getName().str();
    Value *LoopName = Builder.CreateGlobalString(LoopId, "loop_id");

    // Extract source location from debug metadata
    LocationInfo Loc = extractLocation(Builder, ThenTerm);

    // Call: trace2pass_report_loop_bound_exceeded(PC, file, line, function, loop_name, iteration_count, threshold)
    Builder.CreateCall(ReportFunc, {PC, Loc.File, Loc.Line, Loc.Function, LoopName, NewCount, ThresholdVal});

    Modified = true;
    NumLoopsInstrumented++;
  }

  // FIX: Reset all loop counters at function entry to prevent false positives
  // from monotonic increase across invocations
  if (!LoopCounters.empty() && Modified) {
    BasicBlock &EntryBB = F.getEntryBlock();
    IRBuilder<> ResetBuilder(&*EntryBB.getFirstInsertionPt());

    Value *Zero = ResetBuilder.getInt64(0);
    for (GlobalVariable *Counter : LoopCounters) {
#ifdef TRACE2PASS_ATOMIC_COUNTERS
      // Thread-safe mode: Use atomic store
      StoreInst *SI = ResetBuilder.CreateStore(Zero, Counter);
      SI->setAtomic(AtomicOrdering::Release);
      SI->setAlignment(Align(8)); // 8-byte alignment for i64
#else
      // Fast mode: Regular store
      ResetBuilder.CreateStore(Zero, Counter);
#endif
    }
  }

  return Modified;
}

// Select consistency: verify select instruction results match expected operand
bool Trace2PassInstrumentorPass::instrumentSelectConsistency(Function &F) {
  Module &M = *F.getParent();
  LLVMContext &Ctx = M.getContext();

  SmallVector<SelectInst *, 16> ToInstrument;
  for (BasicBlock &BB : F) {
    for (Instruction &I : BB) {
      if (auto *SI = dyn_cast<SelectInst>(&I)) {
        if (SI->getType()->isIntegerTy())
          ToInstrument.push_back(SI);
      }
    }
  }

  if (ToInstrument.empty())
    return false;

  bool Modified = false;

  for (SelectInst *SI : ToInstrument) {
    Value *Cond = SI->getCondition();
    Value *TrueVal = SI->getTrueValue();
    Value *FalseVal = SI->getFalseValue();
    Value *Result = SI;

    Instruction *InsertPt = SI->getNextNonDebugInstruction();
    if (!InsertPt) continue;

    IRBuilder<> Builder(InsertPt);

    // Check: (cond && result != true_val) || (!cond && result != false_val)
    Value *TrueMismatch = Builder.CreateICmpNE(Result, TrueVal, "true_mismatch");
    Value *FalseMismatch = Builder.CreateICmpNE(Result, FalseVal, "false_mismatch");
    Value *CondTrue = Builder.CreateAnd(Cond, TrueMismatch, "cond_true_bad");
    Value *CondNotRaw = Builder.CreateNot(Cond, "cond_not");
    Value *CondFalse = Builder.CreateAnd(CondNotRaw, FalseMismatch, "cond_false_bad");
    Value *IsInconsistent = Builder.CreateOr(CondTrue, CondFalse, "select_inconsistent");

    Instruction *ThenTerm = SplitBlockAndInsertIfThen(IsInconsistent, InsertPt, false);
    Builder.SetInsertPoint(ThenTerm);

    FunctionCallee ReportFunc = getSelectInconsistencyReportFunc(M);

    Function *ReturnAddrFn = Intrinsic::getOrInsertDeclaration(&M, Intrinsic::returnaddress);
    Value *PC = Builder.CreateCall(ReturnAddrFn, {Builder.getInt32(0)});

    LocationInfo Loc = extractLocation(Builder, SI);

    Value *Cond_i64 = Builder.CreateZExtOrTrunc(Cond, Builder.getInt64Ty());
    Value *True_i64 = Builder.CreateSExtOrTrunc(TrueVal, Builder.getInt64Ty());
    Value *False_i64 = Builder.CreateSExtOrTrunc(FalseVal, Builder.getInt64Ty());
    Value *Result_i64 = Builder.CreateSExtOrTrunc(Result, Builder.getInt64Ty());

    Builder.CreateCall(ReportFunc, {PC, Loc.File, Loc.Line, Loc.Function,
                                     Cond_i64, True_i64, False_i64, Result_i64});

    Modified = true;
    NumSelectInstrumented++;
  }

  return Modified;
}

// Range checks: verify !range metadata at runtime
bool Trace2PassInstrumentorPass::instrumentRangeChecks(Function &F) {
  Module &M = *F.getParent();
  LLVMContext &Ctx = M.getContext();

  SmallVector<Instruction *, 16> ToInstrument;
  for (BasicBlock &BB : F) {
    for (Instruction &I : BB) {
      if (I.getMetadata(LLVMContext::MD_range) && I.getType()->isIntegerTy())
        ToInstrument.push_back(&I);
    }
  }

  if (ToInstrument.empty())
    return false;

  bool Modified = false;

  for (Instruction *I : ToInstrument) {
    MDNode *RangeMD = I->getMetadata(LLVMContext::MD_range);
    if (!RangeMD || RangeMD->getNumOperands() < 2)
      continue;

    Instruction *InsertPt = I->getNextNonDebugInstruction();
    if (!InsertPt) continue;

    IRBuilder<> Builder(InsertPt);

    Value *Val = I;
    Type *ValTy = Val->getType();
    unsigned BitWidth = ValTy->getIntegerBitWidth();

    // Parse range pairs and build InAnyRange = OR of all range checks
    Value *InAnyRange = Builder.getFalse();
    // Store first range pair for reporting
    ConstantInt *FirstLo = nullptr;
    ConstantInt *FirstHi = nullptr;

    for (unsigned i = 0; i + 1 < RangeMD->getNumOperands(); i += 2) {
      auto *Lo = mdconst::dyn_extract<ConstantInt>(RangeMD->getOperand(i));
      auto *Hi = mdconst::dyn_extract<ConstantInt>(RangeMD->getOperand(i + 1));
      if (!Lo || !Hi) continue;

      if (!FirstLo) { FirstLo = Lo; FirstHi = Hi; }

      Value *LoVal = ConstantInt::get(ValTy, Lo->getValue());
      Value *HiVal = ConstantInt::get(ValTy, Hi->getValue());

      Value *InRange;
      if (Lo->getValue().ule(Hi->getValue())) {
        // Normal range [lo, hi): val >= lo && val < hi
        Value *GeLo = Builder.CreateICmpUGE(Val, LoVal, "ge_lo");
        Value *LtHi = Builder.CreateICmpULT(Val, HiVal, "lt_hi");
        InRange = Builder.CreateAnd(GeLo, LtHi, "in_range");
      } else {
        // Wrapped range: val >= lo || val < hi
        Value *GeLo = Builder.CreateICmpUGE(Val, LoVal, "ge_lo_wrap");
        Value *LtHi = Builder.CreateICmpULT(Val, HiVal, "lt_hi_wrap");
        InRange = Builder.CreateOr(GeLo, LtHi, "in_range_wrap");
      }
      InAnyRange = Builder.CreateOr(InAnyRange, InRange, "in_any_range");
    }

    if (!FirstLo) continue;

    // OutOfRange = !InAnyRange
    Value *OutOfRange = Builder.CreateNot(InAnyRange, "out_of_range");

    Instruction *ThenTerm = SplitBlockAndInsertIfThen(OutOfRange, InsertPt, false);
    Builder.SetInsertPoint(ThenTerm);

    // Sampling for range checks (can be frequent on code with many range-annotated loads)
    FunctionCallee ShouldSampleFunc = getShouldSampleFunc(M);
    Value *ShouldSample = Builder.CreateCall(ShouldSampleFunc);
    Value *ShouldReport = Builder.CreateICmpNE(ShouldSample, Builder.getInt32(0), "should_report");

    Instruction *ReportTerm = SplitBlockAndInsertIfThen(ShouldReport, ThenTerm, false);
    Builder.SetInsertPoint(ReportTerm);

    FunctionCallee ReportFunc = getRangeViolationReportFunc(M);

    Function *ReturnAddrFn = Intrinsic::getOrInsertDeclaration(&M, Intrinsic::returnaddress);
    Value *PC = Builder.CreateCall(ReturnAddrFn, {Builder.getInt32(0)});

    LocationInfo Loc = extractLocation(Builder, I);

    Value *Val_i64 = Builder.CreateSExtOrTrunc(Val, Builder.getInt64Ty());
    Value *Lo_i64 = Builder.CreateSExtOrTrunc(
        ConstantInt::get(ValTy, FirstLo->getValue()), Builder.getInt64Ty());
    Value *Hi_i64 = Builder.CreateSExtOrTrunc(
        ConstantInt::get(ValTy, FirstHi->getValue()), Builder.getInt64Ty());

    Builder.CreateCall(ReportFunc, {PC, Loc.File, Loc.Line, Loc.Function,
                                     Val_i64, Lo_i64, Hi_i64});

    Modified = true;
    NumRangeInstrumented++;
  }

  return Modified;
}

// Store-load consistency: verify same-BB store-then-load pairs
bool Trace2PassInstrumentorPass::instrumentStoreLoadConsistency(Function &F) {
  Module &M = *F.getParent();
  LLVMContext &Ctx = M.getContext();
  bool Modified = false;

  for (BasicBlock &BB : F) {
    DenseMap<Value*, StoreInst*> LastStore;

    // Collect store-load pairs first to avoid iterator invalidation
    SmallVector<std::pair<StoreInst*, LoadInst*>, 8> Pairs;

    for (Instruction &I : BB) {
      if (auto *SI = dyn_cast<StoreInst>(&I)) {
        if (SI->isVolatile()) continue;
        Value *Ptr = SI->getPointerOperand();
        Type *StoredTy = SI->getValueOperand()->getType();
        if (StoredTy->isIntegerTy() || StoredTy->isPointerTy())
          LastStore[Ptr] = SI;
      } else if (auto *LI = dyn_cast<LoadInst>(&I)) {
        if (LI->isVolatile()) continue;
        Value *Ptr = LI->getPointerOperand();
        auto It = LastStore.find(Ptr);
        if (It != LastStore.end()) {
          StoreInst *SI = It->second;
          // Matching type check
          if (SI->getValueOperand()->getType() == LI->getType()) {
            Pairs.push_back({SI, LI});
          }
        }
      } else if (auto *CB = dyn_cast<CallBase>(&I)) {
        // Call may write memory — clear tracked stores
        if (!CB->doesNotAccessMemory() && !CB->onlyReadsMemory())
          LastStore.clear();
      }
    }

    for (auto &[SI, LI] : Pairs) {
      Value *StoredVal = SI->getValueOperand();
      Value *LoadedVal = LI;

      Instruction *InsertPt = LI->getNextNonDebugInstruction();
      if (!InsertPt) continue;

      IRBuilder<> Builder(InsertPt);

      Value *StoredCmp, *LoadedCmp;
      if (StoredVal->getType()->isPointerTy()) {
        StoredCmp = Builder.CreatePtrToInt(StoredVal, Builder.getInt64Ty());
        LoadedCmp = Builder.CreatePtrToInt(LoadedVal, Builder.getInt64Ty());
      } else {
        StoredCmp = StoredVal;
        LoadedCmp = LoadedVal;
      }

      Value *Mismatch = Builder.CreateICmpNE(StoredCmp, LoadedCmp, "sl_mismatch");

      Instruction *ThenTerm = SplitBlockAndInsertIfThen(Mismatch, InsertPt, false);
      Builder.SetInsertPoint(ThenTerm);

      FunctionCallee ReportFunc = getStoreLoadInconsistencyReportFunc(M);

      Function *ReturnAddrFn = Intrinsic::getOrInsertDeclaration(&M, Intrinsic::returnaddress);
      Value *PC = Builder.CreateCall(ReturnAddrFn, {Builder.getInt32(0)});

      LocationInfo Loc = extractLocation(Builder, LI);

      Value *Stored_i64, *Loaded_i64;
      if (StoredVal->getType()->isPointerTy()) {
        Stored_i64 = Builder.CreatePtrToInt(StoredVal, Builder.getInt64Ty());
        Loaded_i64 = Builder.CreatePtrToInt(LoadedVal, Builder.getInt64Ty());
      } else {
        Stored_i64 = Builder.CreateSExtOrTrunc(StoredVal, Builder.getInt64Ty());
        Loaded_i64 = Builder.CreateSExtOrTrunc(LoadedVal, Builder.getInt64Ty());
      }

      Builder.CreateCall(ReportFunc, {PC, Loc.File, Loc.Line, Loc.Function,
                                       Stored_i64, Loaded_i64});

      Modified = true;
      NumStoreLoadInstrumented++;
    }
  }

  return Modified;
}

FunctionCallee Trace2PassInstrumentorPass::getSelectInconsistencyReportFunc(Module &M) {
  LLVMContext &Ctx = M.getContext();
  Type *VoidTy = Type::getVoidTy(Ctx);
  Type *PtrTy = PointerType::getUnqual(Ctx);
  Type *I32Ty = Type::getInt32Ty(Ctx);
  Type *I64Ty = Type::getInt64Ty(Ctx);

  FunctionType *FT = FunctionType::get(
      VoidTy,
      {PtrTy, PtrTy, I32Ty, PtrTy, I64Ty, I64Ty, I64Ty, I64Ty},
      false);

  return M.getOrInsertFunction("trace2pass_report_select_inconsistency", FT);
}

FunctionCallee Trace2PassInstrumentorPass::getRangeViolationReportFunc(Module &M) {
  LLVMContext &Ctx = M.getContext();
  Type *VoidTy = Type::getVoidTy(Ctx);
  Type *PtrTy = PointerType::getUnqual(Ctx);
  Type *I32Ty = Type::getInt32Ty(Ctx);
  Type *I64Ty = Type::getInt64Ty(Ctx);

  FunctionType *FT = FunctionType::get(
      VoidTy,
      {PtrTy, PtrTy, I32Ty, PtrTy, I64Ty, I64Ty, I64Ty},
      false);

  return M.getOrInsertFunction("trace2pass_report_range_violation", FT);
}

FunctionCallee Trace2PassInstrumentorPass::getStoreLoadInconsistencyReportFunc(Module &M) {
  LLVMContext &Ctx = M.getContext();
  Type *VoidTy = Type::getVoidTy(Ctx);
  Type *PtrTy = PointerType::getUnqual(Ctx);
  Type *I32Ty = Type::getInt32Ty(Ctx);
  Type *I64Ty = Type::getInt64Ty(Ctx);

  FunctionType *FT = FunctionType::get(
      VoidTy,
      {PtrTy, PtrTy, I32Ty, PtrTy, I64Ty, I64Ty},
      false);

  return M.getOrInsertFunction("trace2pass_report_store_load_inconsistency", FT);
}

// Volatile tracking: cross-BB consistency for volatile loads/stores
// Targets GVN bugs where volatile semantics are violated (e.g., #127511, #116668)
bool Trace2PassInstrumentorPass::instrumentVolatileConsistency(Function &F) {
  Module &M = *F.getParent();
  bool Modified = false;

  FunctionCallee ShadowStoreFunc = getShadowStoreFunc(M);
  FunctionCallee ShadowCheckFunc = getShadowCheckFunc(M);

  // Collect volatile stores and loads first to avoid iterator invalidation
  SmallVector<StoreInst*, 8> VolStores;
  SmallVector<LoadInst*, 8> VolLoads;

  for (BasicBlock &BB : F) {
    for (Instruction &I : BB) {
      if (auto *SI = dyn_cast<StoreInst>(&I)) {
        if (SI->isVolatile()) {
          Type *StoredTy = SI->getValueOperand()->getType();
          // Only track integer and pointer types (can be cast to i64)
          if (StoredTy->isIntegerTy() || StoredTy->isPointerTy())
            VolStores.push_back(SI);
        }
      } else if (auto *LI = dyn_cast<LoadInst>(&I)) {
        if (LI->isVolatile()) {
          Type *LoadedTy = LI->getType();
          if (LoadedTy->isIntegerTy() || LoadedTy->isPointerTy())
            VolLoads.push_back(LI);
        }
      }
    }
  }

  // Insert shadow stores after each volatile store
  for (StoreInst *SI : VolStores) {
    Instruction *InsertPt = SI->getNextNonDebugInstruction();
    if (!InsertPt) continue;

    IRBuilder<> Builder(InsertPt);
    Value *Ptr = SI->getPointerOperand();
    Value *Val = SI->getValueOperand();

    // Cast pointer to void*
    Value *PtrCast = Builder.CreateBitCast(Ptr, Builder.getPtrTy());
    // Cast value to i64
    Value *Val_i64;
    if (Val->getType()->isPointerTy()) {
      Val_i64 = Builder.CreatePtrToInt(Val, Builder.getInt64Ty());
    } else {
      Val_i64 = Builder.CreateSExtOrTrunc(Val, Builder.getInt64Ty());
    }

    Builder.CreateCall(ShadowStoreFunc, {PtrCast, Val_i64});
    Modified = true;
    NumVolatileInstrumented++;
  }

  // Insert shadow checks after each volatile load
  for (LoadInst *LI : VolLoads) {
    Instruction *InsertPt = LI->getNextNonDebugInstruction();
    if (!InsertPt) continue;

    IRBuilder<> Builder(InsertPt);
    Value *Ptr = LI->getPointerOperand();
    Value *LoadedVal = LI;

    // Cast pointer to void*
    Value *PtrCast = Builder.CreateBitCast(Ptr, Builder.getPtrTy());
    // Cast loaded value to i64
    Value *Loaded_i64;
    if (LoadedVal->getType()->isPointerTy()) {
      Loaded_i64 = Builder.CreatePtrToInt(LoadedVal, Builder.getInt64Ty());
    } else {
      Loaded_i64 = Builder.CreateSExtOrTrunc(LoadedVal, Builder.getInt64Ty());
    }

    Function *ReturnAddrFn = Intrinsic::getOrInsertDeclaration(&M, Intrinsic::returnaddress);
    Value *PC = Builder.CreateCall(ReturnAddrFn, {Builder.getInt32(0)});

    LocationInfo Loc = extractLocation(Builder, LI);

    Builder.CreateCall(ShadowCheckFunc, {PC, Loc.File, Loc.Line, Loc.Function,
                                          PtrCast, Loaded_i64});
    Modified = true;
  }

  return Modified;
}

FunctionCallee Trace2PassInstrumentorPass::getOpaqueReadFunc(Module &M) {
  LLVMContext &Ctx = M.getContext();
  Type *I64Ty = Type::getInt64Ty(Ctx);
  Type *PtrTy = PointerType::getUnqual(Ctx);
  Type *I32Ty = Type::getInt32Ty(Ctx);

  // int64_t trace2pass_opaque_read(void* addr, int32_t size_bytes)
  FunctionType *FT = FunctionType::get(I64Ty, {PtrTy, I32Ty}, false);
  FunctionCallee FC = M.getOrInsertFunction("trace2pass_opaque_read", FT);

  // Mark as readonly so GVN can still fold the load this call guards.
  // GVN sees: "this call only reads memory" → load value is NOT clobbered
  // → GVN proceeds with its (potentially buggy) folding.
  // But GVN CANNOT predict the return value (external, opaque body)
  // → the icmp comparison survives → mismatch detected at runtime.
  //
  // DO NOT add readnone — that would let GVN eliminate the call entirely.
  if (Function *F = dyn_cast<Function>(FC.getCallee())) {
    F->addFnAttr(Attribute::ReadOnly);
    F->addFnAttr(Attribute::NoUnwind);
    F->addFnAttr(Attribute::WillReturn);
    F->addFnAttr(Attribute::NoSync);
    F->addFnAttr(Attribute::NoFree);
  }

  return FC;
}

FunctionCallee Trace2PassInstrumentorPass::getValuePropagationReportFunc(Module &M) {
  LLVMContext &Ctx = M.getContext();
  Type *VoidTy = Type::getVoidTy(Ctx);
  Type *PtrTy = PointerType::getUnqual(Ctx);
  Type *I32Ty = Type::getInt32Ty(Ctx);
  Type *I64Ty = Type::getInt64Ty(Ctx);

  // void trace2pass_report_value_propagation(void* pc, const char* file, int line,
  //     const char* function, void* addr, int64_t optimized_value, int64_t actual_value)
  FunctionType *FT = FunctionType::get(
      VoidTy,
      {PtrTy, PtrTy, I32Ty, PtrTy, PtrTy, I64Ty, I64Ty},
      false);

  return M.getOrInsertFunction("trace2pass_report_value_propagation", FT);
}

FunctionCallee Trace2PassInstrumentorPass::getCrossBBCheckFunc(Module &M) {
  LLVMContext &Ctx = M.getContext();
  Type *VoidTy = Type::getVoidTy(Ctx);
  Type *PtrTy = PointerType::getUnqual(Ctx);
  Type *I32Ty = Type::getInt32Ty(Ctx);
  Type *I64Ty = Type::getInt64Ty(Ctx);

  // void trace2pass_check_cross_bb(void* addr, int32_t size_bytes,
  //     int64_t optimized_value, const char* file, int32_t line, const char* function)
  FunctionType *FT = FunctionType::get(
      VoidTy,
      {PtrTy, I32Ty, I64Ty, PtrTy, I32Ty, PtrTy},
      false);
  FunctionCallee FC = M.getOrInsertFunction("trace2pass_check_cross_bb", FT);

  // Mark with inaccessiblememonly so GVN does NOT see this call as aliasing
  // any program-visible memory. Without this, GVN conservatively keeps the
  // guarded load (preventing the bug instead of detecting it).
  //
  // Technically the function reads from addr at runtime, but the attribute
  // lie is intentional: we WANT GVN to fold the load (exercising its bug),
  // then the runtime compares the folded value against actual memory.
  if (Function *F = dyn_cast<Function>(FC.getCallee())) {
    F->setMemoryEffects(MemoryEffects::inaccessibleMemOnly());
    F->addFnAttr(Attribute::NoUnwind);
    F->addFnAttr(Attribute::WillReturn);
    F->addFnAttr(Attribute::NoSync);
    F->addFnAttr(Attribute::NoFree);
  }

  return FC;
}

// Helper: trace a value through bitcasts/GEPs to find the root AllocaInst
AllocaInst *Trace2PassInstrumentorPass::findRootAlloca(Value *V) {
  Value *Current = V;
  for (unsigned i = 0; i < 10; ++i) { // Limit depth to avoid infinite loops
    if (auto *AI = dyn_cast<AllocaInst>(Current))
      return AI;
    if (auto *BC = dyn_cast<BitCastInst>(Current)) {
      Current = BC->getOperand(0);
      continue;
    }
    if (auto *GEP = dyn_cast<GetElementPtrInst>(Current)) {
      Current = GEP->getPointerOperand();
      continue;
    }
    break;
  }
  return nullptr;
}

// Helper: check if an alloca's address escapes (passed to calls or stored to memory)
bool Trace2PassInstrumentorPass::isAddressTaken(AllocaInst *AI) {
  SmallVector<Value *, 8> Worklist;
  Worklist.push_back(AI);

  SmallPtrSet<Value *, 16> Visited;

  while (!Worklist.empty()) {
    Value *V = Worklist.pop_back_val();
    if (!Visited.insert(V).second)
      continue;

    for (User *U : V->users()) {
      if (auto *SI = dyn_cast<StoreInst>(U)) {
        // If the alloca is stored AS A VALUE (not as the pointer operand),
        // its address is escaping
        if (SI->getValueOperand() == V)
          return true;
      } else if (auto *CB = dyn_cast<CallBase>(U)) {
        // Skip our own instrumentation functions
        Function *Callee = CB->getCalledFunction();
        if (Callee && Callee->getName().starts_with("trace2pass_"))
          continue;
        // Address passed to a function call — it escapes
        return true;
      } else if (isa<BitCastInst>(U) || isa<GetElementPtrInst>(U)) {
        // Follow through casts/GEPs
        Worklist.push_back(U);
      } else if (isa<LoadInst>(U)) {
        // Loading from the alloca is fine
        continue;
      } else if (auto *SI2 = dyn_cast<StoreInst>(U)) {
        // Storing TO the alloca is fine (already handled above for value operand)
        continue;
      } else if (isa<PHINode>(U) || isa<SelectInst>(U)) {
        Worklist.push_back(U);
      }
    }
  }
  return false;
}

// Helper: check if function contains setjmp/sigsetjmp/returns_twice calls
bool Trace2PassInstrumentorPass::hasSetjmp(Function &F) {
  for (BasicBlock &BB : F) {
    for (Instruction &I : BB) {
      if (auto *CB = dyn_cast<CallBase>(&I)) {
        // Check for returns_twice attribute (covers setjmp and friends)
        if (CB->hasFnAttr(Attribute::ReturnsTwice))
          return true;
        // Also check by name for cases where attribute might be missing
        Function *Callee = CB->getCalledFunction();
        if (Callee) {
          StringRef Name = Callee->getName();
          if (Name == "setjmp" || Name == "_setjmp" ||
              Name == "sigsetjmp" || Name == "__sigsetjmp")
            return true;
        }
      }
    }
  }
  return false;
}

// Cross-BB value propagation consistency check via opaque memory read
// Targets GVN bugs (#127511, #116668) that incorrectly fold loads
bool Trace2PassInstrumentorPass::instrumentCrossBBConsistency(Function &F) {
  Module &M = *F.getParent();
  LLVMContext &Ctx = M.getContext();
  const DataLayout &DL = M.getDataLayout();
  bool Modified = false;

  bool funcHasSetjmp = hasSetjmp(F);

  // Collect loads to instrument (avoid iterator invalidation)
  SmallVector<LoadInst *, 16> ToInstrument;

  for (BasicBlock &BB : F) {
    for (Instruction &I : BB) {
      auto *LI = dyn_cast<LoadInst>(&I);
      if (!LI) continue;

      // Skip volatile loads (already handled by volatile tracking)
      if (LI->isVolatile()) continue;

      Type *LoadedTy = LI->getType();
      // Only handle integer and pointer types (can be compared as i64)
      if (!LoadedTy->isIntegerTy() && !LoadedTy->isPointerTy()) continue;

      // For integer types, only handle sizes we can read (1, 2, 4, 8 bytes)
      if (LoadedTy->isIntegerTy()) {
        unsigned BitWidth = LoadedTy->getIntegerBitWidth();
        if (BitWidth != 8 && BitWidth != 16 && BitWidth != 32 && BitWidth != 64)
          continue;
      }

      // Find root alloca
      AllocaInst *AI = findRootAlloca(LI->getPointerOperand());
      if (!AI) continue;

      // Check if this load qualifies for instrumentation:
      // 1. Function has setjmp (high-value target for GVN bugs)
      // 2. Address is taken (escapes to external functions)
      // 3. Cross-BB: alloca has stores in different BBs than this load
      bool shouldInstrument = false;

      if (funcHasSetjmp) {
        shouldInstrument = true;
      } else if (isAddressTaken(AI)) {
        shouldInstrument = true;
      } else {
        // Check for cross-BB stores
        BasicBlock *LoadBB = LI->getParent();
        for (User *U : AI->users()) {
          if (auto *SI = dyn_cast<StoreInst>(U)) {
            if (SI->getPointerOperand() == AI && SI->getParent() != LoadBB) {
              shouldInstrument = true;
              break;
            }
          }
          // Also check through GEPs/bitcasts
          if (isa<GetElementPtrInst>(U) || isa<BitCastInst>(U)) {
            for (User *UU : U->users()) {
              if (auto *SI = dyn_cast<StoreInst>(UU)) {
                if (SI->getParent() != LoadBB) {
                  shouldInstrument = true;
                  break;
                }
              }
            }
          }
          if (shouldInstrument) break;
        }
      }

      if (shouldInstrument)
        ToInstrument.push_back(LI);
    }
  }

  if (ToInstrument.empty())
    return false;

  // Phase 3: we no longer call the wrapper trace2pass_check_cross_bb.
  // Instead we inline the compare-and-maybe-report sequence in IR, so the
  // common path (sampled, match) costs only: one opaque_read call + icmp
  // + branch. The wrapper function call (and its return overhead) is
  // removed from every check.
  FunctionCallee OpaqueReadFunc = getOpaqueReadFunc(M);
  FunctionCallee ReportFunc = getValuePropagationReportFunc(M);

  for (LoadInst *LI : ToInstrument) {
    Type *LoadedTy = LI->getType();
    Value *Ptr = LI->getPointerOperand();

    // Insert instrumentation AFTER the load
    Instruction *InsertPt = LI->getNextNonDebugInstruction();
    if (!InsertPt) continue;

    IRBuilder<> Builder(InsertPt);

    // Determine size in bytes
    int32_t SizeBytes;
    if (LoadedTy->isPointerTy()) {
      SizeBytes = DL.getPointerSize();
    } else {
      SizeBytes = LoadedTy->getIntegerBitWidth() / 8;
    }

    // Convert loaded value to i64
    Value *Loaded_i64;
    if (LoadedTy->isPointerTy()) {
      Loaded_i64 = Builder.CreatePtrToInt(LI, Builder.getInt64Ty());
    } else {
      Loaded_i64 = Builder.CreateZExtOrTrunc(LI, Builder.getInt64Ty());
    }

    // Extract source location
    LocationInfo Loc = extractLocation(Builder, LI);

    // Gate the check on per-check sampling so cross_bb can be tuned
    // independently of the global rate. Cross_bb's runtime cost is
    // ~100-1000x the default checks; even 1% sampling turns a 90x
    // slowdown into a ~1x slowdown in hot loops.
    //
    // CRITICAL: the load instruction (LI) remains UNCONDITIONAL above
    // this point. Only the check call is moved inside the conditional
    // block, so GVN can still fold the load and exercise the bug.
    FunctionCallee SampleFunc = getShouldSampleCrossBBFunc(M);
    Value *ShouldSample = Builder.CreateCall(SampleFunc);
    Value *DoCheck = Builder.CreateICmpNE(ShouldSample, Builder.getInt32(0), "cb_do_check");
    Instruction *SampleThenTerm = SplitBlockAndInsertIfThen(DoCheck, InsertPt, false);
    Builder.SetInsertPoint(SampleThenTerm);

    // Phase 3: inline the opaque_read + compare + report sequence.
    // Previously this was a single consolidated call to trace2pass_check_cross_bb,
    // which added wrapper function-call overhead on every sampled check.
    Value *PtrCast = Builder.CreateBitCast(Ptr, Builder.getPtrTy());
    Value *Actual_i64 = Builder.CreateCall(OpaqueReadFunc,
                                            {PtrCast, Builder.getInt32(SizeBytes)},
                                            "cb_actual");
    Value *Mismatch = Builder.CreateICmpNE(Actual_i64, Loaded_i64, "cb_mismatch");

    // Only enter the report path when the values disagree. Keeps the common
    // sampled path to just: opaque_read + icmp + branch (no report call).
    Instruction *ReportTerm = SplitBlockAndInsertIfThen(Mismatch, SampleThenTerm, false);
    Builder.SetInsertPoint(ReportTerm);

    // PC for the report (same semantics as the old wrapper used via
    // __builtin_return_address inside the runtime).
    Function *ReturnAddrFn = Intrinsic::getOrInsertDeclaration(
        &M, Intrinsic::returnaddress);
    Value *PC = Builder.CreateCall(ReturnAddrFn, {Builder.getInt32(0)});

    Builder.CreateCall(ReportFunc,
                       {PC, Loc.File, Loc.Line, Loc.Function,
                        PtrCast, Loaded_i64, Actual_i64});

    Modified = true;
    NumCrossBBInstrumented++;
  }

  return Modified;
}

FunctionCallee Trace2PassInstrumentorPass::getShadowStoreFunc(Module &M) {
  LLVMContext &Ctx = M.getContext();
  Type *VoidTy = Type::getVoidTy(Ctx);
  Type *PtrTy = PointerType::getUnqual(Ctx);
  Type *I64Ty = Type::getInt64Ty(Ctx);

  FunctionType *FT = FunctionType::get(
      VoidTy, {PtrTy, I64Ty}, false);

  return M.getOrInsertFunction("trace2pass_shadow_store", FT);
}

FunctionCallee Trace2PassInstrumentorPass::getShadowCheckFunc(Module &M) {
  LLVMContext &Ctx = M.getContext();
  Type *VoidTy = Type::getVoidTy(Ctx);
  Type *PtrTy = PointerType::getUnqual(Ctx);
  Type *I32Ty = Type::getInt32Ty(Ctx);
  Type *I64Ty = Type::getInt64Ty(Ctx);

  // Signature: void(void* pc, char* file, int line, char* function, void* addr, int64_t loaded_value)
  FunctionType *FT = FunctionType::get(
      VoidTy, {PtrTy, PtrTy, I32Ty, PtrTy, PtrTy, I64Ty}, false);

  return M.getOrInsertFunction("trace2pass_shadow_check", FT);
}

// Backend Checksum: Instrument function return values for miscompilation detection
// Accumulates a deterministic checksum of all function return values.
// Compare O0 checksum vs Ox checksum to detect backend codegen bugs.
bool Trace2PassInstrumentorPass::instrumentReturnChecksums(Function &F) {
  Module &M = *F.getParent();
  LLVMContext &Ctx = M.getContext();
  bool Modified = false;

  // Compute a stable hash of the function name (used as func_hash argument)
  // This ties each return value to its function, making the checksum order-sensitive
  uint64_t FuncNameHash = 0;
  StringRef FName = F.getName();
  for (size_t i = 0; i < FName.size(); ++i) {
    FuncNameHash = FuncNameHash * 31 + (uint64_t)FName[i];
  }

  // Collect all return instructions
  SmallVector<ReturnInst *, 8> Returns;
  for (BasicBlock &BB : F) {
    if (auto *RI = dyn_cast<ReturnInst>(BB.getTerminator())) {
      Returns.push_back(RI);
    }
  }

  if (Returns.empty())
    return false;

  FunctionCallee AccumFunc = getAccumulateChecksumFunc(M);

  for (ReturnInst *RI : Returns) {
    IRBuilder<> Builder(RI);

    Value *FuncHash = Builder.getInt64(FuncNameHash);
    Value *RetVal_i64;

    Value *RetVal = RI->getReturnValue();
    if (RetVal) {
      Type *RetTy = RetVal->getType();
      if (RetTy->isIntegerTy()) {
        // Integer return: sign-extend or truncate to i64
        RetVal_i64 = Builder.CreateSExtOrTrunc(RetVal, Builder.getInt64Ty());
      } else if (RetTy->isPointerTy()) {
        // Pointer return: cast to i64
        RetVal_i64 = Builder.CreatePtrToInt(RetVal, Builder.getInt64Ty());
      } else if (RetTy->isFloatingPointTy()) {
        // Float/double: bitcast to integer, then extend to i64
        unsigned BitWidth = RetTy->getPrimitiveSizeInBits();
        Type *IntTy = Type::getIntNTy(Ctx, BitWidth);
        Value *AsInt = Builder.CreateBitCast(RetVal, IntTy);
        RetVal_i64 = Builder.CreateZExtOrTrunc(AsInt, Builder.getInt64Ty());
      } else {
        // Aggregate, vector, or other complex type — use constant 1
        // (still captures call count)
        RetVal_i64 = Builder.getInt64(1);
      }
    } else {
      // Void function — use constant 0
      // Still contributes to checksum via func_hash (captures call count)
      RetVal_i64 = Builder.getInt64(0);
    }

    Builder.CreateCall(AccumFunc, {FuncHash, RetVal_i64});

    Modified = true;
    NumReturnChecksumInstrumented++;
  }

  return Modified;
}

FunctionCallee Trace2PassInstrumentorPass::getAccumulateChecksumFunc(Module &M) {
  LLVMContext &Ctx = M.getContext();
  Type *VoidTy = Type::getVoidTy(Ctx);
  Type *I64Ty = Type::getInt64Ty(Ctx);

  // Signature: void trace2pass_accumulate_checksum(uint64_t func_hash, int64_t ret_value)
  FunctionType *FT = FunctionType::get(
      VoidTy, {I64Ty, I64Ty}, false);

  return M.getOrInsertFunction("trace2pass_accumulate_checksum", FT);
}

} // anonymous namespace

// Pass registration
extern "C" LLVM_ATTRIBUTE_WEAK ::llvm::PassPluginLibraryInfo
llvmGetPassPluginInfo() {
  return {
    LLVM_PLUGIN_API_VERSION, "Trace2PassInstrumentor", "v0.1",
    [](PassBuilder &PB) {
      // Register the pass with the optimizer pipeline
      PB.registerPipelineParsingCallback(
        [](StringRef Name, FunctionPassManager &FPM,
           ArrayRef<PassBuilder::PipelineElement>) {
          if (Name == "trace2pass-instrument") {
            FPM.addPass(Trace2PassInstrumentorPass());
            return true;
          }
          return false;
        });

      // Also register for optimization pipeline extension point
      PB.registerPipelineStartEPCallback(
        [](ModulePassManager &MPM, OptimizationLevel Level) {
          FunctionPassManager FPM;
          FPM.addPass(Trace2PassInstrumentorPass());
          MPM.addPass(createModuleToFunctionPassAdaptor(std::move(FPM)));
        });
    }
  };
}
