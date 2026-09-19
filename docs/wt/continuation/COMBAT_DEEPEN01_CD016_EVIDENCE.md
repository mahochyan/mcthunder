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
## 10. Stage three continues: the user ruled both boundary questions, item 1 is MIGRATED and measured, and the attribution of the two new reds has its mechanism and its plan

```
THE TWO RULINGS, RECORDED IN SUBSTANCE
   RULING ONE on the in-scope stale expectation: MIGRATE IT UNDER THE PROTOCOL - assert the manifest the packet
   actually declares, keep every old assertion, add the HE round and its he_blast policy, and record it as an
   expectation migration with a declared version. No bar is lowered.
   RULING TWO on the two new behavioural reds: ATTRIBUTE FIRST, THEN FIX INSIDE THE PACKAGE SCOPE - bisect the
   production files changed since the last passing clean build, name the causing commit, repair it if it belongs
   to this package own rules, and report before anything outside them is touched.

ITEM 1 IS DONE AND MEASURED, NOT ASSERTED
   tests/run_engineering_runtime_checks.gd no longer compares the manifest against the literal two. It reads the
   declaration: every declared round must carry an identifier and the family policy that family declares
   (APFSDS long_rod, HEAT chemical, HE he_blast), the default must still resolve to a declared round and must
   still be the APFSDS long-rod round, the HEAT round must still be chemical, and the runtime option count is now
   compared against the PACKET OWN DECLARATION instead of a literal, which also cross-checks data against runtime.
   MEASURED BEFORE: 26 checks, 1 failed, twelve further checks never reached because the suite returned early;
   the same suite stood at 44 checks with no failures on the 2026-09-17 clean build, before CD07 added the HE round.
   MEASURED AFTER: 54 checks, 0 failed. The T-80B declares three rounds and all three validate with their own
   policies; the Leopard declares two and both validate; the HEAT reload, both real launches and the reset
   restoration still pass for both vehicles. THE SUITE IS STRONGER THAN IT WAS, not weaker: fifty four checks
   against the forty four of the old literal version.
   RECORDED: the migration table gains its thirty second entry, WT-CD-016 / expectation_migration /
   cd16-declared-manifest-expectation-v1, with the before and after measurements, the retained two-round
   regression, and a rollback that says restoring the literal makes the T-80B HE round fail exactly as it did.
   The append helper again proved its own serialiser byte for byte against the previous last entry before writing.

THE ATTRIBUTION OF ITEMS 2 AND 3: THE MECHANISM IS NAMED AND THE DETERMINISM IS PROVEN
   DETERMINISM FIRST, because a bisect is worthless if the failure is machine speed. Both AI clocks are
   accumulated from delta - ai_tank_controller.gd line 166 clock += delta and ai_path_driver.gd line 201
   clock += delta, both fed by the physics delta - and the suite runs under --fixed-fps 60, so one simulated
   second is exactly sixty physics steps whatever the wall clock does. The village failure is therefore a
   PRODUCT BEHAVIOUR CHANGE.
   THE VILLAGE FAILURE READ FROM ITS OWN DIAGNOSTIC, not from the check text alone. The check prints the
   APPROACHED set, so the five names it lists are the ones that arrived and TWO actors did NOT: A2 and B3. The
   suite also prints an [unreached route] line for each, and both read hop=(inf, inf, inf), meaning the driver
   holds no current hop while still reporting phase "following". A2 emitted only three driver events, all at
   simulated time 0.0, and finished at (-33, 0, 108) against a spawn of (-9, 0, 116): it moved laterally and
   never advanced. B3 looped through physical_obstacle, edge_blocked by B4, reverse, turn_recovery and repeated
   idle/new_goal/path_ready cycles that reset the waypoint to zero, drifting to (-57, 0, -117) - the wrong side of
   the map. So the red is a NAVIGATION PROGRESS stall for two named actors, not a scene, spawn or physics failure.
   THE MECHANISM FILES THAT CHANGED ARE FEW, AND THAT IS THE BISECT SET. Between the last passing clean build
   15026f1a and HEAD the navigation, map and battle-driver files are UNCHANGED; the changed candidates in that
   mechanism are exactly four - scripts/ai/ai_perception.gd (CD004, the fire-lane prediction now integrates the
   profile-aware advance), scripts/ai/ai_tank_controller.gd (99c96674, aim recovery from persistently blocked
   surfaces), scripts/drive/drive_profile.gd (CD11, per vehicle declared curves with the old globals as defaults)
   and scripts/vehicle_actor.gd (CD01-T01, the ammunition contents now fed into the damage snapshot). The query
   layer that feeds AI observation also changed and is therefore in the set rather than assumed innocent:
   scripts/query/shot_query_service.gd, query_snapshot_builder.gd and world_query_adapter.gd.
   THE PLAN, STATED SO IT CAN BE CHECKED: bisect the production commits in that range with the village suite as
   the test, run in a SEPARATE git worktree so the main tree stays clean and every artifact already committed
   here is untouched, with the engine path passed explicitly because tools/ is not part of the snapshot. The test
   is deterministic, so the boundary it finds will be a real one. R3-A is the second target and is checked at the
   commit the bisect names, since one cause may explain both.
   NOTHING WAS FIXED FOR ITEMS 2 AND 3 IN THIS ROUND, and nothing outside the package own files was touched.
   release_ready=false, public_release=false, human=PENDING, performance=HOLD_BY_USER.
```
## 11. The bisect instrument itself failed three times, and each failure is recorded because a wrong instrument is worse than no instrument

```
FAULT ONE - THE GOOD COMMIT WAS NOT AN ANCESTOR, SO THE RANGE WAS NOT A RANGE
   I picked 15026f1a as the good end because its build recorded the village suite as PASS. `git bisect` refused and
   said why: that commit is NOT an ancestor of HEAD, so the "range" I had been reasoning about was a diff between
   two trees, not a linear history. The merge base a005b681 had to be tested and it is bad as well. The lesson is
   recorded in the scan that replaced it: find_good_ancestor.js reads the village verdict out of every earlier
   clean build's copied regression log AND asks git whether that build's commit is an ancestor of HEAD. It found
   TWELVE ancestors where the suite passed, the newest being 69a83a9e on 2026-09-16, and ZERO ancestors where it
   failed - so the real range is 69a83a9e..HEAD, 237 commits.

FAULT TWO - A VACUOUS VERDICT, PRODUCED BY A STALE IMPORT CACHE AND AN ERROR-POLICY TRAP
   The first bisect run finished in twenty three seconds over four commits and announced that a commit which
   changed ONE DOCUMENTATION FILE was the first bad one. That verdict cannot be true, and it was refused rather
   than reported. Two causes, both mine:
     a) the test reused whatever import cache the worktree happened to hold, so the suite emitted a ONE-LINE log
        containing no verdict at all - and a run with no verdict was read as a verdict;
     b) the script ran under $ErrorActionPreference='Stop' with Godot stderr redirected through the pipeline,
        which made PowerShell turn a NATIVE WARNING into a terminating error. The script therefore died BEFORE
        printing its verdict and exited 1, and `git bisect` reads exit 1 as "this commit is bad" - for every step.
   Both are fixed in the rewrite: the cache is deleted so each commit is imported from its own sources, the engine
   is launched through a real process handle with redirected streams so a missing exit status is never mistaken
   for zero, and any path that cannot produce a real verdict exits 125 so git SKIPS the commit instead of guessing.

FAULT THREE - A CHINESE LITERAL IN A BOM-LESS .ps1 BROKE THE SCRIPT WITH A PARSE ERROR
   The rewrite first read the suite's check count out of its Chinese result line, and Windows PowerShell reads a
   BOM-less .ps1 as ANSI, so the literal was mangled and the whole script failed to parse - which is the exact trap
   already documented in tests/package_doc_names.json after it broke packaging once. The count now comes from the
   ASCII [PASS] and [FAIL] markers, the script contains ZERO non-ASCII bytes, and a parse check was added as its
   own step: logs/COMBAT-DEEPEN-01/check_ps1_parse.ps1 asserts a script parses BEFORE any run is believed.

THE INSTRUMENT IS NOW VALIDATED ON A KNOWN ANSWER BEFORE BEING TRUSTED
   Self-test on the known-bad commit 561a74f8, with the engine run exactly as the bisect will run it:
     BISECT_STEP commit=561a74f8 exit=1 checks=21 traced=True pass=False fail=True
     line=[FAIL] all seven autonomous actors leave spawn and reach central approaches: ["A4","B","A3","B4","B2"]
   Twenty one checks, the natural battle trace present, the same five approached actors as the working-tree
   measurement, exit 1 as the bad end must be. Only then was the bisect started.

THE BISECT IS RUNNING, IN A SEPARATE WORKTREE, AND ITS RESULT IS NOT IN YET
   worktree E:\AIprogram\mcthunder-bisect, bad 561a74f8, good 69a83a9e, 237 commits, roughly seven to eight steps
   at about eight minutes each, logs under logs/COMBAT-DEEPEN-01/c16-bisect4/. The main tree and every artifact
   already committed stay untouched because the bisect checks out into its own directory. NOTHING IS CLAIMED ABOUT
   THE CAUSE OF ITEMS 2 AND 3 UNTIL THAT RESULT IS IN, and the earlier vacuous answer is explicitly NOT a result.
   release_ready=false, public_release=false, human=PENDING, performance=HOLD_BY_USER.
```
## 12. The village red is ATTRIBUTED to a named pre-package commit, and the R3-A red is measured as load-dependent and therefore NOT attributable

```
THE VILLAGE BISECT CONCLUDED, and every step carried a real verdict: the battle trace was present and the suite
printed its full twenty one checks at every commit it judged, so no step was a silent run.
   BAD   8bc490fa   checks=21 traced=True   FAIL line = all seven autonomous actors ... ["A4","B","A3","B2","A2"]
   BAD   15340ac0   checks=21 traced=True   same failure
   BAD   cacc1ed3   checks=21 traced=True   same failure
   GOOD  7f89c941   checks=21 traced=True   no failure
   BAD   99c96674   checks=21 traced=True   same failure
   GOOD  c81f599e   checks=21 traced=True   no failure
   GOOD  0c2b4713   checks=21 traced=True   no failure
   GOOD  c164511e   checks=21 traced=True   no failure
   -> 99c966745944920535af5ddf201fdeb46631598b IS THE FIRST BAD COMMIT, and its IMMEDIATE PARENT c164511e was
      measured GOOD in the same run, so this is a parent-against-child two point proof and not an inference.
   WHAT THAT COMMIT IS: "fix: recover AI aiming from persistent blocked surface choices", 2026-09-17 15:42. It
   changes scripts/ai/ai_tank_controller.gd (25 lines: an aim-stall timer, a visible-sample advance and its
   resets), tests/build_release.ps1, tests/record_river_ai_match.gd and adds
   tests/run_modern_ai_surface_checks.gd.
   ITS SCOPE, MEASURED RATHER THAN ASSUMED: git merge-base --is-ancestor 99c96674 cacc1ed3 succeeds, and cacc1ed3
   is the FIRST commit of the combat-deepen branch ("phase 1 baseline half ... on the new isolated branch
   work/combat-deepen-01"), so this commit is an ANCESTOR OF THE BRANCH START. It belongs to the earlier
   continuation stream, NOT to any of the sixteen sub-orders and NOT to the combat-deepen change set. That stream
   had already recorded a related limitation in the handover it left behind: the traversal limitation that keeps
   the player slot from reaching the enemy inside a bounded match.
   UNDER THE USER RULING ("attribute first, then fix inside the package scope ... report before anything outside
   them is touched") THIS IS THE POINT TO STOP AND REPORT: the cause is named and measured, and it lies OUTSIDE
   the package own files, so nothing was changed for it.

THE R3-A RED IS A DIFFERENT ANIMAL, AND THE MEASUREMENT SAYS SO
   Four runs of tests/run_checks.gd, differing in how loaded the machine was:
     at 6c945fb2, inside the candidate build clean-source regression (machine busy)  FAIL first_cross=-1, end error 10.99 deg
     at 6c945fb2, working tree, while other work ran                                FAIL identical numbers
     at 561a74f8, bisect worktree, fresh import, machine quiet                      PASS first_cross=142, end error 0.01 deg
     at 92c1ddb6, MAIN TREE, same cache as the failing runs, machine quiet          PASS first_cross=143, end error 0.01 deg
   The last one is decisive because it holds the tree, the commit family and the import cache constant and changes
   only the load: the same check that failed twice now passes, converging in about 2.4 simulated seconds against a
   harness window of nine hundred physics frames.
   SO R3-A IS NOT ATTRIBUTABLE BY BISECTION: an unstable verdict cannot name a commit, and running the bisect
   would have manufactured a boundary that means nothing. Its instrument was nevertheless written, parse-checked
   and self-tested (logs/COMBAT-DEEPEN-01/bisect_r3a_test.ps1, which judges ONLY the R3-A B1 convergence line and
   never the suite exit status, because run_checks carries its own ninety second watchdog in EVERY build), and it
   is deliberately NOT run until the instability itself is understood.
   THE CANDIDATE MECHANISM IS NAMED RATHER THAN GUESSED: the suite is launched WITHOUT a fixed frame rate, the
   harness counts PHYSICS frames while the chain it measures is fed from the render clock, and turret_rig.gd states
   in its own comment that presentation never advances the authoritative axes - so exactly where those two clocks
   meet is the thing to instrument next. That is a focused investigation, not a bisect.

WHAT IS TRUE AT THE END OF THIS ROUND
   The village red: attributed to 99c96674, outside the package scope, reported and untouched.
   The R3-A red: measured as load-dependent (two failures under load, two passes when quiet, same code), so it is
   NOT a product regression that any commit can be blamed for on this evidence, and it is reported rather than
   registered or papered over. The build script own instruction about R3-A - that a reappearance must be reported,
   fixed or proposed as a separately bounded exception and never silently tolerated - is satisfied by this report.
   The industrial timeout, the in-scope expectation migration and the still-missing package are unchanged from the
   previous sections.
   release_ready=false, public_release=false, human=PENDING, performance=HOLD_BY_USER.
```
