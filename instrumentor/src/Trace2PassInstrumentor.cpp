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

  // Statistics
  unsigned NumInstrumented = 0;
  unsigned NumUnreachableInstrumented = 0;
  unsigned NumGEPInstrumented = 0;
  unsigned NumSignConversionInstrumented = 0;
  unsigned NumDivisionByZeroInstrumented = 0;
  unsigned NumPureCallsInstrumented = 0;
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

  // Select the appropriate overflow intrinsic based on operation
  Intrinsic::ID IntrinsicID;
  const char *OpName;

  switch (I->getOpcode()) {
    case Instruction::Mul:
      IntrinsicID = Intrinsic::smul_with_overflow;
      OpName = "mul";
      break;
    case Instruction::Add:
      IntrinsicID = Intrinsic::sadd_with_overflow;
      OpName = "add";
      break;
    case Instruction::Sub:
      IntrinsicID = Intrinsic::ssub_with_overflow;
      OpName = "sub";
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

  // Create a new basic block for the overflow handler
  BasicBlock *OverflowBB = BasicBlock::Create(Ctx, "overflow_detected",
                                               I->getFunction());
  BasicBlock *ContinueBB = BasicBlock::Create(Ctx, "continue",
                                               I->getFunction());

  // Split the current basic block
  BasicBlock *CurrentBB = I->getParent();

  // Branch based on overflow flag
  Builder.CreateCondBr(OverflowFlag, OverflowBB, ContinueBB);

  // Fill in the overflow handler block
  Builder.SetInsertPoint(OverflowBB);

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

  // Create basic blocks
  BasicBlock *InvalidShiftBB = BasicBlock::Create(Ctx, "invalid_shift",
                                                   I->getFunction());
  BasicBlock *ContinueBB = BasicBlock::Create(Ctx, "continue",
                                               I->getFunction());

  // Branch based on validity
  Builder.CreateCondBr(IsInvalid, InvalidShiftBB, ContinueBB);

  // Fill in the invalid shift handler
  Builder.SetInsertPoint(InvalidShiftBB);

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
    IRBuilder<> Builder(UI);

    // Get the runtime report function
    FunctionCallee ReportFunc = getUnreachableReportFunc(M);

    // Get PC (return address)
    Function *ReturnAddrIntrinsic = Intrinsic::getOrInsertDeclaration(
        &M, Intrinsic::returnaddress);
    Value *PC = Builder.CreateCall(ReturnAddrIntrinsic,
                                    {Builder.getInt32(0)});

    // Create message string
    std::string Message = "unreachable code executed";
    Value *MessageGlobal = Builder.CreateGlobalString(Message);

    // Call the report function before the unreachable instruction
    Builder.CreateCall(ReportFunc, {PC, MessageGlobal});

    // Note: We don't remove the unreachable instruction itself
    // If code reaches here, report will be called, then unreachable will abort

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
    BasicBlock *ViolationBB = BasicBlock::Create(Ctx, "bounds_violation",
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

    Builder.CreateCondBr(IsNegative, ViolationBB, ContinueBB);

    // Fill in the violation handler
    Builder.SetInsertPoint(ViolationBB);

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

    // Now insert the report call in the "then" block
    Builder.SetInsertPoint(ThenTerm);

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
    // This creates: if (divisor == 0) { report(); } then continue with division
    Instruction *ThenTerm = SplitBlockAndInsertIfThen(IsZero, DivOp, false);

    Builder.SetInsertPoint(ThenTerm);

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
