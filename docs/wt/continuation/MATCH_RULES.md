# 比赛状态与规则参数（WT-022-R1）

- 依据：`02_首轮10张执行单.md` §09「必须交付：比赛状态/规则参数文档」
- 冻结载体：`scripts/battle/match_rule_preset.gd`（新增）；`TeamMatchState.rules` 携带本局冻结规则、`rule_fingerprint()` 提供可追溯指纹
- **口径**：本单是**规则提取与冻结**，不是平衡改动——所有数值与实现常量逐一相等，并由套件做漂移守卫（见 §4）

## 1. 冻结规则参数（`MatchRulePreset.standard()`，`id=team_standard_300@v1`）

| 参数 | 值 | 实现常量（守卫对象） |
|---|---|---|
| 初始票池 | 300 | `TeamMatchState.START_TICKETS` |
| 阵亡扣票 | 30 | `TeamMatchState.DEATH_COST` |
| 时限 | 600 s | `TeamMatchState.TIME_LIMIT` |
| 再出击延迟 | 8 s | `TeamMatchState.RESPAWN_DELAY` |
| 出生保护 | 3 s | `TeamMatchState.PROTECTION_SECONDS` |
| 占点半径 | 12 m | `TeamMatchState.CAPTURE_RADIUS` |
| 占领时长 | 12 s | `TeamMatchState.CAPTURE_SECONDS` |
| 占点上限 | 3 | `BattleObjectives.MAX_POINTS` |
| 倒计时 | 3 s | `MatchDirector.COUNTDOWN_SECONDS` |
| 事件 schema / 历史上限 | 1 / 128 | `TeamMatchState.EVENT_SCHEMA_VERSION` / `EVENT_HISTORY_LIMIT` |
| 奖励表 | victory 60 / defeat 30 / draw 40 / abandoned 0 | `ProgressionService.REWARDS` |

## 2. 结果顺序（冻结为显式列表）

`["tickets_exhausted","time_limit","ticket_compare","draw"]`，实现见 `TicketLedger.result_after_tick`：

1. **同 tick 双方票池皆空 → 平局**（先判双零，避免"谁先判谁赢"的歧义）
2. 仅本方空 → `defeat`；仅敌方空 → `victory`
3. 到时限：票数相等 → `draw`；否则票多者 `victory`
4. 未结束 → 空结果（不产生胜负）

## 3. 状态机与三类会话

| 阶段 | 行为 |
|---|---|
| `loading` / `countdown` | 不计占点、不扣票（`BattleObjectives.step` 与 `TicketLedger.apply_events` 都要求 `phase=="playing"`） |
| `playing` | 占点推进 + 票池结算 + 阵亡扣票 + 再出击计时 |
| `finished` | 终局事件提交后**冻结**：`result_after_tick` 立即返回 `""`，占点/扣票不再推进 |

**占点参战者定义（实现事实）**：`team_match_director.gd:80-83` 明确 **跳过 `state.destroyed`（死车）与 `protected_at_start`（出生保护）**，只有活跃实体进入 `occupants`；`BattleObjectives` 再过滤"区外 / 距中心上方 > 12 m"的位置。→ 死车占点与保护期占点**不会计入**；已占领的据点即使在无人时也持续为占有方扣敌票（设计如此）。

**再出击（规则侧）**：`respawn_rules = {new_life_id:true, frozen_loadout:true, protection_s:3.0, player_manual:true}` → 用**冻结配装 + 新 life_id**；资格仍走 `VehicleReadiness.eligible`（WT-031-R1 统一门禁），HUD 不能直接改票/保护/资格。

**结算与奖励（去重事实）**：`ProgressionService.apply_result_once(token,result)`：
- `receipts` 已有该 token → `duplicate=true, points=0`
- 无 live 注册对局 / 导演未 `finished` / 结果与 `state.result` 不一致 → 拒绝
- 收据上限 128，`pending` 上限 16；中断会话不得凭空产生结果
- `app_flow._settle_match` 在失败时保留 `pending_reward` 以便重试，成功即清空

## 4. 本轮验证（真实运行）

| 套件 | 结果 |
|---|---|
| `tests/run_match_rules_checks.gd`（新增，43 项） | **43/43 PASS** |
| `run_multi_objective_checks` | **35/35** |
| `run_match_event_checks` | **PASS** |
| `run_garage_checks`（历史轮次证据，见 `logs/WT-031-r1/`） | 151/151 |
| `run_balance_match_checks` | **NOT_RUN**（headless 600 s 超时；属长时平衡批测，按范围界限不跑大型采样） |
| `run_app_match_cycle` | **NOT_RUN**（headless 挂起，300 s 看门狗终止，仅 1 项通过） |

新增套件覆盖：preset↔实现漂移守卫（11 项）、单方占领、双方争夺（进度不推进且继续为占有方扣票）、夺回（先中立化再占领）、空区不扣票、区外/高空不计占点、重复阵亡事件只扣一次票且只记一条事件、同 tick 双零=平局、时限比较、运行中无结果、隔离存档上的奖励契约（空 token 0 分 / 无 live 对局被拒 / 存档无 problem）、新局干净且携带冻结规则指纹。

## 5. 未覆盖（如实）

- `run_balance_match_checks` / `run_app_match_cycle`：见上（`NOT_RUN`）
- 真实窗口的选车/配弹/HUD/结算 UI 复核：`NOT_RUN`（由 `run_garage_frontend_checks`、`run_*_player_checks` 承担，本单未跑）
- 网络与真人：`NOT_RUN`；性能 `HOLD_BY_USER`（未采集 FPS/p95/p99）
- **死车占点/保护期占点**为**代码路径事实**（`team_match_director.gd:80-83`）+ 真实整局套件（`run_match_batch_checks` 5/5、`run_multi_objective_checks` 35/35）联合支撑；本单未构造"击杀占点车内玩家"的端到端夹具 → 该专项 `NOT_RUN`
