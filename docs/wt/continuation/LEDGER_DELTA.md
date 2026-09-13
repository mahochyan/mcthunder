# WT-001-R2 台账增量差异说明（5f24ae6 → a1bac406）

- 对应父项：WT-001（本地主线保全、状态追平与可复现候选）
- 依赖：WT-001-R1（已完成，`208648ae`，快照与恢复验证 PASS）
- 依据：`02_首轮10张执行单.md` §02、`03_全部42项目标工作单.md` WT-001 行 30-44、`06_直接发给执行模型.txt` 第 11 段（"WT-001-R2 追平台账、版本/构建身份、有效入口和历史包索引；保留旧证据。WT032 的 planned 要与新实施记录比较后修正；新 completed=0 不等于零功能。旧 RC2 包不代表当前能力。"）

## 1. 原则

1. **保留源台账数据**：`docs/wt/EXECUTION_PLAN.json`、`docs/wt/GAP_REGISTER.json` 的原有字段与取值一律保留，不做批量改写。
2. **只做一处就地状态更正**：WT-032 `planned → in_progress`（证据见 §3），并加 `status_note` 与该项五列。**不把 planned 统一改 completed**（`completed` 仍为 0）。
3. **五列统一以增量文件补齐**：`docs/wt/continuation/EXECUTION_PLAN_ADDENDUM.json`。每列为证据指针或显式 `NOT_RUN` / `source_report_only`，不用设计清单冒充实测。
4. **冲突不裁决**：台账与代码证据矛盾时保留 `conflict` 标记与双方来源，见 §4。

## 2. 时间轴与范围

| 项 | 值 |
|---|---|
| 源台账基线 | `5f24ae6`（2026-09-12，`EXECUTION_PLAN.source_baseline`） |
| 当前源码 | `a1bac406`（2026-09-13 01:32 +0800） |
| 之间提交 | **20 个**（`git rev-list --count 5f24ae65..a1bac406`） |
| 台账文件日期 | `EXECUTION_PLAN.json` date=2026-09-12；三份台账均早于最后 4 个提交 |

## 3. 20 个提交 → 工作项映射（增量登记依据）

| 提交 | 主题 | 归属工作项 | 主要落点 |
|---|---|---|---|
| `a1bac406` | Connect River Junction roads to real vehicle navigation and route guide | WT-032 | `scripts/maps/river_junction_navigation.gd`、`river_junction_range.gd`、`scripts/ai/drive_navigator.gd`、`ai_path_driver.gd`、`scripts/ui/river_junction_atlas.gd`、`tests/run_river_navigation_checks.gd`、`tests/run_river_route_ui_checks.gd` |
| `fc09daf5` | Implement three-objective capture rules and River Junction exercise | WT-032 / WT-022 | `scripts/battle/battle_objectives.gd`、`capture_point.gd`、`capture_point_state.gd`、`team_match_director.gd`、`team_match_state.gd`、`simulation_snapshot.gd`、`scripts/ui/river_objective_hud.gd`、`tests/run_multi_objective_checks.gd` |
| `af8fc50d` | Add River Junction driving trial and physical deployment cover | WT-032 | 河谷驾驶演练与部署掩体、`assets/shaders/river_buildings.gdshader` |
| `2724b27a` | Design three-point large battlefield and add garage map survey | WT-032 / WT-019 | 大地图设计与车库勘察入口 |
| `572d7290` | Bind modern candidate models to measured vehicle mechanisms | WT-030 | T-80B/豹 2A4 模型机构绑定 |
| `502d4835` | Build Soviet and German base-family trees with parallel branches and model trials | WT-033 / WT-031 | 五路线科技树、改型折叠、模型试驾 |
| `7d65b325` | Add modern bustle ammunition loss and repair recovery | WT-015 / WT-027 | 尾舱弹药损失与维修补弹 |
| `adfa47ee` | Build Soviet German combat candidates and proportional ready-rack stowage | WT-030 / WT-015 | 苏德战斗候选、按比例待发架 |
| `df48de7d` | Admit explicit vehicle equipment profiles with Soviet German drafts | WT-030 | 显式装备配置准入 |
| `1c36486e` | Add authoritative single-use reactive armor and network state | WT-012 / WT-009 | ERA 单次消耗与网络状态 |
| `a65cda8d` | Add passive composite armor and evidenced geometry layers | WT-012 | 被动复合装甲与附加层 |
| `6b12e42b` | Add independent HEAT carrier and chemical jet damage pipeline | WT-013 | HEAT 载体与化学射流 |
| `01d5bdaf` | Add budgeted directional spall with multi-batch damage and replay | WT-013 | 定向破片与多批回放 |
| `05b5a985` | Add explicit APFSDS direct-impact policy and real firing integration | WT-010 / WT-012 | APFSDS 直接命中策略接入实弹 |
| `02a84b4b` | Integrate explicit model bindings into vehicle packages and runtime exports | WT-030 | 模型绑定进入车辆包与导出 |
| `dd6af774` | Add explicit full-caliber material response and validate replay evidence | WT-012 | 全口径材料响应与回放证据 |
| `d8e48873` | Implement configurable APHE delay and external fragmentation | WT-013 | APHE 延迟引信与车外破片 |
| `dea5244d` | Add loading rules, AI interception and combat event recovery | WT-027 / WT-010 / WT-009 | 装填规则、AI 拦截、事件恢复 |
| `57870948` | Integrate range setting, turret response and reference vehicle intake | WT-007 / WT-008 | 距离装定、炮塔响应、参考车准入 |
| `c1936939` | docs(plan): map all remaining game work to dependencies and acceptance gates | 规划 | 42 项依赖与验收门映射（本台账来源） |

**结论**：`5f24ae6` 之后的主线是 **WT-032 河谷枢纽（4 提交）+ 现代车辆与毁伤（11 提交）+ 科技树与内容（2 提交）+ 规划（1 提交）+ 模型绑定（2 提交）**；台账把这批全部记在 `planned` 之前的状态，故"WT-032 完全未实施"与事实不符——只更正这一项。

## 4. 冲突与未验证项（不裁决，仅登记）

| 项 | 台账值 | 代码/证据值 | 处置 |
|---|---|---|---|
| WT-032 执行状态 | `planned` | 4 提交 + `docs/wt/WT032_*.md`（4 篇，2026-09-13）+ `logs/WT032-*/RESULTS.json` | **更正为 `in_progress`** 并附 `status_note` |
| WT-032 完成度 | — | `logs/WT032-navigation/RESULTS.json.limitations`：`release_accepted=false`、`formal_20_32_player_match=NOT_RUN`、`network=NOT_RUN`、`human=NOT_RUN`、`performance=HOLD_BY_USER`、`battle_admitted=false`、`simultaneous_multi_vehicle_navigation=NOT_RUN` | 保持未完成；不标 completed |
| WT-001 执行状态 | `EXECUTION_PLAN`: `planned`；`GAP_REGISTER`: `in_progress` | 本分支已交付 R1（PASS）与 R2 | 两份台账口径本来不同（一个记执行、一个记缺口）；**不强行统一**，增量记入 addendum |
| 构建身份 | `project.godot config/version="1.0.0-rc.2"` | 源码含 RC3 与 20 个后续提交；`docs/wt/BASELINE.json`：`build.id=null`、`status=source_candidate_not_packaged` | 见 `BUILD_IDENTITY.md`；RC2 包保留历史身份 |
| 人类验收 | 42/42 `NOT_RUN` | 无真人反馈记录 | 保持 `NOT_RUN`，不代签 |

## 5. 五列口径（`EXECUTION_PLAN_ADDENDUM.json`）

| 列 | 含义 | 允许取值 |
|---|---|---|
| `implementation` | 实现落点（文件/提交） | 文件路径 + 提交哈希，或 `source_report_only` |
| `automated_verification` | 相关自动检查（无窗口） | `logs/...` 结果文件 + 项数 + 退出码，或 `NOT_RUN` |
| `normal_session_verification` | 正常入口/真实窗口证据 | `docs/evidence/...` 截图或窗口日志，或 `NOT_RUN` |
| `human` | 真人体验 | 恒为 `NOT_RUN`（本包不代签） |
| `build` | 独立包/构建身份 | 包路径 + 哈希，或 `NOT_RUN` |

**本次对 20 提交增量覆盖的工作项**（WT-032、WT-030、WT-031、WT-033、WT-012、WT-013、WT-010、WT-015、WT-027、WT-007、WT-008、WT-009、WT-022）逐项填五列；**其余 29 项**在 `5f24ae6..a1bac406` 期间无变更，`implementation` 沿用源台账描述（`source_report_only`），其余四列为 `NOT_RUN`。

## 6. 本单不做

- 不把 42 项中的任何一项标为 `completed`（`completed` 仍为 0）。
- 不改 `GAP_REGISTER.json` 的 42 条原始要求文本。
- 不重跑历史长测，不重写 50 份历史交付文档。
- 不推送、不发布、不接入云 CI（仅准备本地门禁接口，见 `TEST_ENTRY_LIST.md`）。
