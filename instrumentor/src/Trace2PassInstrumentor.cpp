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

using namespace llvm;

namespace {

class Trace2PassInstrumentorPass : public PassInfoMixin<Trace2PassInstrumentorPass> {
public:
  PreservedAnalyses run(Function &F, FunctionAnalysisManager &FAM);

private:
  // Instrumentation helper functions
  bool instrumentArithmeticOperations(Function &F);
  void insertOverflowCheck(IRBuilder<> &Builder, Instruction *I,
                           Value *LHS, Value *RHS);

  // Runtime function declarations
  FunctionCallee getOverflowReportFunc(Module &M);

  // Statistics
  unsigned NumInstrumented = 0;
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

  if (Modified) {
    errs() << "Trace2Pass: Instrumented " << NumInstrumented
           << " operations in " << F.getName() << "\n";

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
      // Look for multiply instructions
      if (I.getOpcode() == Instruction::Mul) {
        // Only instrument integer multiplications
        if (I.getType()->isIntegerTy()) {
          ToInstrument.push_back(&I);
        }
      }
      // TODO: Add other arithmetic operations (add, sub, shl, etc.)
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

  // Use LLVM's overflow intrinsic: llvm.smul.with.overflow
  Function *OverflowIntrinsic = Intrinsic::getOrInsertDeclaration(
      &M, Intrinsic::smul_with_overflow, {IntTy});

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

  // Create expression string
  std::string ExprStr = "x * y";  // TODO: Better expression tracking
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
