# MCT-COMBAT-DEEPEN-01 / WT-CD-016 evidence: benchmark matrix, two-vehicle sample package and independent delivery

Status: **OPEN at stage zero**. This document records the pickup check and the measured inventory. Nothing here is an implementation claim yet, and no case is claimed until it is measured.

## 1. The order and its six cases, read from the read-only original

Extracted verbatim into `logs/COMBAT-DEEPEN-01/cd016_order_extract.md` by `logs/COMBAT-DEEPEN-01/extract_cd016.js`, which reads `original/07_WORK_ORDERS.json` and `original/08_ACCEPTANCE_CASES.json` rather than retyping them.

```
WT-CD-016 对标矩阵、两车完成样片与独立交付   priority P1出口   phase G4   status planned
depends_on : WT-CD-001 .. WT-CD-015 (all fifteen)
sources    : R11, W01, W02, W03, W04, W05, W06, W07
```

| case | title | action | expected |
|---|---|---|---|
| **CD16-T01** | 版本锁定与证据完整性 | 从明确集成提交生成包并核对全部identity | 源码/内容/规则/包身份能追溯，UNKNOWN exit和脚本错误拒收 |
| **CD16-T02** | 两车入口与配装 | 正常UI分别选择T-80B和豹2A4进入河谷 | 实际车型/弹药/模型/布局一致，缺必需资源不能降级 |
| **CD16-T03** | 正常完整对局 | 正常操作/可记录AI按冻结规则完成一局再开一局 | 真实票池/伤害/恢复/终局，下一局无旧事件污染 |
| **CD16-T04** | 同生命实弹再出击 | 从包内受控实弹夹具产生玩家阵亡并正常点击 | 死亡/扣票/新生命配置/可驾驶可开火连续有证据 |
| **CD16-T05** | 历史与开放舱兼容 | 运行旧AP/APHE回归和新HE代表场景 | 旧规则不被静默改写，新HE对标按本次版本声明 |
| **CD16-T06** | 关闭重启和独立路径 | 新目录启动、保存、关闭、独立进程重启 | 配装/研究/设置按版本恢复，不读开发目录补资源 |

Rejection conditions, verbatim: `把文件数量或PASS数当相似度` · `同一项目检查器自证战雷一致` · `必需工程车缺资源后换训练车通过` · `未运行的最终包套用旧包证据`.

Four deliverable classes are named by the order: the two-vehicle modern river-valley internal package with its manifest and hashes; the benchmark matrix together with the NOT_COMPARED items; the evidence index for the full match, the special fixtures and the restart; and the known issues, old-save migration and rollback statement.

## 2. Stage zero pickup check: the fifteen prerequisites, measured rather than remembered

```
The state below is read from docs/wt/continuation/COMBAT_DEEPEN01_CASE_COVERAGE.json, which was regenerated
from DISK at the CD15 close (fifty four cases COMPLETE, thirty six EVIDENCE_RECORDED, six NOT_RUN):
   CD07 .. CD15 : COMPLETE, a result file with six executed cases each, plus an evidence document and runners;
   CD01 .. CD06 : EVIDENCE_RECORDED, an evidence document and no result file.
An evidence document is the form the user ACCEPTED for CD03, CD04 and CD06 during the CD15 stage zero ruling,
and CD01, CD02 and CD05 carry the same form. That acceptance is applied to those three as well rather than
treated as a fresh gap, and it is stated here so the reasoning is auditable: the ruling accepted the FORM,
and the same form is what these three already carry.
The coverage table is the authority for this check and it says so in its own note, so no separate survey was
run for it - which is exactly what the order implementation step one asks for (maintain the matrix as each
sub-order closes, and do not open a new round of file hunting at the end).
CONCLUSION: the pickup is complete, and CD016 opens.
```

## 3. The five named sources, read by actual path and measured

```
tests/build_release.ps1          248 lines   builds a package from a COMMITTED snapshot, excludes tracked edits,
                                             requires a Windows release export template, writes into a run folder
tests/run_suite_checks.ps1       103 lines   the suite runner
tests/run_modern_player_flow.ps1  68 lines   the modern player flow runner
tests/run_player_flow_checks.ps1  73 lines   the ordinary player flow runner
docs/wt/continuation/                       the entry documents, whose index is this file own folder
```
So all five exist and are substantial; none of them is missing and no path had to be guessed.

## 4. Required content, measured on disk

```
TWO MODERN ENGINEERING VEHICLES, the ones the order names by name:
  configs/vehicles/engineering/ussr_t_80b.json          238360 bytes  armour + 10 modules + drive_profile +
                                                                       compatible_shells + shell_catalog +
                                                                       assembly + geometry + model_binding + 5 sources
  configs/vehicles/engineering/germ_leopard_2a4.json    183977 bytes  armour + 11 modules + drive_profile +
                                                                       compatible_shells + shell_catalog +
                                                                       assembly + geometry + model_binding + 4 sources
HISTORICAL REGRESSION VEHICLES, the AP/APHE and open-top half:
  us_m4a3_75w_vvss_1944.json 28684   us_m24_m6_t85e1_1951.json 27563
  us_m26_m3_1945.json        29241   us_m36_m4a1_1945.json     29453
THE RIVER VALLEY AND THE NORMAL ENTRY:
  14 scripts under scripts/maps named river*, 13 river test suites, scenes/maps/map_river_team.tscn,
  scenes/maps/river_junction_range.tscn, scenes/battle/team_range.tscn, scenes/app.tscn, scenes/main.tscn
THE PACKAGE PATH:
  export_presets.cfg carries five presets including "Windows Release"; the 4.7.2.stable windows release template
  is installed at %APPDATA%/Godot/export_templates/4.7.2.stable/windows_release_x86_64.exe (109268480 bytes);
  tests/package_doc_names.json carries the package document names; logs/WT040-package already holds a prior run.
```
So the content the order requires for its two-vehicle package is present, and the build path exists end to end.

## 5. The one deliverable that does NOT exist yet, named before any work starts

```
THE BENCHMARK MATRIX IS NOT BUILT. docs/wt/continuation holds no BENCHMARK file at all; the only matrix-like
documents are the ZONE matrix, the FINAL coverage matrix and the shell/armour matrix, none of which is the
external comparison matrix this order asks for. The package ships a READ-ONLY template,
original/10_BENCHMARK_MATRIX_TEMPLATE.json, with four evidence levels (SOURCE_RULE, PROJECT_FIXTURE,
WT_BEHAVIOR_COMPARISON, HUMAN_PLAYTEST), a per-case schema that binds the War Thunder build, mode, vehicle
variant, shell, crew condition, source and time of capture against the project tested_sha, package hash, rules
version and conditions, and one known reference conflict (REF-CREW-01, the crew chapter text against its own
table).
So the matrix is stage one of this sub-order: filled from what the fifteen closed sub-orders actually measured,
with every external row that has no capture left NOT_COMPARED, and with no percentage invented. NO external
comparison has been performed by this agent and none is claimed.
```

## 6. The next stage, stated before it starts

```
1. STAGE ONE - baseline and the dependency graph: the fifteen closed sub-orders are the dependencies and the
   matrix is built from their measured results rather than from a new search, as the order implementation step
   one requires.
2. STAGE TWO - contract first: the four deliverable classes and the four rejection conditions are written down
   as the contract the package must satisfy, before any package is built, so that a missing required resource
   FAILS rather than being downgraded to a training vehicle - which the order rejects by name.
3. STAGE THREE onward - the cases in the order implementation step order: the short gates first, then the
   two-vehicle entry, the normal full match, the same-life live-fire re-sortie, the historical and open-top
   regression, and finally the close and restart from an independent directory.
4. NOTHING IS CLAIMED YET. release_ready=false, public_release=false, human=PENDING, performance=HOLD_BY_USER,
   and the evidence state stays the engineering self-consistent version only.
```
## 7. Stage one DONE: the benchmark matrix is built from measurement, and its external half is empty on purpose

```
WHAT WAS BUILT
   docs/wt/continuation/COMBAT_DEEPEN01_BENCHMARK_MATRIX.json  (122674 bytes before the no-row section was added)
   docs/wt/continuation/COMBAT_DEEPEN01_BENCHMARK_MATRIX.md    (the rendered tables)
   built by logs/COMBAT-DEEPEN-01/build_cd016_matrix.js, which reads the READ-ONLY template, the migration
   table, the coverage mirror, the divergence register and the commit map, and REFUSES TO WRITE when any of its
   eight shape assertions fail.

THE SHAPE, MEASURED
   rows                      31, one per migration entry, so every row is a rule that the package actually changed
   evidence_level            SOURCE_RULE 5, PROJECT_FIXTURE 26
   WT_BEHAVIOR_COMPARISON    0
   HUMAN_PLAYTEST            0
   similarity percentage     none given, and the summary says a row count or a pass count is not a similarity
   dependencies bound        15 of 15, each to the commit that last touched its evidence document (and to its
                             result commit where the order delivered one), twelve distinct tested commits
   not-compared items        41, listed individually rather than implied
   sub-orders with no row    4, each with a stated reason: CD001 and CD002 deliver geometry and CD006 delivers the
                             post-penetration, fuze and fragment behaviour, so none of the three changed a rule;
                             CD016 is the delivery itself and its rows arrive with its own six cases
   every row carries         war_thunder.game_build null, mode Ground Realistic Battles (normal mode), variant, shell,
                             crew and capture null, expected_reference null, tolerance_predeclared null, and a
                             limitation that names the absent external capture

WHAT IT DELIBERATELY DOES NOT DO
   It does not carry a percentage, it does not treat a project fixture as evidence about War Thunder, and it does
   not fill conditions from an internal run. Every external field is null and every row says NOT_COMPARED, which
   is the only honest state while no capture of any external title exists.

TWO DEVICE FAULTS OF MINE, BOTH FOUND BY MEASURING RATHER THAN BY LUCK, AND BOTH NAMED
   1. THE THREE-DIGIT AGAINST TWO-DIGIT NAMING TRAP BIT THIS GENERATOR TOO, for the third time in this session
      and this time in a way the previous two did not cover: packaged ORDER ids carry three digits (WT-CD-001)
      while the coverage mirror and the commit map address sub-orders with two (CD01), so deriving the mirror key
      by string replacement produced CD001 and the first run wrote a dependency graph of fifteen UNKNOWN rows with
      NULL shas. The generator now maps explicitly and its shape check asserts all fifteen dependencies are bound
      to a forty character commit before it will write anything.
   2. A POWERSHELL STRING-SURGERY PASS OVER THE GENERATOR ITSELF RE-ENCODED IT AND DESTROYED ITS TEXT. The lesson
      this session had already recorded twice - edit text with the file tools, not with PowerShell - was applied
      to product files and not to a helper script, and the helper was the thing that broke. The file was rewritten
      whole, and the broken one removed rather than left beside its replacement.

STATE: the matrix is built and bound; the package, the two-vehicle entry, the full match, the live-fire re-sortie,
the historical and open-top regression and the independent restart are NOT_RUN and are the remaining stages.
release_ready=false, public_release=false, human=PENDING, performance=HOLD_BY_USER.
```
## 8. Stage two DONE: the contract is written BEFORE the package exists, and it is checkable

```
docs/wt/continuation/COMBAT_DEEPEN01_CD016_CONTRACT.md states, before anything is built:
   the four deliverable classes the order names, each with the GATE that proves it and the FAILURE if it is absent;
   the four rejection conditions, each with the check that must FAIL the package when it is violated;
   the required content, with the rule that a missing required item is a recorded FAILURE and never a substitution;
   the gate order G0 to G5 from the shortest gate to the independent restart, one line per case;
   the identity binding, including that the evidence commit is SEPARATE from the tested commit and that the four
   standing flags may not be flipped by this sub-order;
   and the out-of-scope list, so that this sub-order integrates and delivers rather than inventing new rules.

IT IS CHECKABLE RATHER THAN ASPIRATIONAL
   logs/COMBAT-DEEPEN-01/check_cd016_contract.js verifies it against DISK and against the READ-ONLY packaged
   order: 31 checks, all passing. It confirms that each of the six sections exists, that the twelve required
   content paths really exist, that the two byte counts the contract quotes match the files on disk exactly, that
   the four rejection conditions are quoted verbatim from the packaged order rather than paraphrased, that all
   four packaged deliverables are named, that the four standing flags are declared and unchanged, and that the
   six case ids appear in gate order.
   A contract whose numbers do not match disk is worse than no contract, which is why the size check compares
   against the filesystem rather than against the inventory note it was copied from.

ONE CORRECTION IT CAUGHT, RECORDED BECAUSE IT IS THE POINT OF WRITING THE CHECK
   The first run failed on one of its own assertions: the first deliverable was written as
   "两车现代河谷内部开发包及 manifest/hashes" with a space inserted before the Latin word, while the packaged
   order says "两车现代河谷内部开发包及manifest/hashes". The check compares against the packaged string, so the
   contract now quotes the order verbatim. A paraphrased requirement is exactly the kind of quiet drift this
   package keeps punishing.

STATE: the contract is written and verified; the package build and the six cases are the remaining stages, and
nothing in the contract is a result. release_ready=false, public_release=false, human=PENDING,
performance=HOLD_BY_USER.
```
## 9. Stage three BLOCKED: the package build ran to the register gate and STOPPED, and the gate found reds thirteen sub-order slices never saw

```
WHAT WAS RUN, verbatim
   & .\tests\build_release.ps1 -Candidate -ModernRiver -CommittedSnapshot
   from E:\AIprogram\mcthunder-cont at HEAD 6c945fb263b23b80b69ae1fa5124b0a5e213bbf0, with a clean tracked
   tree, the fixed engine 4.7.2.stable.official.ed1daf0bf and the installed release template.
   Raw output: logs/COMBAT-DEEPEN-01/c16pkg-build.txt ; run directory
   backups/builds/031/6c945fb2.../20260919-122619-427 ; logs logs/031/6c945fb2.../build-20260919-122619-427.

WHAT IT DID, IN ORDER
   fresh_import                 exit 0, exit_known true, timed_out false, passed TRUE - the committed snapshot
                                imports reproducibly from a clean source with no cache (143330 bytes of log)
   committed-source.zip         522687403 bytes extracted into clean-source
   regression                   53 recorded rows, run to completion, then the register gate
   export_release               NEVER RAN
   independent_* checks         NEVER RAN
   package directory            EMPTY, zero files: THERE IS NO PACKAGE

THE AUTHORITATIVE STOP MESSAGE (build_release.ps1:177)
   Candidate build refuses an UNREGISTERED failing suite: run_checks - add it to the register only after the
   failure is understood and recorded

FIVE FAILING SUITES, COMPARED AGAINST TWO EARLIER CLEAN BUILDS RATHER THAN CALLED OLD OR NEW BY GUESS
   suite                          this build         2026-09-17          2026-09-16
   run_checks                     FAIL (1 [FAIL])    PASS (177 pass)     PASS (217 checks)
   run_village_battle_checks      FAIL (1 [FAIL])    PASS (21 checks)    PASS (21 checks)
   run_industrial_battle_checks   FAIL timed out     FAIL registered     FAIL registered
   run_challenge_checks           FAIL registered    FAIL registered     FAIL registered
   run_engineering_runtime_checks FAIL (1 [FAIL])    PASS (44 checks)    (suite added since)
   Everything else passed, including all twelve modern river suites.

THE FOUR DISTINCT CAUSES, EACH MEASURED AND EACH REPRODUCED IN THE WORKING TREE

   1. IN SCOPE, AND CAUSED BY THIS PACKAGE - a stale manifest expectation:
      [FAIL] ussr_t_80b: the packet carries exactly two authored rounds and a default
      tests/run_engineering_runtime_checks.gd line 53 asserts shells.size()==2 for BOTH engineering packets and
      returns early when it is not two, which is why the suite drops from 44 checks to 26.
      MEASURED: the T-80B packet now declares THREE authored rounds -
        eng_125_apfsds_v1 APFSDS long_rod (the default), eng_125_heat_v1 HEAT chemical, and
        eng_125_he_v1 HE he_blast - while the Leopard still declares exactly two.
      ATTRIBUTED: the HE round was added by commit 37afe1a9, "MCT-COMBAT-DEEPEN-01 CD07: the engineering HE is
      landed and the tree is green, with the loadout consequence handled". CD07 migrated the LOADOUT consequence
      (the edited_loadout_total expectation migration) but NOT this manifest assertion, and CD07 own green slice
      never ran this suite, so the red survived every sub-order close and was caught only by the package gate.
      This is the order own requirement working: new rules must be re-bound to the same source, content and
      package verification, and a sub-order own fixtures are not the integration gate.
      Reproduced in the working tree: exit 1, 26 checks, the same single failure, in 2 seconds.

   2. NEW BEHAVIOURAL RED, CAUSE NOT YET ATTRIBUTED - village AI arrival:
      [FAIL] all seven autonomous actors leave spawn and reach central approaches: ["A4", "B", "A3", "B4", "B2"]
      21 checks, 1 failed; the same suite passed with 0 failures on 2026-09-17 and 2026-09-16.
      Reproduced in the working tree: exit 1 after 319 s, identical failure and identical actor list.
      NOT YET ATTRIBUTED, and the candidate causes are named rather than guessed: this package changed
      scripts/ai/ai_perception.gd (CD004: the fire-lane prediction now integrates the profile-aware advance),
      scripts/ai/ai_tank_controller.gd, scripts/drive/drive_profile.gd, scripts/tank.gd, scripts/gunner.gd and
      scripts/battle/team_range.gd - nineteen production files in all between 15026f1a and HEAD. Whether the
      arrival red comes from one of those or predates the package is the next measurement, by bisecting exactly
      those files rather than by opinion.

   3. NEW RED IN THE FLAGSHIP SUITE, WITH ITS OWN HISTORY NAMED IN THE BUILD SCRIPT:
      [FAIL] R3-A near-target B1 stabilised convergence (first crossing = -1 frame, held 0.00 s, max error
      58.55 degrees, end error 10.99 degrees)
      run_checks prints 175 PASS and this ONE failure, then its own 90 second watchdog fires and force-quits, so
      the suite never prints its final result line and the runner sees exit 2 with no evidence marker.
      IMPORTANT AND MEASURED: THE WATCHDOG IS NORMAL ON THIS MACHINE AND IS NOT THE CAUSE. The 2026-09-17 log,
      which was judged PASS, ends with the SAME watchdog line; the difference is that it had 177 passes and ZERO
      failures. So the red is the R3-A check, not the timing.
      The build script already carries a note about exactly this item: "The implementer-added R3-A exemption is
      NOT in force... If R3-A appears again it is reported, fixed, or proposed as a separately bounded exception
      - never silently tolerated." R3-A has now appeared again, and it is being reported here rather than
      tolerated.
      Reproduced in the working tree: exit 2 after 92 s, same single failure, same watchdog.

   4. THE TWO PREVIOUSLY REGISTERED REDS, ONE OF WHICH CHANGED SHAPE:
      run_challenge_checks failed with its registered signature, which the register allows.
      run_industrial_battle_checks did NOT fail with its signature: it was KILLED at the 1500 second per-suite
      cap (exit -1, timed_out true), so no [FAIL] line exists for the register to match. A timeout is not a
      registered failure, and the build would have refused it on its own terms.

WHAT IS *NOT* CLAIMED, AND WHAT THE STATE OF THIS SUB-ORDER IS
   CD16-T01 is NOT met: the case asks for a package built from an explicit integration commit with every
   identity traceable, and NO PACKAGE EXISTS to trace. T02 to T06 are therefore untouched. Nothing was
   registered, no expectation was edited, no product or test file was modified, and the working tree is
   unchanged at 6c945fb2 with zero tracked edits - the failure is a measurement, not a change.
   The gate did exactly its job: it refused an internal candidate whose own integration suite carries reds, and
   it refused to let a sub-order green slice stand in for a package-level verification.
   The verification scripts written for this stage are kept even though they had nothing to verify:
   logs/COMBAT-DEEPEN-01/verify_cd016_package.js (55 checks; dry-run against the 2026-09-17 package and it
   found two real defects in ITSELF - a UTF-8 BOM that the build own Set-Content writes and a hardcoded project
   version that the real project does not use - both fixed and both named), compare_build_rows.js,
   read_suite_fails.js, classify_reds.js and read_build_failures.js.

WHAT THIS STAGE NEEDS BEFORE IT CAN CONTINUE
   item 1 is inside this package own change set and its remedy is a DECLARED new expectation under the
   delivery protocol, not a loosened one: the suite must assert the manifest the packet actually declares,
   including the HE round and its he_blast policy, while keeping every old assertion (APFSDS default with the
   long-rod effect, HEAT with the chemical effect, the reset restoring the declared manifest), with the change
   recorded as an expectation migration. items 2 and 3 are NEW behavioural reds that no sub-order delivered or
   measured, and whether they belong to this package or predate it is the next measurement.
   release_ready=false, public_release=false, human=PENDING, performance=HOLD_BY_USER.
```
