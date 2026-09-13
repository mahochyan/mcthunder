# WT-022-R1 设计页（三点、票池、再出击与结算统一）

- 对应父项：WT-022 / WT-032 / WT-033 / WT-035；依赖：WT-032-R1（可达 + 补给）、WT-031-R1（门禁）、WT-012-R1（能力/恢复）
- 依据：`02_首轮10张执行单.md` §09

## 1. 现状核查（实测，先核实再补）

| 要求 | 现状 | 处置 |
|---|---|---|
| 提取并冻结 `MatchRulePreset` | **缺失**：规则散落在 `TeamMatchState`(9 常量)、`MatchDirector`(2)、`BattleObjectives`(1)、`ProgressionService.REWARDS` | **本单新增** preset + 状态携带 + 漂移守卫 |
| 活跃参战实体才计占点 | **已实现**：`team_match_director.gd:80-83` 跳过 destroyed 与出生保护；`BattleObjectives` 再过滤区外/高空 | 仅**验证**并写入规则文档 |
| 再出击用冻结配装 + 新 life_id | **已实现**（配装冻结 + `life_id` 递增 + 门禁走 `VehicleReadiness.eligible`） | 仅验证（WT-031-R1 已覆盖门禁） |
| 终局原子提交、冻结后不再得分 | **已实现**：`finished` 后 `result_after_tick` 返回空、占点/扣票停推 | 仅验证 |
| 奖励收据与重复入账保护 | **已实现**：`apply_result_once(token,result)`（`receipts` 去重 / live 对局校验 / 结果一致性校验 / 上限） | 仅验证 |
| 结果顺序含双零平局 | **已实现**（先判双零再判单方） | 仅验证 |

**结论**：本单只需补 **规则冻结载体**；其余为**验证与文档**。未重写导演、未改任何规则数值。

## 2. 改动清单

| 文件 | 改动 |
|---|---|
| `scripts/battle/match_rule_preset.gd`（新，60 行） | 冻结 preset：`VERSION=1`、`ID=team_standard_300`、11 个参数值、`result_order`、`rewards`、`respawn_rules`、`capture_rules`、`snapshot()`、`fingerprint()`、`label()`、`id()` |
| `scripts/battle/team_match_state.gd` | 新增 `var rules := MatchRulePreset.standard()` 与 `func rule_fingerprint()`；**常量原样保留**（不改变行为） |
| `tests/run_match_rules_checks.gd`（新，43 项） | 漂移守卫 + 占点语义 + 重复阵亡 + 结果顺序 + 奖励契约 + 新局干净 |

**零行为变更**：常量为唯一实现值，preset 只做冻结副本；接线是纯追加字段。

## 3. 自纠记录（测试语义，非实现缺陷）

新套件首版有 **3 处断言语义写错**，经代码路径核对后修正（**未放宽任何断言**）：

1. "区内实体即时贡献占点时间" → 实际是**占领完成后**才累积（`CapturePoint.step` 的 boundary 逻辑）。
2. "区外实体不贡献" → 实际**已占领据点即使无人也持续为占有方扣票**（设计如此），故改用**全新据点**验证"区外/高空不计入"。
3. `preset.id` → 实为常量 `ID`（已补 `id()` 方法，并给套件加 180 s 看门狗，避免运行期错误导致静默挂起）。

## 4. 验证

见 `MATCH_RULES.md` §4；本单新增 **43/43**，回归 `run_multi_objective_checks` **35/35**、`run_match_event_checks` **PASS**。`run_balance_match_checks` 与 `run_app_match_cycle` 在本机 headless 下超时/挂起 → `NOT_RUN`。

## 5. 明确不做 / 未运行

- 不重做三点专用车辆/伤害/保存系统（复用既有 director）。
- 不改票池、扣票、时限、占点时长等任何数值（仅冻结）。
- 不跑大规模平衡批测；窗口 UI、网络、真人 `NOT_RUN`；性能 `HOLD_BY_USER`。

## 6. 回滚

删除 `match_rule_preset.gd` + 回退 `team_match_state.gd` 的 3 行 + 删除新套件即可；因常量与行为未变，回滚无副作用。
