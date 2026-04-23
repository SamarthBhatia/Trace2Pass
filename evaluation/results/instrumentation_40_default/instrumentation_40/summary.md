# Instrumentation evaluation on the full 40 bugs

Configuration: checks=default, sample_rate=1.0, minimal_mode=0, timeout=30s
Generated: 2026-04-23T22:46:57Z

| Outcome | Count | % of total |
|---|---|---|
| detected   | 2    | 5.1% |
| prevented  | 21   | 53.8% |
| passthrough| 15 | 38.5% |
| no_build   | 1    | 2.6% |
| test_error | 0  | 0.0% |
| **Total**  | **39**   | 100% |

### Involvement rate
detected + prevented = 23 / 39 = 59.0%

### Per-bug verdicts

```
{"bug_id":"59679","verdict":"passthrough","plain_exit":"1","instr_exit":"1","image_kind":"release","culprit":"EarlyCSEPass@32"}
{"bug_id":"116668","verdict":"passthrough","plain_exit":"1","instr_exit":"1","image_kind":"release","culprit":"JumpThreadingPass@71"}
{"bug_id":"127511","verdict":"passthrough","plain_exit":"1","instr_exit":"1","image_kind":"release","culprit":"SROAPass@76"}
{"bug_id":"175018","verdict":"passthrough","plain_exit":"1","instr_exit":"1","image_kind":"release","culprit":"SimplifyCFGPass@140"}
{"bug_id":"76789","verdict":"passthrough","plain_exit":"0","instr_exit":"0","image_kind":"custom","culprit":"LICMPass@429"}
{"bug_id":"72831","verdict":"passthrough","plain_exit":"0","instr_exit":"0","image_kind":"custom","culprit":"DSEPass@222"}
{"bug_id":"119173","verdict":"prevented","plain_exit":"1","instr_exit":"0","image_kind":"custom","culprit":"LoopVectorizePass@87"}
{"bug_id":"80113","verdict":"prevented","plain_exit":"1","instr_exit":"0","image_kind":"custom","culprit":"ReassociatePass@88"}
{"bug_id":"94897","verdict":"prevented","plain_exit":"134","instr_exit":"0","image_kind":"custom","culprit":"InstCombinePass@67"}
{"bug_id":"124275","verdict":"passthrough","plain_exit":"134","instr_exit":"134","image_kind":"custom","culprit":"InstCombinePass@14"}
{"bug_id":"63996","verdict":"prevented","plain_exit":"1","instr_exit":"0","image_kind":"custom","culprit":"Early Tail Duplication@480"}
{"bug_id":"64598","verdict":"prevented","plain_exit":"139","instr_exit":"0","image_kind":"custom","culprit":"GVNPass@273"}
{"bug_id":"115149","verdict":"passthrough","plain_exit":"124","instr_exit":"124","image_kind":"custom","culprit":"DSEPass@196"}
{"bug_id":"122496","verdict":"prevented","plain_exit":"124","instr_exit":"0","image_kind":"custom","culprit":"LoopVectorizePass@340"}
{"bug_id":"129244","verdict":"prevented","plain_exit":"3","instr_exit":"0","image_kind":"custom","culprit":"SLPVectorizerPass@384"}
{"bug_id":"85536","verdict":"passthrough","plain_exit":"128","instr_exit":"128","image_kind":"custom","culprit":"InstCombinePass@445"}
{"bug_id":"70547","verdict":"prevented","plain_exit":"192","instr_exit":"0","image_kind":"custom","culprit":"SimplifyCFGPass@274"}
{"bug_id":"140481","verdict":"prevented","plain_exit":"134","instr_exit":"0","image_kind":"custom","culprit":"ConstraintEliminationPass@32"}
{"bug_id":"62992","verdict":"prevented","plain_exit":"136","instr_exit":"0","image_kind":"custom","culprit":"IndVarSimplifyPass@45"}
{"bug_id":"181103","verdict":"passthrough","plain_exit":"127","instr_exit":"127","image_kind":"release","culprit":"LICMPass@203"}
{"bug_id":"164617","verdict":"no_build","reason":"custom_image_missing"}
{"bug_id":"166496","verdict":"passthrough","plain_exit":"1","instr_exit":"1","image_kind":"release","culprit":"IndVarSimplifyPass@79"}
{"bug_id":"116483","verdict":"passthrough","plain_exit":"0","instr_exit":"0","image_kind":"release","culprit":"IndVarSimplifyPass@265"}
{"bug_id":"87534","verdict":"passthrough","plain_exit":"0","instr_exit":"0","image_kind":"release","culprit":"InlinerPass@49"}
{"bug_id":"79743","verdict":"passthrough","plain_exit":"0","instr_exit":"0","image_kind":"release","culprit":"SLPVectorizerPass@374"}
{"bug_id":"124387","verdict":"passthrough","plain_exit":"1","instr_exit":"1","image_kind":"custom","culprit":"InstCombinePass@251"}
{"bug_id":"121110","verdict":"prevented","plain_exit":"1","instr_exit":"0","image_kind":"custom","culprit":"VectorCombinePass@235"}
{"bug_id":"129181","verdict":"detected","plain_exit":"1","instr_exit":"0","image_kind":"release","culprit":"LoopFullUnrollPass@56"}
{"bug_id":"69097","verdict":"prevented","plain_exit":"124","instr_exit":"0","image_kind":"custom","culprit":"InstCombinePass@184"}
{"bug_id":"62660","verdict":"prevented","plain_exit":"124","instr_exit":"0","image_kind":"custom","culprit":"Loop Strength Reduction@192"}
{"bug_id":"58340","verdict":"prevented","plain_exit":"1","instr_exit":"0","image_kind":"custom","culprit":"IndVarSimplifyPass@145"}
{"bug_id":"54112","verdict":"prevented","plain_exit":"136","instr_exit":"0","image_kind":"custom","culprit":"LoopSimplifyCFGPass@69"}
{"bug_id":"57899","verdict":"prevented","plain_exit":"1","instr_exit":"0","image_kind":"custom","culprit":"InstCombinePass@123"}
{"bug_id":"64333","verdict":"prevented","plain_exit":"124","instr_exit":"0","image_kind":"custom","culprit":"InstCombinePass@443"}
{"bug_id":"64345","verdict":"prevented","plain_exit":"1","instr_exit":"0","image_kind":"custom","culprit":"JumpThreadingPass@57"}
{"bug_id":"82243","verdict":"prevented","plain_exit":"139","instr_exit":"0","image_kind":"custom","culprit":"GVNPass@160"}
{"bug_id":"64060","verdict":"prevented","plain_exit":"1","instr_exit":"0","image_kind":"custom","culprit":"Early Machine Loop Invariant Code Motion@411"}
{"bug_id":"60944","verdict":"detected","plain_exit":"136","instr_exit":"136","image_kind":"custom","culprit":"IndVarSimplifyPass@124"}
{"bug_id":"63327","verdict":"prevented","plain_exit":"1","instr_exit":"0","image_kind":"custom","culprit":"InstCombinePass@14"}
```
