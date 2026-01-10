/*
 * LLVM Bug #165077: M68k miscompilation - move immediate to SR generates wrong assembly
 * https://github.com/llvm/llvm-project/issues/165077
 *
 * Version: LLVM M68k backend
 * Status: FIXED
 * Pass: M68k backend code generation
 *
 * Expected: move.w #0x2700,%sr (set status register)
 * Actual:   move.w #9984,%d0 (writes to data register instead)
 *
 * Root Cause: M68k backend incorrectly codegen inline asm with SR register
 * SR (status register) replaced with D0 (data register)
 *
 * Compile: clang --target=m68k -S llvm-165077.c
 * Godbolt: https://godbolt.org/z/eMh7qWz6G
 */

/* Example usecase: Disabling interrupts by setting interrupt mask bits of SR to 7 */
void disable_interrupts() {
    /* BUG: Backend generates "move.w #9984,%d0" instead of "move.w #0x2700,%sr" */
    __asm__("move.w #0x2700,%sr");
}

/*
 * IR (correct):
 * define dso_local void @disable_interrupts() {
 * entry:
 *   call void asm sideeffect "move.w #0x2700,%sr", ""()
 *   ret void
 * }
 *
 * Expected assembly:
 * disable_interrupts:
 *   link.w  %a6, #0
 *   move.w  #0x2700, %sr    ; Set status register
 *   unlk    %a6
 *   rts
 *
 * Buggy assembly (actual):
 * disable_interrupts:
 *   link.w  %a6, #0
 *   move.w  #9984, %d0      ; BUG: Writes to D0 instead of SR!
 *   unlk    %a6
 *   rts
 *
 * 0x2700 = 9984 decimal
 * SR = status register (controls interrupts, flags)
 * D0 = data register (general purpose)
 *
 * Workaround: Move via temporary register
 * asm("move.w #0x2700,%d0; move.w %d0,%sr");
 *
 * Originally from Rust code setting interrupt level
 */
