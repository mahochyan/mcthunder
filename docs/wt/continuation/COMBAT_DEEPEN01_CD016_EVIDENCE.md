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
   **CORRECTED IN SECTION 16 (read that before quoting this):** the "two failures under load" reading counted logs
   whose `first_cross=-1` line is printed by PASSING runs as well. One log is a real failure, it is a FROZEN WORLD
   (a focus-out pause), and the mechanism is measured there.
   The industrial timeout, the in-scope expectation migration and the still-missing package are unchanged from the
   previous sections.
   release_ready=false, public_release=false, human=PENDING, performance=HOLD_BY_USER.
```
## 14. The HE velocity was aligned, measured, REVERTED, and the measurement then corrected my own attribution

```
WHAT THE WAR THUNDER REFERENCE SAID (docs/wt/wt-reference/WT_AMMO_COMPARISON.json)
   Our engineering HE round eng_125_he_v1 declares 700 m/s. The gun file 125mm_2a46_2_user_cannon.blk states
   850 m/s for its 125mm_ussr_HE round (explosive a_ix_2, 3.402 kg) in the local build 2.59.0.13. Every other
   round matches exactly: 1700 = 3BM42, 905 = 3BK12, 1650 = NATO APDS_FS, 1140 = NATO HEAT_FS.

WHAT WAS DONE, IN THE ORDER IT WAS DONE
   1. both declarations of the HE velocity in the T-80B packet - the shell_catalog entry and the evidence claim
      value that must agree with it - were set to 850;
   2. five suites were run: run_engineering_runtime_checks 54/0 PASS, run_shell_checks 193/0 PASS,
      probe_cd007_he_runtime 19/0 PASS, probe_cd007_world_burst 15/0 PASS, probe_cd007_occlusion_target 13/0
      PASS - and probe_cd007_he_landed came back 3 PASS / 4 FAIL;
   3. I attributed that failure to the change and REVERTED the packet, because the goal says a failure returns
      the tree to the last runnable state;
   4. THE REVERT WAS THEN MEASURED, and it corrected me: with the packet byte-identical to the committed state
      (tracked diff 0) the same probe still reports 3 PASS / 4 FAIL, with the SAME four failures and the same
      messages. THE CHANGE DID NOT CAUSE THEM. I had attributed a failure from a single observation without
      having measured the baseline first, which is exactly the mistake this session keeps recording.

WHAT THE FOUR FAILURES ACTUALLY ARE, AND THEY ARE A NEW FINDING
   [FAIL] CD07 HE L1 ussr_t_80b registers
   [FAIL] CD07 HE L1 germ_leopard_2a4 registers
   [FAIL] CD07 HE L1 the engineering HE is reachable on the vehicle that carries its gun: []
   [FAIL] CD07 HE L1 and it is LIMITED rather than handed to every vehicle: 0 of 0 offer it
   The probe own registration leg fails, so nothing is registered and the two downstream reachability checks then
   report 0 of 0. It is VELOCITY-INDEPENDENT (identical in both states), it is PRE-EXISTING, and it was never in
   any green slice - CD07 own evidence used run_shell_checks and other probes for the family claim, so this leg
   was not re-run as the packets changed shape afterwards. It is recorded here as an open defect of a delivered
   CD07 fixture, named rather than absorbed, and it needs its own round.

STATE OF THE TREE AND OF THE ALIGNMENT
   The packet is back at its committed value (700 m/s) and the tree has ZERO tracked changes, so the last
   runnable state is restored. The alignment itself is NOT withdrawn as a finding: it is prepared and evidenced
   (the file value, the five green suites, the measured impact list) and it becomes a declared behavior change
   with its own migration entry once the fixture defect above is understood, because a rule change and a broken
   fixture must not be fixed in the same breath.
   release_ready=false, public_release=false, human=PENDING, performance=HOLD_BY_USER.
```
## 15. The CD07 HE fixture defect is FIXED, and the product truth it was hiding is now measured

```
THREE FIXTURE FAULTS IN ONE PROBE, ALL OF THEM MINE AND ALL NOW CORRECTED
   1. WRONG ENTRY POINT: L1 built the catalog as VehicleCatalog.new(packet.get("sources",{})), handing the packet
      EVIDENCE sources where the catalog expects the project MODEL registry
      (res://configs/vehicles/model_sources.json), so registration failed on the model binding. The old code then
      asserted only "does not register" and printed no reason. It now uses the default constructor - the same
      entry point production uses - and PRINTS the registration errors, so a future failure explains itself.
   2. NO PHYSICS BEFORE READING: L1 disabled physics on the actor and waited two PROCESS frames before reading the
      shell options, while the rounds are installed by the loading step on PHYSICS frames. It therefore read an
      empty list and reported a product gap that was its own wiring. It now waits thirty frames with physics
      running, exactly as run_engineering_runtime_checks does, and only then freezes the actor.
   3. WRONG ID FORM: the runtime shell id is the packet-scoped id PREFIXED WITH THE VEHICLE ID, so the round is
      ussr_t_80b_eng_125_he_v1 and not eng_125_he_v1. Comparing against the packet id made the leg report that
      nothing offered the round while the printed option list immediately above it showed the round installed.

WHAT THE FIXED PROBE NOW MEASURES, AND IT IS THE CD07 CLAIM ITSELF
   [CD07 HE] L1 ussr_t_80b       gun=125mm_2A46_2_user_cannon options=["ussr_t_80b_shell",
                                  "ussr_t_80b_eng_125_heat_v1", "ussr_t_80b_eng_125_he_v1"]
   [CD07 HE] L1 germ_leopard_2a4 gun=120mm_Rheinmetall_L44_user_cannon options=["germ_leopard_2a4_shell",
                                  "germ_leopard_2a4_eng_120_heat_v1"]
   [CD07 HE] L1 vehicles offering eng_125_he_v1: ["ussr_t_80b"]
   -> the HE is reachable on the vehicle that carries its gun, and it is LIMITED to that vehicle: 1 of 2 offer it,
      with the Leopard explicitly checked not to offer it.
   RESULT: 13 checks, 0 failures, CD07_HE_LANDED_PASS.
   L2 outcome unchanged and still recorded honestly by the probe own note: terminal=expired_distance, contacts=0,
   burst=none - the fixture has nothing in the flight path, so this leg measures what happens when the round meets
   nothing and does NOT claim a burst. The contact burst path itself is measured elsewhere and green:
   probe_cd007_world_burst 15/0 and probe_cd007_occlusion_target 13/0, the latter recording terminal=internal_burst
   with contact_kind=world_contact and three channels.

NO EXPECTATION WAS LOWERED: the three failures that disappeared were failures of the fixture own wiring, the
product assertions are the same assertions, and the option list that proves the behaviour is printed as evidence.
   release_ready=false, public_release=false, human=PENDING, performance=HOLD_BY_USER.
```
## 13. The user ruled both boundary questions again, and the R3-A trace turns the instability from a suspicion into a mechanism

```
THE TWO RULINGS, RECORDED IN SUBSTANCE
   RULING THREE on the village red: AUTHORISE A BOUNDED OUT-OF-PACKAGE FIX - repair that commit's AI aim and
   visible-sample change, recorded as an out-of-package repair with its own evidence, so the integration gate can
   pass. It touches one pre-package AI file and none of the sixteen sub-orders' rules.
   RULING FOUR on R3-A: AUTHORISE THE FOCUSED CLOCK INVESTIGATION - instrument where the physics clock and the
   render clock meet in the aim chain, prove the mechanism, and fix the harness or the driver only once the cause
   is shown.

WHAT THE TRACES ALREADY PROVE ABOUT R3-A, BEFORE ANY NEW RUN
   The harness prints its own error trajectory every sixty frames, and the two logs differ in kind, not in degree:
     FAIL, machine busy:   frame 0 = 58.060 deg, 60 = 35.552, 120 = 11.260, 180 = 10.987, and then 10.987 at
                           240, 300, 360, 420 ... - THE MECHANISM STOPS ADVANCING ENTIRELY and the error freezes
                           at a constant value, which is a stopped turret, not a slow one.
     PASS, machine quiet:  frame 0 = 59.160 deg, 60 = 35.308, 120 = 2.602, 180 = 0.029, first crossing at 143.
   A frozen residual is the signature of an aim point that stopped being refreshed: the barrel converges onto a
   stale point and holds a constant offset from the live one. The chain that refreshes it is
   vehicle_actor.advance_simulation_aim (which calls fire_control.advance, cam_rig.intent_point and
   turret.set_aim_point) followed by advance_simulation_mechanism, both gated by simulation_step_valid and both
   driven by the simulation phases rather than by rendering - and turret_rig states in its own comment that
   rendering never advances the authoritative axes. So the remaining question is exactly one: WHY a physics-paced
   step would stop refreshing the aim point when the machine is loaded, and the answer has to be measured rather
   than asserted.
   THE FIRST INSTRUMENT ATTEMPT WAS A DEAD END AND IS RECORDED AS ONE: vehicle_actor already prints a command
   trace with Engine.get_physics_frames(), but it sits behind debug_command_trace and is therefore absent from
   both logs (zero [cmd-trace] lines in each), so it could not measure the cadence. The next step is a counter
   that is always on for this investigation - aim-phase steps against physics frames - not a guess about clocks.

WHAT IS KNOWN ABOUT THE VILLAGE FIX BEFORE IT IS WRITTEN
   The attributed commit changes scripts/ai/ai_tank_controller.gd by twenty five lines: it adds an aim-stall timer
   (_aim_stall_since) with a visible-sample advance and its resets, and it replaces the inline preferred-sample
   rotation after a shot with that helper. Nothing else in that commit touches driving, so the repair has to
   explain how an AIM-side state change stalls the PATH DRIVER's hop - which is what the [unreached route] output
   showed, hop=(inf, inf, inf) with the phase still reading "following" - before anything is changed.

NOTHING WAS CHANGED FOR EITHER ITEM YET, and the two authorisations are recorded here so the next round starts
from the rulings rather than from memory. release_ready=false, public_release=false, human=PENDING,
performance=HOLD_BY_USER.
```

## 16. Ruling four EXECUTED: R3-A is not a clock problem at all, it is a PAUSED WORLD, and the harness was reporting a frozen turret as a convergence failure

The authorised instrument was built and it answered the question in one round, by rejecting both candidate mechanisms
and finding the real one through the product's own pause path.

WHAT WAS BUILT (always on, as authorised - the earlier `debug_command_trace` attempt was a dead end because it printed
nothing, and a counter that is off cannot measure anything):
   - `vehicle_actor.gd`: `aim_phase_steps`, `aim_steps_this_physics_frame`, `aim_steps_max_per_physics_frame`, stepped
     by `_note_aim_step()` at the top of `advance_simulation_aim`.
   - `camera_rig.gd`: `pose_updates_from_physics` / `pose_updates_from_render` and `aim_point_reads_precise` /
     `aim_point_reads_pose`, because the convergence TRUTH is `get_aim_point()` and it can be answered from two
     different clocks - the physics-derived precise intent, or a ray built from the CAMERA TRANSFORM that only
     `_process` (render) refreshes.
   - `tests/probe_r3a_clock.gd`: reproduces the leg exactly and takes `--load-ms N`, `--pause-at N`, `--focus-out-at N`.

MEASURED, FOUR REGIMES, ONE BUILD (all logs in `logs/COMBAT-DEEPEN-01/r3a-clock-*.log`):

| regime | process:physics ratio | aim steps per physics frame | truth clock | first_cross | final_err |
|---|---|---|---|---|---|
| `--fixed-fps 60`, quiet | 1.00 | 0.999 (max 1 in a frame) | precise (physics) | 136 | 0.00 |
| real-time, quiet | 2.20 | 0.999 (max 1) | precise (physics) | 136 | 0.00 |
| real-time, `--load-ms 12` | 0.61 | 0.999 (max 1) | precise (physics) | 136 | 0.00 |
| real-time, 4 CPU burners + `--load-ms 30` | 0.36 | 0.999 (max 1) | precise (physics) | 136 | 0.00 |

   H1 REJECTED: the aim phase advances AT MOST ONCE per physics frame in every regime, so it is not render-clocked.
   H2 REJECTED: the convergence truth is answered from the physics-derived precise intent - `aim_reads_pose = 0` in all
   four regimes - so the leg is not chasing a stale render-clock point.
   The convergence numbers are BIT-IDENTICAL from a 0.36 to a 2.20 process:physics ratio, under real CPU contention.
   The trajectory is render-clock independent, which is exactly what the code comments claim and what the flake
   appeared to contradict.

THE REAL MECHANISM, MEASURED THROUGH THE PRODUCT'S OWN PATH
   `scripts/main.gd:477` pauses the battle on `NOTIFICATION_APPLICATION_FOCUS_OUT` (the suite exercises this as
   T002-04). Deliver that notification mid-leg with `--focus-out-at 60`:
     `FOCUS_OUT delivered at frame 60 -> tree paused=true (main._paused=true)`, then the error PLATEAUS at 31.074 deg
     for the remaining 840 samples, `first_cross=-1`, and `aim_phase_steps=60` over 900 physics frames - the mechanism
     stops advancing at the pause and the loop keeps sampling a world that is not running.
   `--pause-at 150` (a pause set after convergence) shows the same freeze with the criterion already met. So the
   signature - constant residual, `first_cross=-1` - is a PAUSED WORLD, not a stopped aim refresh and not load.

A CORRECTION OF MY OWN EARLIER RECORD, which is why this section exists
   Section 12 recorded R3-A as "measured as load-dependent and therefore NOT attributable". Reading the logs again:
   of the package logs containing the `[stab] frame=0 ... first_cross=-1` line, FOUR continue to a PASS at frame
   143/147 (c16r2, fc, w42, r43-runchecks-baseline2) - frame 0 is simply the sample taken before the turret has moved,
   so that line was never evidence of failure. Exactly ONE log is a real failure: c16r, whose error plateaus at
   10.987 deg from frame 180 (the "10.99 deg" figure in the earlier notes). The load correlation was real - other
   foreground processes are what generate a focus-out - but the mechanism is a pause, and one failing run was
   generalised into "load-dependent" on the strength of a line that passing runs print too.

THE HARNESS GUARD (convergence criteria NOT relaxed)
   `tests/run_checks.gd` `_stable_converge` now returns `{"aborted":"world_paused"}` and prints
   `[stab] ABORTED at frame N: the world is PAUSED, so the mechanism cannot move - this is not a convergence result`
   instead of reporting non-convergence about a world that is not running. A paused world is still a FAILURE; it is
   named rather than disguised. Non-interference measured: the suite still passes the leg at first_cross=147,
   final_err=0.01 deg, 177 PASS / 0 FAIL, with the same pre-existing watchdog outcome as the untouched `main` tree.

STILL OPEN, stated rather than implied: the village AI repair (ruling three) is untouched, and what delivered the
focus-out in the original failing run is not recoverable from that log - what is now known is that ANY focus-out
during the leg produces exactly the recorded signature, and that the leg no longer disguises it.

## 17. Ruling three RE-MEASURED in the current build: the village red is still red, and this round's fresh facts narrow it to two actors and one destroyed-and-respawned one

`run_village_battle_checks` on the current work tree (log `logs/COMBAT-DEEPEN-01/village-baseline-before-fix.log`,
380 s): **20 PASS, 1 FAIL**. The failing check is unchanged - `all seven autonomous actors leave spawn and reach
central approaches: ["A4", "B", "A3", "B4", "B2"]` - and its criterion is `absf(p.z) < 45` inside 120 s of game time,
sampled every 15 s.

WHAT THE TIME SERIES ADDS, which the earlier record did not have (the two unreached actors, every 15 s):

```
         A2                                   B3
 5.1s    (-15.4,  0.008,  105.2) following   ( 15.4,  0.008, -105.2) following
20.2s    (-71.0,  0.021,  113.9) following   ( 71.0,  0.021, -113.9) following
35.1s    (-71.1,  0.013,   50.2) following   ( 72.1, -0.020,  -81.8) yielding
50.1s    (-70.2, -0.019,   49.1) following   ( 72.1, -0.008,  -83.2) reverse
65.1s    (-70.2, -0.019,   49.1) idle        ( 75.6, -0.018, -106.5) following
80.1s    (-70.2, -0.019,   49.1) idle        ( 37.3,  0.007, -117.0) following
95.1s    (-70.2, -0.019,   49.1) player *    ( -8.4, -0.019, -128.9) following
110.1s   (-33.0, -0.000,  107.8) following   (-56.8,  0.015, -116.5) following
```
   * `drive: "player"` in the harness means `actor.controller is AITankController` was FALSE at that sample, i.e.
     the controller was transiently absent, which is the shape of a respawn - and the next sample has A2 back near
     the spawn side of the map with a fresh AI phase. A2 also came to rest at z=49.08, which is 4 m OUTSIDE the
     `absf(z) < 45` criterion, after 45 s of not moving at all in the "idle" drive phase.
   NEITHER ACTOR IS FROZEN, which is how the earlier record described it: both drive 50 to 90 m across the map.
     B3 in particular walks out to z=-128.9, i.e. behind its own spawn, before coming back. Both end with
     `hop=(inf, inf, inf)`, so the final state of both is "no finite escape hop", but that is the state at the END of
     a 120 s match and it is not the whole story.
   A2 fired at least once during the match (it is in the `fired` set), so it was engaged before it stopped.

THE NEXT MEASUREMENT, NAMED BEFORE IT IS RUN (no product change until it is read): the bisect already established
`c164511e` GOOD and `99c96674` BAD in the same run, so the question is no longer WHETHER that commit matters but
WHICH BEHAVIOUR it moved. The answer needs the same match recorded on both builds with per-sample per-actor record
of: roster deaths, `state.destroyed`, position, AI phase, drive phase, and `driver.goal`/`_last_hop`. The harness
already prints most of that, so the run is a two-build comparison of the existing output, not new instrumentation.
The two candidates to separate, both testable from that output: (a) actors dying and respawning lose their progress
before arriving, i.e. the aim commit changed the FIGHT rather than the ROUTE; (b) the route/jam behaviour itself
changed and A2's 45 s "idle" at z=49.08 is the route failing to finish. Candidate (a) is supported so far by the
`player` sample and the position reset, and it is NOT yet proven.

## 18. Ruling three MEASURED THREE WAYS: the red really does start at that commit, and it is a MATCH-OUTCOME flip near the criterion, not a stall bug to repair

The two-build comparison of section 17 was run, and then the attributed commit itself was measured, because a
parent-versus-current comparison cannot isolate a commit that has 237 commits sitting on top of it.

THREE POINTS, SAME MACHINE, SAME INSTRUMENT, SAME CRITERION (`absf(p.z) < 45` inside 120 s):

| build | result | unreached actors |
|---|---|---|
| parent `c164511e` (worktree, imported) | **PASS 21/0** | none |
| attributed `99c96674` (worktree, imported) | **FAIL 20/1** | **B3, B4** |
| current `work/combat-deepen-01` HEAD, twice | **FAIL 20/1** | **A2, B3** (identical both runs, 380 s and 686 s wall) |

   ATTRIBUTION CONFIRMED: the red appears exactly at `99c96674` and not at its parent, on this machine, with the
   package's own suite. The earlier bisect verdict is now independently reproduced rather than inherited.
   THE FAILING SET IS NOT STABLE ACROSS BUILDS: B3+B4 at the commit, A2+B3 at HEAD. So the criterion is not
   "some actor is broken" but "six or seven actors finish a fight near the z=45 line and the seventh is decided by
   combat timing".

WHY: the AI stops driving while it engages or repairs, on BOTH builds, so arrival is a race between progress and
damage. From the `[natural battle]` series (AI phase, drive phase, position):
```
PASS parent   A2: engage/idle z=77.5 -> engage/following z=39.8 -> engage/idle z=17.8 -> repair z=17.9   ARRIVED
              B3: ... engage/following z=-61.6 -> turn_recovery z=-44.7 -> ...                          ARRIVED
FAIL HEAD     A2: repair/following z=49.1 -> engage/idle z=49.1 -> repair/idle z=49.1 -> DEAD (dead=true,
                  controller absent for one sample) -> respawned near its own spawn -> patrol z=107.8   MISSED by 4 m
              B3: never below z=-81.8 before wandering out to z=-128.9                                 MISSED
```
   The parent's A2 had already reached z=17.8 before its damage stopped it; HEAD's A2 took its damage 30 m further
   out, stopped at z=49.08 - FOUR METRES outside the criterion - repaired, and was destroyed while stationary. The
   behaviour is identical IN KIND on both builds (stop to engage, stop to repair); what moved is WHEN the damage
   lands. There is no frozen route, no infinite hop at the moment of failure (the `hop=(inf,inf,inf)` line is the
   state at the END of the match), and no render/physics clock involved.
   The red is also NOT load-sensitive: the current build failed identically at 380 s and at 686 s wall time.

CONSEQUENCE FOR RULING THREE: the ruling authorised "repair that commit's AI aim and visible-sample change ... so
the integration gate can pass". The measurement says the commit is a genuine cause, but there is no defect of the
kind the ruling assumed: the aim fix makes the AI recover from blocked surfaces, which changes who is hit when, and
a criterion of seven arrivals inside a 120 s fight turns that into a pass/fail. Repairing the aim change would also
not reproduce the parent's whole-match outcome today, because 237 commits now sit between them. The next step is
therefore a user ruling between a bounded AI-behaviour fix (an engaged or repairing AI keeps or resumes its
objective) and registering this red as understood - NOT a silent expectation change, which the package forbids.

## 19. Ruling three executed as a BOUNDED AI FIX: the first attempt was a measured NO-OP and was reverted, and the navigator then named two different real causes

The user ruled on section 18: bounded AI progress fix. This section is what happened, including the attempt that
failed, because a recorded no-op is worth more than a silent one.

ATTEMPT 1, REVERTED (the change is not in the tree): gate MOVEMENT on the mobility capability `caps.drive` instead of
on "a repair is pending" (`recovering`), at four sites in `ai_tank_controller.gd` (the objective retry, the patrol
and search returns, and the advance-while-engaged branch), on the reading that a repairing-but-mobile AI was standing
down from its objective.
   MEASURED: `run_village_battle_checks` 20 PASS / 1 FAIL, still A2+B3, and the per-sample phase/position series is
   **BIT-IDENTICAL** to the pre-fix run - the change had no effect on the match at all, so the reading was wrong.
   The five AI suites were green with it (recovery 17, combat 35, drive 41, river traffic 5, team 68) which is
   exactly why a green suite set is NOT evidence that a change does anything. Reverted with `git checkout`; the tree
   is at `018e266c` with no AI change.

ATTEMPT 2, MEASUREMENT FIRST (`tests/probe_village_route.gd`, logs `route-diagnostic.log`, `route-diagnostic2.log`).
The probe runs the same natural match and asks the NAVIGATOR, every 20 s, the three questions the phases cannot
answer. Answers for both stranded actors at every sample:

```
                       clean_plan  remembered_plan  drv.goal     hops  obj_blocked  deaths  ammo
A2  t=60.1s engage/idle   true         true        objective    0     false          0     25
A2  final   patrol/follow true         true        objective    0     false          1     30   z=115.8 (spawn side)
B3  t=40.1s repair/yield  true         true        objective    0     false          0     30
B3  final   patrol/follow true         true        objective    0     false          0     30   z=-91.7
```
   Q1/Q2/Q3 answered: the objective IS plannable from where both actors strand, WITH and WITHOUT the remembered
   traffic blocks; a finite escape hop exists; the driver's goal is the objective itself; the hop list is empty and
   `objective_blocked` is false. THE EARLIER "stranded route / hop=(inf,inf,inf)" READING WAS A SNAPSHOT OF A
   DIFFERENT MOMENT, and the actors never lose their objective.

TWO REAL CAUSES, DIFFERENT FROM EACH OTHER AND FROM EVERY EARLIER HYPOTHESIS:
   1. **A2 DIES AND RESPAWNS.** `deaths=1`, ammo back to 30, and its final position is z=115.8 - its own spawn side,
      126 m from the objective. It had arrived nowhere near the criterion before dying at about 95 s, and a respawn
      that far out cannot reach |z|<45 in the 20 s that remain. A single death makes the criterion unreachable; on
      the PASSING parent build A2 had already crossed into the zone (z=17.8) before its damage stopped it.
   2. **B3 IS IN A PHYSICAL STUCK/REVERSE LOOP WITH A VALID PATH.** `deaths=0`, `ammo=30` (it never fired), goal =
      objective, plan true - and its distance to the objective GROWS: 100.4 -> 108.1 -> 113.3 -> 111.4 -> 111.6 m
      while z oscillates -81.8 -> -92.3 -> -117.0 -> -119.0 -> -91.7. The driver event log for this pattern is
      `yielding physical_obstacle` -> `reverse insufficient_actual_progress` -> `turn_recovery reverse_complete` ->
      `path_ready` -> the same edge again: 30 m forward, 40 m back, forever. That is a driver-level defect (a route
      it cannot physically complete and never resolves), and it is the one part of this red that is a defect rather
      than an outcome.

WHAT THIS MEANS FOR THE NEXT BOUNDED FIX, named before it is written: the objective is never abandoned, so nothing
in the engage/repair decision needs changing; the fix belongs in the path driver's recovery loop - after N failed
recoveries on the same edge, that edge must be REMEMBERED as blocked for this task (the driver already keeps
`_blocked_edges` and already has `_release_vacated_traffic`, so the mechanism exists and is not being applied to the
physical-obstacle loop). Cause 1 is NOT a defect: a killed vehicle respawning at its spawn is correct, and the
criterion's demand that all seven arrive within 120 s of a live fight is a criterion-design question for the user,
not something to be relaxed here.

## 20. The village red is fully explained and it is NOT an AI defect: a WRECK closes the direct road, and the wreck lifetime equals the criterion window

Three more measurements (`route-diagnostic3.log`, `-4.log`; the probe now prints the driver's waypoint index, path
length and the route length with and without the block memory) settle it.

FIRST, THE LOOP HYPOTHESIS IS DEAD. B3 is NOT stuck and NOT looping: its waypoint index ADVANCES steadily through a
long route - `wp 0/19 -> 2/18 -> 7/18 -> 11/18` - with `attempts=0`, the driver's goal is the objective itself, the
last waypoint is (3,-9) = the objective, and the planner succeeds at every sample. It simply does not finish the
route before the 120 s criterion expires.

SECOND, THE DETOUR IS FORCED BY A REMEMBERED BLOCK, AND THE LENGTHS QUANTIFY IT:

```
                    clean_len (no block memory)   remembered_len (with it)
B3  t=60.1s                    7                          19
B3  t=80.1s                   10                          16
B3  t=100.1s                  12                          12
```
   At t=60 s the DIRECT route is SEVEN waypoints and the remembered block makes it NINETEEN - the block alone
   triples the route. By t=100 s the two agree, i.e. by then the detour is what the road network requires from where
   B3 has got to. The block's own event records it: `edge_blocked edge=road_89_1:road_89_2 mode=recover limit=2.5
   blocker=B4`.

THIRD, AND THIS IS THE ANSWER: `mode=recover` is chosen when the blocking vehicle's `controller == null`
(ai_path_driver.gd:291), which the driver reads as "parked hull, a dead end". B4's controller was null because
B4 WAS DESTROYED - `team_range.gd:436-449` clears the controller of a lost vehicle, stops its physics, and
**`wrecks.register(vehicle)` keeps the hull in the world** ("A previous player hull becomes ordinary visible cover in
the next life's gunsight"). So the permanent block is CORRECT: a wreck really does close that road, and B3's long
detour around it is the correct route.
   And the wreck cannot clear inside the measured window: `RecoveryRules.WRECK_LIFETIME_SECONDS = 120.0` while the
   arrival criterion's own window is 120 s from the start of the match. A wreck created at t=34 s is still there at
   the end of the window by construction.

SO THE RED IS A MATCH-OUTCOME FAILURE produced by the damage system working as designed: a wreck in a choke point
closes the short route, one actor (B3) correctly takes a detour too long to finish, and another actor (A2) is
destroyed and respawns 126 m out with about 20 s left. Neither is stalled, frozen, paused, mis-routed or
clock-dependent, and NO bounded AI progress fix can address it without either gaming the criterion or changing
combat balance. What remains is a user decision between REGISTERING this red as understood (the gate's own mechanism
for exactly this) and changing the wreck lifetime - which is gameplay balance with its own blast radius
(`WRECK_MAX_COUNT = 12` is also read by the performance verifier) - and NOT relaxing the criterion, which the
package forbids.

## 21. Ruling EXECUTED: the village red is REGISTERED in the build gate, and the registration was verified against the real failing line plus two negative controls

The user ruled: register it as a known red, do not tune the game to the test. `tests/build_release.ps1` now carries a
third `$deviationRegister` entry:

```
suite     = run_village_battle_checks
failures  = 1
signature = 'all seven autonomous actors leave spawn and reach central approaches' (count 1)
reason    = a wreck in the choke closes the direct road (route 7 -> 19 waypoints, no recovery loop) and the wreck
            lifetime equals the criterion window; one actor therefore detours too long and one dies and respawns
            126 m out   (recorded in ASCII, because a Chinese literal in this .ps1 is read as ANSI and has already
            broken packaging once)
```

WHY THIS IS A REGISTRATION AND NOT AN EXCUSE, verified rather than asserted
(`logs/COMBAT-DEEPEN-01/verify_village_register.ps1`, which dot-sources the gate's OWN matcher instead of copying it
and reads the register out of the script's real AST so it cannot drift from what the build executes):
```
PARSE_OK tokens=2764 parseErrors=0
REGISTER_ENTRIES=3 suites=run_industrial_battle_checks,run_challenge_checks,run_village_battle_checks
REAL_FAIL_ACCEPTED=True    the failure set matches the register exactly
NEW_FAILURE_REFUSED=True   signature matched 0 failure(s); the register expects exactly 1
EXTRA_FAILURE_REFUSED=True failed 2 check(s) but its registered signatures account for exactly 1
```
   So the gate tolerates THIS ONE check and nothing else: a different failure, or this failure plus any other, still
   stops the build. The suite log health guard also passes - the village logs carry 0 `SCRIPT ERROR`, 0 `^ERROR:` and
   0 `Parse Error` lines. `tests/check_candidate_register_match.ps1` still passes (15 checks, 0 failed,
   `CANDIDATE_REGISTER_MATCH_PASS`) and `build_release.ps1` remains pure ASCII.

WHAT THIS DOES NOT CLAIM: the check is still RED and still visible. Nothing in the product was tuned to make it pass,
no expectation was changed, and the criterion (`absf(z) < 45` for all seven inside 120 s) is untouched.

NEXT BLOCKER FOR THE PACKAGE BUILD, named now that the village red no longer stops it: `run_checks` ends in its own
90 s watchdog with 177 PASS / 0 FAIL, and the gate refuses an unregistered failing suite. That watchdog is a
GAME-TIME timer while the suite's waits are frame-based, and the suite's designed waits (three
`_wait_trial_hits(...,1200)` calls alone are 3600 frames = 60 s of game time) exceed 90 s of game time by
construction - measured identical on the untouched `main` tree, so it is pre-existing and not a regression. The two
honest options there are to derive the watchdog from the suite's designed frame budget, or to register it; the
decision is the user's and the measurement is already in section 16.






