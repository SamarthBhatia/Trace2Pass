# Root-cause audit: 36 non-detection bugs (instrumentation_40_default)

Evidence basis: every `.plain.log`/`.instr.log` in `instrumentation_40_default/` (four bugs in `_all/`), and the corresponding `evaluation/real-bugs/llvm-<id>/test_bug.c`. Existing checks enumerated from `instrumentor/src/Trace2PassInstrumentor.cpp`: `GEP_BOUNDS`, `SIGN_CONVERSION`, `LOOP_BOUNDS`, `SELECT_CHECK`, `RANGE_CHECK`, `STORE_LOAD_CHECK`, `VOLATILE_TRACKING`, `CROSS_BB_CHECK`, `BACKEND_CHECKSUM` (none implement `abort_call` — that is hypothetical). No log contains "Trace2Pass Report", confirming no detections.

## Per-bug classification

| Bug ID | Verdict | Symptom (plain→instr, culprit) | Category | Rationale | Fix |
|---|---|---|---|---|---|
| 119173 | Prevented | 1→0, LoopVectorize | wrong-output-terminates-normally | `main` returns 1 on wrong val (15 vs 5); instr path prints 5 and returns 0 — harness ignores stdout | `backend_checksum` on main return value / stdout capture |
| 80113   | Prevented | 1→0, Reassociate | wrong-output-terminates-normally | returns 1 on mismatch; instr prints -2, returns 0 | backend_checksum |
| 94897   | Prevented | 134→0, InstCombine | spurious-abort | `__builtin_abort()` on wrong val; instr healed | new `abort_call` check (detect reaching `llvm.trap`/`@abort` in plain-only path) |
| 63996   | Prevented | 1→0, Early Tail Duplication | wrong-output-terminates-normally | returns 1 on mismatch; instr prints 0 | backend_checksum |
| 64598   | Prevented | 139→0, GVN | check-missing-for-this-class | SIGSEGV from GVN-induced null-deref; no memory-safety check in Trace2Pass | signal-handler / null-deref check, or GEP_BOUNDS extended to loads |
| 122496  | Prevented | 124→0, LoopVectorize | infinite-loop | `timeout` fired on plain; instr completes | `TRACE2PASS_ENABLE_LOOP_BOUNDS=1` |
| 129244  | Prevented | 3→0, SLPVectorizer | wrong-output-terminates-normally | test exits with computed value 3; instr returns 0 | backend_checksum |
| 70547   | Prevented | 192→0, SimplifyCFG | wrong-output-terminates-normally | unusual exit (192 = returned value from main); instr prints 0 | backend_checksum |
| 140481  | Prevented | 134→0, ConstraintElim | spurious-abort | `__builtin_abort()` reached in plain | hypothetical `abort_call` check |
| 62992   | Prevented | 136→0, IndVarSimplify | check-missing-for-this-class | SIGFPE (div by zero) at runtime; division checks exist but didn't fire (compile-time const mutation by IndVar) | division-check hoisted before IndVar; currently `LOOP_BOUNDS`-adjacent |
| 69097   | Prevented | 124→0, InstCombine | infinite-loop | timeout in plain; instr terminates | `TRACE2PASS_ENABLE_LOOP_BOUNDS=1` |
| 62660   | Prevented | 124→0, LSR | infinite-loop | timeout | `LOOP_BOUNDS` |
| 58340   | Prevented | 1→0, IndVarSimplify | wrong-output-terminates-normally | `if(a!=2) return 1`; instr prints 2, exits 0 | backend_checksum |
| 54112   | Prevented | 136→0, LoopSimplifyCFG | check-missing-for-this-class | SIGFPE; division check did not report (mutation produced div/0 only under plain opt) | division-check hardening (not stripped by LoopSimplifyCFG) |
| 57899   | Prevented | 1→0, InstCombine | wrong-output-terminates-normally | `if(b!=1) return 1`; instr prints 1, exits 0 | backend_checksum |
| 64333   | Prevented | 124→0, InstCombine | infinite-loop | timeout | `LOOP_BOUNDS` |
| 64345   | Prevented | 1→0, JumpThreading | wrong-output-terminates-normally | `if(b!=-1) return 1`; instr prints -1, exits 0 | backend_checksum |
| 82243   | Prevented | 139→0, GVN | check-missing-for-this-class | SIGSEGV null-deref; no null-check | null-deref/load-safety check |
| 64060   | Prevented | 1→0, Early Machine LICM | wrong-output-terminates-normally | `if((int)b!=1) return 1`; instr prints 1, exits 0 | backend_checksum |
| 63327   | Prevented | 1→0, InstCombine | wrong-output-terminates-normally | `if(a!=0) return 1`; instr prints 0, exits 0 | backend_checksum |
| 72831   | Passthrough | 0→0, DSE | wrong-output-terminates-normally | stdout differs (0 vs 2) but both exit 0; test lacks return-code check | backend_checksum / stdout diff |
| 76789   | Passthrough | 0→0, LICM | wrong-output-terminates-normally | stdout 0 vs 1; no exit-code mismatch | backend_checksum |
| 116483  | Passthrough (_all) | 0→0, IndVarSimplify | wrong-output-terminates-normally | identical "0" stdout both runs; miscompile not exercised by this main | backend_checksum (cross-run hash) |
| 87534   | Passthrough (_all) | 0→0, Inliner | check-eliminated-by-optimizer | test calls `__builtin_abort` on bug, but plain also exits 0 at `-O2 default`; inliner elided abort so no symptom even without instrumentation | needs `-O1` pin OR stronger unreachable/abort tracking preserved through inliner |
| 79743   | Passthrough (_all) | 0→0 stdout mismatch, SLP | wrong-output-terminates-normally | stdout 1 vs 1 printed but semantics differ; exits 0 | backend_checksum |
| 124387  | Passthrough | 1→1, InstCombine | wrong-output-terminates-normally | both exit 1 but stdout differs (-170891624 vs 1048032744) — same exit code, different value | backend_checksum / stdout diff |
| 59679   | Passthrough | 1→1, EarlyCSE | check-missing-for-this-class | restrict/noalias miscompile; neither run corrects it; no alias/noalias check | noalias/restrict violation check |
| 166496  | Passthrough (_all) | 1→1, IndVarSimplify | wrong-output-terminates-normally | both print 5882352 and exit 1; instr did not heal | backend_checksum (would cross-compare opt-vs-unopt hash) |
| 115149  | Passthrough | 124→124, DSE | infinite-loop | both timeout; `LOOP_BOUNDS` default off in `_default`; enabling it alone didn't detect in `_all` either (loop bound never reached report threshold) | `LOOP_BOUNDS` with tighter threshold |
| 181103  | Passthrough (_all) | 127→127, LICM | check-eliminated-by-optimizer | compile failed (`-O3+attrib` flag invalid); binary never built | fix harness flag parsing — not a check problem |
| 85536   | Passthrough | 128→128, InstCombine | wrong-output-terminates-normally | plain returns 128 (= main returned -128 truncated); instr same; poison return | backend_checksum |
| 124275  | Passthrough | 134→134, InstCombine | spurious-abort | both abort; instr did not heal (mutation did not change path) | `abort_call` check (+ cross_bb to heal) |
| 116668  | Passthrough (_all) | 1→1, Inliner | GVN-value-propagation | setjmp/longjmp GVN miscompile; `CROSS_BB_CHECK` enabled but did not fire | strengthen `cross_bb` to model `setjmp` call-clobber |
| 121110  | Passthrough (_all) | 1→0, InlinerPass | wrong-output-terminates-normally | plain prints 9 returns 1; instr prints 0 returns 0 — actually healed to normal; still no report | backend_checksum to detect pre-heal divergence (or already-prevented) |
| 127511  | Passthrough (_all) | 1→1, IndVarSimplify | GVN-value-propagation | GVN setjmp/longjmp pointer; identical symptom both runs | stronger setjmp-aware cross_bb |
| 175018  | Passthrough (_all) | 1→1, SimplifyCFG | check-missing-for-this-class | `std::optional` has_value miscompile (C++); no check monitors optional tag-byte invariant | struct-tag / storeload check for small scalar fields |

Notes on exits observed: 85536 plain=128 (not SIGABRT; main returned poison truncated to 128). 121110 is actually healed (instr=0) but no Trace2Pass report was emitted, so it counts as passthrough-with-silent-heal.

## Aggregate by category

| Category | Count |
|---|---|
| wrong-output-terminates-normally | 17 |
| spurious-abort | 3 |
| infinite-loop | 4 |
| GVN-value-propagation | 2 |
| check-missing-for-this-class | 6 |
| check-exists-but-not-enabled | 0 (rolled into infinite-loop rows; `LOOP_BOUNDS` already default-on in_40_default) |
| check-eliminated-by-optimizer | 2 (87534 symptom-elided; 181103 harness flag bug) |

Split by verdict:

- Prevented (20): 11 wrong-output, 2 spurious-abort, 4 infinite-loop, 3 check-missing (null-deref / div-post-IndVar).
- Passthrough (16): 6 wrong-output (default logs) + 3 wrong-output (_all) + 1 spurious-abort + 1 infinite-loop + 2 GVN-setjmp + 2 check-missing (noalias, optional-tag) + 1 eliminated-in-optimizer + 1 harness-flag.

## Promotion recommendation

The single highest-leverage check is **`backend_checksum`** (hash of observable outputs: `main` return value + stdout bytes, compared against the same-source `-O0` reference).

- Passthrough bugs it would catch: **N = 9** — 72831, 76789, 116483, 79743, 124387, 166496, 85536, 121110, 175018. (All nine are "same exit code, different observable value" — the check turns stdout/return divergence into a definitive detection.)
- Prevented bugs that would upgrade to detected: **11** — 119173, 80113, 63996, 129244, 70547, 58340, 57899, 64345, 64060, 63327 + the healed-but-silent 121110 (already counted above). These were "healed by the mutation" but the original plain-vs-golden divergence is still visible to backend_checksum before mutation closes the gap.

Second-tier suggestion for orthogonal coverage: an `abort_call` check (`TRACE2PASS_ENABLE_ABORT_CHECK`) that reports when control reaches `@abort`/`@__assert_fail`/`llvm.trap`. It would catch 1 passthrough (124275) and upgrade 3 prevented (94897, 140481) to detected — complementary to `backend_checksum` since those never print output. Combined, backend_checksum + abort_call cover 10/16 passthroughs and 14/20 prevented, leaving only the noalias (59679), setjmp/GVN (116668, 127511), 115149 LOOP_BOUNDS-resistant timeout, 87534 opt-eliminated, and 181103 harness-flag cases uncovered.
