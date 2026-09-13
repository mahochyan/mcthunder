# WT-012-R1 设计页（既有现代毁伤与装填通过样车实战链）

- 对应父项：WT-010 / WT-011 / WT-012 / WT-013 / WT-014 / WT-015 / WT-027
- 依赖：WT-031-R1（门禁）、WT-002-R1（权威状态）、WT-007-R1（火控）
- 依据：`02_首轮10张执行单.md` §07

## 1. 现状核查（先核实覆盖，缺失才补 —— 本单结论：**无需改运行时代码**）

按 `02` §07「先从已有日志和调用链核实功能覆盖」逐项核查：

| 要求能力 | 生产实现 | 既有套件 |
|---|---|---|
| 标准板/角度/材质 | `armor_resolver`、`armor_impact_profile`、`penetration_curve` | `run_armor_checks` |
| 长杆 APFSDS | `armor_impact_profile` 长杆分支 | `run_long_rod_checks` / `_content_` / `_damage_` |
| 化学射流 HEAT | `chemical_jet_system`、`chemical_profile` | `run_chemical_checks` / `_content_` |
| 被动复合装甲 | `armor_layer_profile`、`vehicle_armor_layers` | `run_composite_checks` / `_binding_` / `_content_` |
| 单次 ERA | `reactive_armor_profile` | `run_era_checks` / `_binding_` / `_network_` |
| 定向破片 | `fragment_system`、`spall_profile` | `run_spall_checks` / `_content_` |
| APHE 延迟引信 | `shell_fuze`、`shell_effect_policy` | `run_fuze_checks` |
| 弹药舱/弹架损失 | `ammo_compartment_profile`、`ammo_inventory` | `run_ammo_compartment_checks` |
| 装填/待发架/搬运 | `loading_rules`、`ammo_inventory` | `run_loading_checks` |
| 模块/乘员/能力损失 | `damage_resolver`、`vehicle_capabilities`、`crew_roster` | `run_damage_checks`、`run_track_damage_checks` |
| 回放与状态对应 | `shot_record_builder`、各 `*_record_validator`、`ReplayView` | `run_replay_checks`、`run_material_replay_checks` |

**核查结果**：`02` §07 要求的全部夹具类别（标准板 / 复合 / 一次 ERA / 重复命中 / 空架满架 / 引信离体起爆）在生产代码中**均已存在且有对应套件**；本轮以**当前树全量重跑**确认其真实通过，未发现需要补的实现缺口。

## 2. 本单改动（仅证据与文档，零运行时代码改动）

| 类型 | 文件 | 说明 |
|---|---|---|
| 新工具 | `tests/export_engagement_record.gd` | 真实实验室发射 → 生产 `ShotRecordCodec` 编码 → 解码往返校验 → 落盘事件 JSON |
| 文档 | `docs/wt/continuation/SHELL_ARMOR_MATRIX.md` | **弹族×防护/后效用例矩阵**（逐格引用本轮真实标签） |
| 文档 | `docs/wt/continuation/PILOT_COMBAT_CHAIN.md` | **样车命中—能力—恢复链报告**（7 环节 + 4 项阻断条件专项） |
| 文档 | 本页 | 设计页与边界 |
| 证据 | `logs/WT-012-r1/*.log`（18 份）+ `engagement_record.json` | 全量重跑与事件 JSON |

## 3. 本轮验证（当前树，全部 exit 0）

**18 套件 / 1217 项检查 / 0 失败**：
`run_armor_checks` 81 · `run_long_rod_checks` 56 · `run_long_rod_content_checks` 24 · `run_long_rod_damage_checks` 57 · `run_spall_checks` 78 · `run_spall_content_checks` 33 · `run_chemical_checks` 92 · `run_chemical_content_checks` 31 · `run_composite_checks` 117 · `run_era_checks` 73 · `run_era_binding_checks` 119 · `run_fuze_checks` 137 · `run_loading_checks` 62 · `run_ammo_compartment_checks` 63 · `run_material_replay_checks` 43 · `run_replay_checks` 73 · `run_track_damage_checks` 21 · `run_damage_checks` 57

阻断条件专项（重复毁伤 / 弹药复制 / 空架殉爆假阳性 / 换生命旧位姿）逐条对应到真实标签，见 `PILOT_COMBAT_CHAIN.md` §2。

## 4. 兼容与回滚

- 无运行时改动 → 无存档/协议/内容迁移；回滚 = 删除新工具与三份文档。
- 事件 JSON 为**新增只读产物**，不被任何生产代码消费。

## 5. 明确不做 / 未运行（如实）

- **不重写**任何现代毁伤公式；**不改**战斗参数（含 `GUN_RANGE`、`HISTORICAL_PROJECTILE_RANGE_M`、冷却、伤害）。
- 不把未知现实参数伪装成已核验精确值（沿用 `WT013_DELAYED_FUZE.md` 的 `game_rule` / `historical_value=null` 口径）。
- **网络套件未跑**：`run_era_network_checks`(58)、`run_network_fire_control_checks`(35) 等 → `NOT_RUN`。
- 现代两车整车链 `NOT_RUN`（仍是 `candidate_only`、无 `combat_definition`）。
- 真人体验 `NOT_RUN`；性能 `HOLD_BY_USER`，未采集 FPS/p95/p99。
- 导出记录的终止原因为 `impact_world`（实验室墙体遮挡源车—靶车视线），**不宣称车辆命中**；车辆命中证据由 §1 套件承担。
