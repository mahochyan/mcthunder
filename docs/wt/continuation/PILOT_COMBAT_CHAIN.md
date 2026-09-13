# 样车命中—能力—恢复链报告（WT-012-R1）

- 依据：`02_首轮10张执行单.md` §07「必须交付：样车命中—能力—恢复链报告」
- 口径：「样车」= **已准入的 4 辆历史车**（`VehicleCatalog.IDS`）。现代两车（T-80B/豹 2A4）为 `candidate_only` 且 `combat_definition` 为空，**不在本链上**（见 §5）。
- 全部证据来自本单在当前树的重跑（`logs/WT-012-r1/`），合计 **1217 项检查 0 失败**。

## 1. 链条（每步的生产实现与证据）

| 环节 | 生产实现 | 本轮证据（标签） |
|---|---|---|
| ① 命中与装甲结算 | `armor_resolver` / `armor_impact_profile` / `penetration_curve` | `run_armor_checks` 81：`unknown plate conservatively stops actual flight`；`run_material_replay_checks` 43：`replay rejects altered contact effective_mm / adjusted_angle_deg / after_mm` |
| ② 后效（长杆/射流/破片/引信） | `shell_effect_policy`、`chemical_jet_system`、`fragment_system`、`shell_fuze` | 长杆 56/24/57；化学 92/31（`damage callback stops jet and reset prevents late damage`）；破片 78/33（`same shot seed reproduces real directions after reset`）；引信 137（`armed projectile arrested by rear armor / internal module / world`、`production replay opens actual exterior detonation`） |
| ③ 模块/乘员能力损失 | `damage_resolver`、`vehicle_capabilities`、`crew_roster` | `run_damage_checks` 57（`actual path 5cm outside module misses it`）；`run_track_damage_checks` 21（`reset restores both independent track abilities`） |
| ④ 弹药与装填约束 | `ammo_inventory`、`loading_rules`、`ammo_compartment_profile` | `run_loading_checks` 62：`broken in-progress mechanism cannot fire an empty chamber`、`same-tick recovery fire commits before loading completion and prevents a stale-capability chamber`、`reset restores original typed loadout and three-person configuration` |
| ⑤ 恢复（维修/灭火/换位/补弹） | `vehicle_recovery`、`ammunition_supply`、`RecoveryRules` | `run_ammo_compartment_checks` 63：`lost source or destination cancels stale transfer without duplication`、`actual damage obeys isolation and inventory state: empty`；`run_loading_checks`：`reconfiguration cannot revive a stale reservation token` |
| ⑥ 结算与回放 | `shot_record_builder`、各 `*_record_validator`、`ReplayView` | `run_replay_checks` 73：`ten replays do not alter real damage, ammunition or hits`、`overflow shows unavailable instead of a truncated fake replay`、`record remains replayable after actual target deletion` |
| ⑦ 守恒与重置 | 生产事务 + 重置路径 | 三套内容套件：`mixed normal firing conserves physical ammunition`、`reset restores initial mixed loadout and original chamber`；ERA：`vehicle reset restores independently initialized charge`、`reentrant reset prevents late records or damage after atomic armor call` |

## 2. 阻断项专项（`02` §07 停止条件）

| 停止条件 | 本轮对应证据 | 判定 |
|---|---|---|
| 重复毁伤 | ERA `duplicate authoritative transaction cannot apply twice`；damage `reset callback cannot leave late damage or duplicate finish`；各家族 `… replay never repeats live damage` | **未发现** |
| 弹药复制 | loading `destination reservation prevents duplicate move and external overflow`；content `mixed normal firing conserves physical ammunition`；compartment `replay rejects altered rack transaction: negative/float/missing/reserve/health/amount` | **未发现** |
| 空架殉爆假阳性 | loading `broken in-progress mechanism cannot fire an empty chamber`；compartment `actual damage obeys isolation and inventory state: empty` | **未发现** |
| 换生命后命中旧位姿 | ERA **`stale query generation is rejected through the actual projectile authority path`**；era_binding `actual reset restores bound turret, stock and original hull parent`；WT-002-R1 亦已单独验证身份陈旧命令被拒 | **未发现** |

## 3. 实际事件 JSON（交付物）

- 工具：`tests/export_engagement_record.gd`（真实实验室发射 → 生产 `ShotRecordCodec` → 往返校验 → 落盘）
- 产物：`logs/WT-012-r1/engagement_record.json`（1085 B）
- 实测：`fire accepted=true`、弹药 29→28、记录 830 字节、**`decode_matches_encode=true`（编码/解码无损）**
- 终止原因：`impact_world`——实验室源车与靶车之间**有遮挡墙**（`AICombatRange` 的墙体夹具），故本次导出记录落在世界碰撞；车辆命中链的证据由 §1 各套件承担（不含伪造命中）。

## 4. 未通过"写伤害/清冷却/换 resolver"过关的说明

- 本轮**零运行时代码改动**：未修改 `armor_resolver`、`damage_resolver`、`ProjectileManager`、`Gunner` 或任何伤害/冷却参数。
- 所有用例通过生产命令消费者与生产发射路径；失败/反例（`reject …`、`5cm outside`、`cannot revive a stale token`）均保留在日志中。

## 5. 现代两车为何不在链上（如实）

| 项 | 状态 |
|---|---|
| `ussr_t_80b` / `germ_leopard_2a4` | `admission=candidate_only`、`historical_verified=false`、`combat_definition=null`（`PILOT_CANDIDATE_REPORT.md`） |
| 现代弹族（APFSDS/HEAT/复合/ERA/装填机制） | 已在**标准夹具**验证（本报告 §1 各套件），符合"不给样车强装不存在弹、其余弹族继续在标准夹具验证" |
| 现代整车命中—能力—恢复链 | `NOT_RUN`（需先补齐 7 条作者缺口与整车战斗包；属 WT-016/WT-030/WT-031 范围） |
