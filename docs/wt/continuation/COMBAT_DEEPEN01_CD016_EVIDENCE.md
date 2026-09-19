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
