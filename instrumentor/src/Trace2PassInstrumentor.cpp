#include "llvm/IR/PassManager.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Passes/PassPlugin.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/IR/Module.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Transforms/Utils/ModuleUtils.h"
#include "llvm/Transforms/Utils/BasicBlockUtils.h"

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
  bool instrumentSignConversions(Function &F);
  bool instrumentDivisionByZero(Function &F);
  bool instrumentPureFunctionCalls(Function &F);
  bool instrumentLoopBounds(Function &F);
  void insertOverflowCheck(IRBuilder<> &Builder, Instruction *I,
                           Value *LHS, Value *RHS);
  void insertShiftCheck(IRBuilder<> &Builder, Instruction *I,
                        Value *ShiftValue, Value *ShiftAmount);
  void insertBoundsCheck(IRBuilder<> &Builder, GetElementPtrInst *GEP);

  // Runtime function declarations
  FunctionCallee getOverflowReportFunc(Module &M);
  FunctionCallee getUnreachableReportFunc(Module &M);
  FunctionCallee getBoundsViolationReportFunc(Module &M);
  FunctionCallee getSignConversionReportFunc(Module &M);
  FunctionCallee getDivisionByZeroReportFunc(Module &M);
  FunctionCallee getPureConsistencyReportFunc(Module &M);
  FunctionCallee getLoopBoundReportFunc(Module &M);
  FunctionCallee getShouldSampleFunc(Module &M);

  // Statistics
  unsigned NumInstrumented = 0;
  unsigned NumUnreachableInstrumented = 0;
  unsigned NumGEPInstrumented = 0;
  unsigned NumSignConversionInstrumented = 0;
  unsigned NumDivisionByZeroInstrumented = 0;
  unsigned NumPureCallsInstrumented = 0;
  unsigned NumLoopsInstrumented = 0;
};

PreservedAnalyses Trace2PassInstrumentorPass::run(Function &F,
                                                    FunctionAnalysisManager &FAM) {
  // Skip declarations (no body)
  if (F.isDeclaration())
    return PreservedAnalyses::all();

  // Skip runtime library functions to avoid recursive instrumentation
  if (F.getName().starts_with("trace2pass_"))
    return PreservedAnalyses::all();

  errs() << "Trace2Pass: Instrumenting function: " << F.getName() << "\n";

  // Reset counters for this function to avoid accumulation across functions
  NumInstrumented = 0;
  NumUnreachableInstrumented = 0;
  NumGEPInstrumented = 0;
  NumSignConversionInstrumented = 0;
  NumDivisionByZeroInstrumented = 0;
  NumPureCallsInstrumented = 0;
  NumLoopsInstrumented = 0;

  bool Modified = false;

  // Instrument arithmetic operations
  Modified |= instrumentArithmeticOperations(F);

  // Instrument unreachable code
  Modified |= instrumentUnreachableCode(F);

  // Instrument memory accesses (GEP bounds checks)
  Modified |= instrumentMemoryAccess(F);

  // Instrument sign-changing casts
  Modified |= instrumentSignConversions(F);

  // Instrument division by zero
  Modified |= instrumentDivisionByZero(F);

  // Instrument pure function calls for consistency checking
  Modified |= instrumentPureFunctionCalls(F);

  // Instrument loop bounds checking
  Modified |= instrumentLoopBounds(F);

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
    errs() << " in " << F.getName() << "\n";

    // We modified the function, so we need to invalidate analyses
    return PreservedAnalyses::none();
  }

  return PreservedAnalyses::all();
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

    // Insert overflow check
    insertOverflowCheck(Builder, I, LHS, RHS);

    Modified = true;
    NumInstrumented++;
  }

  return Modified;
}

void Trace2PassInstrumentorPass::insertOverflowCheck(IRBuilder<> &Builder,
                                                      Instruction *I,
                                                      Value *LHS, Value *RHS) {
  Module &M = *I->getModule();
  LLVMContext &Ctx = M.getContext();
  Type *IntTy = I->getType();

  // Handle shift operations separately (no intrinsic available)
  if (I->getOpcode() == Instruction::Shl) {
    insertShiftCheck(Builder, I, LHS, RHS);
    return;
  }

  // Determine if we should check signed or unsigned overflow
  // Use nsw/nuw flags if present, otherwise default to signed
  bool checkSigned = true;
  bool checkUnsigned = false;

  if (auto *BinOp = dyn_cast<BinaryOperator>(I)) {
    // If instruction has nsw (no signed wrap) flag, check signed overflow
    // If instruction has nuw (no unsigned wrap) flag, check unsigned overflow
    checkSigned = BinOp->hasNoSignedWrap() || (!BinOp->hasNoSignedWrap() && !BinOp->hasNoUnsignedWrap());
    checkUnsigned = BinOp->hasNoUnsignedWrap();
  }

  // Select the appropriate overflow intrinsic based on operation and signedness
  Intrinsic::ID IntrinsicID;
  const char *OpName;

  switch (I->getOpcode()) {
    case Instruction::Mul:
      IntrinsicID = checkUnsigned ? Intrinsic::umul_with_overflow : Intrinsic::smul_with_overflow;
      OpName = checkUnsigned ? "umul" : "smul";
      break;
    case Instruction::Add:
      IntrinsicID = checkUnsigned ? Intrinsic::uadd_with_overflow : Intrinsic::sadd_with_overflow;
      OpName = checkUnsigned ? "uadd" : "sadd";
      break;
    case Instruction::Sub:
      IntrinsicID = checkUnsigned ? Intrinsic::usub_with_overflow : Intrinsic::ssub_with_overflow;
      OpName = checkUnsigned ? "usub" : "ssub";
      break;
    default:
      return; // Shouldn't reach here
  }

  // Use LLVM's overflow intrinsic
  Function *OverflowIntrinsic = Intrinsic::getOrInsertDeclaration(
      &M, IntrinsicID, {IntTy});

  // Call the intrinsic
  CallInst *OverflowCall = Builder.CreateCall(OverflowIntrinsic, {LHS, RHS});

  // Extract result and overflow flag
  Value *Result = Builder.CreateExtractValue(OverflowCall, 0);
  Value *OverflowFlag = Builder.CreateExtractValue(OverflowCall, 1);

  // Create basic blocks for sampling and reporting
  BasicBlock *CheckSampleBB = BasicBlock::Create(Ctx, "check_sample",
                                                  I->getFunction());
  BasicBlock *ReportBB = BasicBlock::Create(Ctx, "report_overflow",
                                             I->getFunction());
  BasicBlock *ContinueBB = BasicBlock::Create(Ctx, "continue",
                                               I->getFunction());

  // Split the current basic block
  BasicBlock *CurrentBB = I->getParent();

  // Branch based on overflow flag
  Builder.CreateCondBr(OverflowFlag, CheckSampleBB, ContinueBB);

  // Fill in the sampling check block
  Builder.SetInsertPoint(CheckSampleBB);

  // Call trace2pass_should_sample() to decide if we should report
  FunctionCallee ShouldSampleFunc = getShouldSampleFunc(M);
  Value *ShouldSample = Builder.CreateCall(ShouldSampleFunc);
  Value *ShouldReport = Builder.CreateICmpNE(ShouldSample, Builder.getInt32(0), "should_report");

  // Branch to report or continue based on sampling decision
  Builder.CreateCondBr(ShouldReport, ReportBB, ContinueBB);

  // Fill in the report block
  Builder.SetInsertPoint(ReportBB);

  // Get the runtime report function
  FunctionCallee ReportFunc = getOverflowReportFunc(M);

  // Prepare arguments for the report function
  // void trace2pass_report_overflow(void* pc, const char* expr, i64 a, i64 b)

  // Get PC (return address)
  Function *ReturnAddrIntrinsic = Intrinsic::getOrInsertDeclaration(
      &M, Intrinsic::returnaddress);
  Value *PC = Builder.CreateCall(ReturnAddrIntrinsic,
                                  {Builder.getInt32(0)});

  // Create expression string based on operation
  std::string ExprStr = std::string("x ") + OpName + " y";
  Value *ExprGlobal = Builder.CreateGlobalString(ExprStr);

  // Convert operands to i64 for reporting
  Value *LHS_i64 = Builder.CreateSExtOrTrunc(LHS, Builder.getInt64Ty());
  Value *RHS_i64 = Builder.CreateSExtOrTrunc(RHS, Builder.getInt64Ty());

  // Call the report function
  Builder.CreateCall(ReportFunc, {PC, ExprGlobal, LHS_i64, RHS_i64});

  // Continue execution (non-fatal for now)
  Builder.CreateBr(ContinueBB);

  // Move the rest of the instructions to the continue block
  ContinueBB->splice(ContinueBB->begin(), CurrentBB,
                     I->getIterator(), CurrentBB->end());

  // Replace uses of the original instruction with our computed result
  I->replaceAllUsesWith(Result);

  // The original instruction is now dead, but we keep it for now
  // (it will be cleaned up by DCE)
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
  Value *IsInvalid = Builder.CreateICmpUGE(ShiftAmount_i32, BitWidthConst);

  // Create basic blocks for sampling and reporting
  BasicBlock *CheckSampleBB = BasicBlock::Create(Ctx, "check_sample",
                                                  I->getFunction());
  BasicBlock *ReportBB = BasicBlock::Create(Ctx, "report_shift_overflow",
                                             I->getFunction());
  BasicBlock *ContinueBB = BasicBlock::Create(Ctx, "continue",
                                               I->getFunction());

  // Branch based on validity
  Builder.CreateCondBr(IsInvalid, CheckSampleBB, ContinueBB);

  // Fill in the sampling check block
  Builder.SetInsertPoint(CheckSampleBB);

  // Call trace2pass_should_sample() to decide if we should report
  FunctionCallee ShouldSampleFunc = getShouldSampleFunc(M);
  Value *ShouldSample = Builder.CreateCall(ShouldSampleFunc);
  Value *ShouldReport = Builder.CreateICmpNE(ShouldSample, Builder.getInt32(0), "should_report");

  // Branch to report or continue based on sampling decision
  Builder.CreateCondBr(ShouldReport, ReportBB, ContinueBB);

  // Fill in the report block
  Builder.SetInsertPoint(ReportBB);

  // Get the runtime report function
  FunctionCallee ReportFunc = getOverflowReportFunc(M);

  // Prepare arguments
  Function *ReturnAddrIntrinsic = Intrinsic::getOrInsertDeclaration(
      &M, Intrinsic::returnaddress);
  Value *PC = Builder.CreateCall(ReturnAddrIntrinsic,
                                  {Builder.getInt32(0)});

  // Create expression string
  std::string ExprStr = "x shl y";
  Value *ExprGlobal = Builder.CreateGlobalString(ExprStr);

  // Convert operands to i64 for reporting
  Value *Value_i64 = Builder.CreateSExtOrTrunc(ShiftValue, Builder.getInt64Ty());
  Value *ShiftAmount_i64 = Builder.CreateZExtOrTrunc(ShiftAmount, Builder.getInt64Ty());

  // Call the report function
  Builder.CreateCall(ReportFunc, {PC, ExprGlobal, Value_i64, ShiftAmount_i64});

  // Continue execution
  Builder.CreateBr(ContinueBB);

  // Move remaining instructions to continue block
  BasicBlock *CurrentBB = I->getParent();
  ContinueBB->splice(ContinueBB->begin(), CurrentBB,
                     I->getIterator(), CurrentBB->end());

  // Note: For shifts, the result is undefined if shift >= bitwidth,
  // so we just continue with whatever LLVM produces
}

FunctionCallee Trace2PassInstrumentorPass::getOverflowReportFunc(Module &M) {
  LLVMContext &Ctx = M.getContext();

  // void trace2pass_report_overflow(void* pc, const char* expr, i64 a, i64 b)
  Type *VoidTy = Type::getVoidTy(Ctx);
  Type *VoidPtrTy = PointerType::getUnqual(Ctx);
  Type *CharPtrTy = PointerType::getUnqual(Ctx);
  Type *I64Ty = Type::getInt64Ty(Ctx);

  FunctionType *FT = FunctionType::get(
      VoidTy,
      {VoidPtrTy, CharPtrTy, I64Ty, I64Ty},
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
    LLVMContext &Ctx = M.getContext();

    // Split the block before the unreachable instruction
    BasicBlock *UnreachableBB = UI->getParent();
    BasicBlock *CheckSampleBB = BasicBlock::Create(Ctx, "check_sample", &F);
    BasicBlock *ReportBB = BasicBlock::Create(Ctx, "report_unreachable", &F);
    BasicBlock *ContinueThenUnreachableBB = BasicBlock::Create(Ctx, "continue_then_unreachable", &F);

    // Move the unreachable instruction to the new block
    ContinueThenUnreachableBB->splice(ContinueThenUnreachableBB->begin(), UnreachableBB, UI->getIterator(), UnreachableBB->end());

    // Insert branch to check_sample at end of original block
    IRBuilder<> BranchBuilder(UnreachableBB);
    BranchBuilder.CreateBr(CheckSampleBB);

    // Fill in the sampling check block
    IRBuilder<> SampleBuilder(CheckSampleBB);
    FunctionCallee ShouldSampleFunc = getShouldSampleFunc(M);
    Value *ShouldSample = SampleBuilder.CreateCall(ShouldSampleFunc);
    Value *ShouldReport = SampleBuilder.CreateICmpNE(ShouldSample, SampleBuilder.getInt32(0), "should_report");
    SampleBuilder.CreateCondBr(ShouldReport, ReportBB, ContinueThenUnreachableBB);

    // Fill in the report block
    IRBuilder<> ReportBuilder(ReportBB);

    // Get the runtime report function
    FunctionCallee ReportFunc = getUnreachableReportFunc(M);

    // Get PC (return address)
    Function *ReturnAddrIntrinsic = Intrinsic::getOrInsertDeclaration(
        &M, Intrinsic::returnaddress);
    Value *PC = ReportBuilder.CreateCall(ReturnAddrIntrinsic,
                                          {ReportBuilder.getInt32(0)});

    // Create message string
    std::string Message = "unreachable code executed";
    Value *MessageGlobal = ReportBuilder.CreateGlobalString(Message);

    // Call the report function
    ReportBuilder.CreateCall(ReportFunc, {PC, MessageGlobal});

    // Branch to unreachable instruction
    ReportBuilder.CreateBr(ContinueThenUnreachableBB);

    // Note: The unreachable instruction remains in ContinueThenUnreachableBB
    // If code reaches here, it will hit the unreachable and abort

    Modified = true;
    NumUnreachableInstrumented++;
  }

  return Modified;
}

FunctionCallee Trace2PassInstrumentorPass::getUnreachableReportFunc(Module &M) {
  LLVMContext &Ctx = M.getContext();

  // void trace2pass_report_unreachable(void* pc, const char* message)
  Type *VoidTy = Type::getVoidTy(Ctx);
  Type *VoidPtrTy = PointerType::getUnqual(Ctx);
  Type *CharPtrTy = PointerType::getUnqual(Ctx);

  FunctionType *FT = FunctionType::get(
      VoidTy,
      {VoidPtrTy, CharPtrTy},
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
        // Only instrument GEPs that access arrays (not struct fields)
        // We check if there are more than one indices (first is base pointer)
        if (GEP->getNumIndices() > 1) {
          ToInstrument.push_back(GEP);
        }
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

  // For now, we'll implement a conservative check:
  // We'll instrument all GEP instructions and check indices at runtime
  // More sophisticated analysis could determine actual array bounds

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
  if (LastIndex->getType()->isIntegerTy()) {
    // Create basic blocks for the check
    BasicBlock *CheckBB = BasicBlock::Create(Ctx, "bounds_check",
                                              GEP->getFunction());
    BasicBlock *CheckSampleBB = BasicBlock::Create(Ctx, "check_sample",
                                                    GEP->getFunction());
    BasicBlock *ReportBB = BasicBlock::Create(Ctx, "report_bounds_violation",
                                               GEP->getFunction());
    BasicBlock *ContinueBB = BasicBlock::Create(Ctx, "bounds_ok",
                                                 GEP->getFunction());

    BasicBlock *CurrentBB = GEP->getParent();

    // Insert unconditional branch to check block
    Builder.CreateBr(CheckBB);

    // Build the check: index < 0 (for signed indices)
    Builder.SetInsertPoint(CheckBB);

    // Convert index to i64 for checking
    Value *Index_i64 = Builder.CreateSExtOrTrunc(LastIndex, Builder.getInt64Ty());

    // Check if index is negative
    Value *IsNegative = Builder.CreateICmpSLT(Index_i64, Builder.getInt64(0));

    Builder.CreateCondBr(IsNegative, CheckSampleBB, ContinueBB);

    // Fill in the sampling check block
    Builder.SetInsertPoint(CheckSampleBB);

    // Call trace2pass_should_sample() to decide if we should report
    FunctionCallee ShouldSampleFunc = getShouldSampleFunc(M);
    Value *ShouldSample = Builder.CreateCall(ShouldSampleFunc);
    Value *ShouldReport = Builder.CreateICmpNE(ShouldSample, Builder.getInt32(0), "should_report");

    // Branch to report or continue based on sampling decision
    Builder.CreateCondBr(ShouldReport, ReportBB, ContinueBB);

    // Fill in the report block
    Builder.SetInsertPoint(ReportBB);

    // Get the runtime report function
    FunctionCallee ReportFunc = getBoundsViolationReportFunc(M);

    // Get PC (return address)
    Function *ReturnAddrIntrinsic = Intrinsic::getOrInsertDeclaration(
        &M, Intrinsic::returnaddress);
    Value *PC = Builder.CreateCall(ReturnAddrIntrinsic,
                                    {Builder.getInt32(0)});

    // Cast base pointer to void*
    Value *BasePtr_void = Builder.CreatePointerCast(BasePtr,
                                                     PointerType::getUnqual(Ctx));

    // For now, we report with index as offset and 0 as size (unknown)
    // A more sophisticated implementation would track actual array sizes
    Value *Offset_u64 = Builder.CreateSExtOrTrunc(Index_i64, Builder.getInt64Ty());
    Value *Size_u64 = Builder.getInt64(0); // Unknown size

    // Call the report function
    // void trace2pass_report_bounds_violation(void* pc, void* ptr, size_t offset, size_t size)
    Builder.CreateCall(ReportFunc, {PC, BasePtr_void, Offset_u64, Size_u64});

    // Continue execution (non-fatal for now)
    Builder.CreateBr(ContinueBB);

    // Move the GEP and subsequent instructions to the continue block
    ContinueBB->splice(ContinueBB->begin(), CurrentBB,
                       GEP->getIterator(), CurrentBB->end());
  }
}

bool Trace2PassInstrumentorPass::instrumentSignConversions(Function &F) {
  bool Modified = false;
  Module &M = *F.getParent();

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

        // We instrument casts where:
        // 1. Bitcast from same-width integers (i32 -> i32 but semantically signed->unsigned)
        // 2. ZExt which might lose sign if source was negative
        // 3. Trunc which might change interpretation

        if (Cast->getOpcode() == Instruction::BitCast ||
            Cast->getOpcode() == Instruction::ZExt ||
            (Cast->getOpcode() == Instruction::Trunc && SrcBitWidth > DestBitWidth)) {
          SignChangingCasts.push_back(Cast);
        }
      }
    }
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

    // Call trace2pass_should_sample() to decide if we should report
    FunctionCallee ShouldSampleFunc = getShouldSampleFunc(M);
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

    // Convert values to i64
    Value *OrigValue_i64 = Builder.CreateSExtOrTrunc(OriginalValue, Builder.getInt64Ty());
    Value *CastValue_i64 = Builder.CreateZExtOrTrunc(CastValue, Builder.getInt64Ty());

    Value *SrcBits = Builder.getInt32(SrcTy->getIntegerBitWidth());
    Value *DestBits = Builder.getInt32(DestTy->getIntegerBitWidth());

    // Call runtime function
    FunctionCallee ReportFunc = getSignConversionReportFunc(M);
    Builder.CreateCall(ReportFunc, {PC, OrigValue_i64, CastValue_i64, SrcBits, DestBits});

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
    // This creates: if (divisor == 0) { check_sample(); if (should_sample) report(); } then continue with division
    Instruction *ThenTerm = SplitBlockAndInsertIfThen(IsZero, DivOp, false);

    Builder.SetInsertPoint(ThenTerm);

    // Call trace2pass_should_sample() to decide if we should report
    FunctionCallee ShouldSampleFunc = getShouldSampleFunc(M);
    Value *ShouldSample = Builder.CreateCall(ShouldSampleFunc);
    Value *ShouldReport = Builder.CreateICmpNE(ShouldSample, Builder.getInt32(0), "should_report");

    // Create another split for the actual report
    Instruction *ReportTerm = SplitBlockAndInsertIfThen(ShouldReport, ThenTerm, false);

    Builder.SetInsertPoint(ReportTerm);

    // Get PC (return address)
    Function *ReturnAddrFn = Intrinsic::getOrInsertDeclaration(&M, Intrinsic::returnaddress);
    Value *PC = Builder.CreateCall(ReturnAddrFn, {Builder.getInt32(0)});

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

    // Call: trace2pass_report_division_by_zero(PC, op_name, dividend, divisor)
    Builder.CreateCall(ReportFunc, {PC, OpStr, Dividend64, Divisor64});

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

    // Call: trace2pass_check_pure_consistency(PC, func_name, arg0, arg1, result)
    Builder.CreateCall(ReportFunc, {PC, FuncName, Arg0, Arg1, Result});

    Modified = true;
    NumPureCallsInstrumented++;
  }

  return Modified;
}

FunctionCallee Trace2PassInstrumentorPass::getSignConversionReportFunc(Module &M) {
  LLVMContext &Ctx = M.getContext();

  // void trace2pass_report_sign_conversion(void* pc, int64_t original_value, uint64_t cast_value, uint32_t src_bits, uint32_t dest_bits)
  Type *VoidTy = Type::getVoidTy(Ctx);
  Type *VoidPtrTy = PointerType::getUnqual(Ctx);
  Type *Int64Ty = Type::getInt64Ty(Ctx);
  Type *Uint64Ty = Type::getInt64Ty(Ctx); // Same as Int64 in LLVM IR
  Type *Uint32Ty = Type::getInt32Ty(Ctx);

  FunctionType *FT = FunctionType::get(
      VoidTy,
      {VoidPtrTy, Int64Ty, Uint64Ty, Uint32Ty, Uint32Ty},
      false);

  return M.getOrInsertFunction("trace2pass_report_sign_conversion", FT);
}

FunctionCallee Trace2PassInstrumentorPass::getBoundsViolationReportFunc(Module &M) {
  LLVMContext &Ctx = M.getContext();

  // void trace2pass_report_bounds_violation(void* pc, void* ptr, size_t offset, size_t size)
  Type *VoidTy = Type::getVoidTy(Ctx);
  Type *VoidPtrTy = PointerType::getUnqual(Ctx);
  Type *SizeTy = Type::getInt64Ty(Ctx); // size_t is i64 on 64-bit systems

  FunctionType *FT = FunctionType::get(
      VoidTy,
      {VoidPtrTy, VoidPtrTy, SizeTy, SizeTy},
      false);

  return M.getOrInsertFunction("trace2pass_report_bounds_violation", FT);
}

FunctionCallee Trace2PassInstrumentorPass::getDivisionByZeroReportFunc(Module &M) {
  LLVMContext &Ctx = M.getContext();

  // void trace2pass_report_division_by_zero(void* pc, const char* op_name, int64_t dividend, int64_t divisor)
  Type *VoidTy = Type::getVoidTy(Ctx);
  Type *VoidPtrTy = PointerType::getUnqual(Ctx);
  Type *CharPtrTy = PointerType::getUnqual(Ctx);  // const char*
  Type *Int64Ty = Type::getInt64Ty(Ctx);

  FunctionType *FT = FunctionType::get(
      VoidTy,
      {VoidPtrTy, CharPtrTy, Int64Ty, Int64Ty},
      false);

  return M.getOrInsertFunction("trace2pass_report_division_by_zero", FT);
}

FunctionCallee Trace2PassInstrumentorPass::getPureConsistencyReportFunc(Module &M) {
  LLVMContext &Ctx = M.getContext();

  // void trace2pass_check_pure_consistency(void* pc, const char* func_name, int64_t arg0, int64_t arg1, int64_t result)
  Type *VoidTy = Type::getVoidTy(Ctx);
  Type *VoidPtrTy = PointerType::getUnqual(Ctx);
  Type *CharPtrTy = PointerType::getUnqual(Ctx);  // const char*
  Type *Int64Ty = Type::getInt64Ty(Ctx);

  FunctionType *FT = FunctionType::get(
      VoidTy,
      {VoidPtrTy, CharPtrTy, Int64Ty, Int64Ty, Int64Ty},
      false);

  return M.getOrInsertFunction("trace2pass_check_pure_consistency", FT);
}

FunctionCallee Trace2PassInstrumentorPass::getLoopBoundReportFunc(Module &M) {
  LLVMContext &Ctx = M.getContext();

  // void trace2pass_report_loop_bound_exceeded(void* pc, const char* loop_name, uint64_t iteration_count, uint64_t threshold)
  Type *VoidTy = Type::getVoidTy(Ctx);
  Type *VoidPtrTy = PointerType::getUnqual(Ctx);
  Type *CharPtrTy = PointerType::getUnqual(Ctx);
  Type *Uint64Ty = Type::getInt64Ty(Ctx);

  FunctionType *FT = FunctionType::get(
      VoidTy,
      {VoidPtrTy, CharPtrTy, Uint64Ty, Uint64Ty},
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

    // Insert instrumentation at the beginning of the loop header
    IRBuilder<> Builder(&*LoopHeader->getFirstInsertionPt());

    // Load current counter value
    Value *CurrentCount = Builder.CreateLoad(Type::getInt64Ty(Ctx), Counter, "loop_count");

    // Increment counter
    Value *NewCount = Builder.CreateAdd(CurrentCount, Builder.getInt64(1), "loop_count_inc");

    // Store incremented value
    Builder.CreateStore(NewCount, Counter);

    // Check if threshold exceeded
    Value *ThresholdVal = Builder.getInt64(LOOP_ITERATION_THRESHOLD);
    Value *ExceededThreshold = Builder.CreateICmpUGT(NewCount, ThresholdVal, "exceeds_threshold");

    // Only report once when threshold is first exceeded
    // Check if count == threshold + 1
    Value *ThresholdPlusOne = Builder.getInt64(LOOP_ITERATION_THRESHOLD + 1);
    Value *IsFirstExceedance = Builder.CreateICmpEQ(NewCount, ThresholdPlusOne, "first_exceed");

    Value *ShouldCheckReport = Builder.CreateAnd(ExceededThreshold, IsFirstExceedance, "should_check_report");

    // Split block and insert conditional report
    Instruction *InsertPt = &*Builder.GetInsertPoint();
    Instruction *ThenTerm = SplitBlockAndInsertIfThen(ShouldCheckReport, InsertPt, false);

    Builder.SetInsertPoint(ThenTerm);

    // Call trace2pass_should_sample() to decide if we should report
    FunctionCallee ShouldSampleFunc = getShouldSampleFunc(M);
    Value *ShouldSample = Builder.CreateCall(ShouldSampleFunc);
    Value *ShouldReport = Builder.CreateICmpNE(ShouldSample, Builder.getInt32(0), "should_report");

    // Create another split for the actual report
    Instruction *ReportTerm = SplitBlockAndInsertIfThen(ShouldReport, ThenTerm, false);

    Builder.SetInsertPoint(ReportTerm);

    // Get PC (return address)
    Function *ReturnAddrFn = Intrinsic::getOrInsertDeclaration(&M, Intrinsic::returnaddress);
    Value *PC = Builder.CreateCall(ReturnAddrFn, {Builder.getInt32(0)});

    // Create loop identifier string
    std::string LoopId = F.getName().str() + ":" + LoopHeader->getName().str();
    Value *LoopName = Builder.CreateGlobalString(LoopId, "loop_id");

    // Call: trace2pass_report_loop_bound_exceeded(PC, loop_name, iteration_count, threshold)
    Builder.CreateCall(ReportFunc, {PC, LoopName, NewCount, ThresholdVal});

    Modified = true;
    NumLoopsInstrumented++;
  }

  return Modified;
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
