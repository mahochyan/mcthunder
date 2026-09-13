# 弹族 × 防护/后效 用例矩阵（WT-012-R1）

- 依据：`02_首轮10张执行单.md` §07「必须交付：弹族×防护/后效用例矩阵」
- 生成方式：**本单在当前树（`work/continuation-20260913`）重跑 18 个相关套件**，全部 exit 0；下表每格引用该次运行的真实通过标签（日志在 `logs/WT-012-r1/`）
- 合计：**1217 项检查，0 失败**

## 1. 矩阵

| 弹族 / 规则 | 生产路由 | 套件（本轮） | 结果 | 关键用例（本轮实际标签） |
|---|---|---|---|---|
| AP 标准板 / 角度 / 材质 | `armor_resolver`、`armor_impact_profile` | `run_armor_checks` | **81/81** | `unknown plate conservatively stops actual flight`；`contact callback reset stops continuation and duplicate terminal` |
| APHE 延迟引信（车内外） | `shell_fuze`、`shell_effect_policy` | `run_fuze_checks` | **137/137** | `threshold inclusive; later armor never resets armed delay`；`armed projectile arrested by rear armor / internal module / world`；`removed target detonation has valid replay without invented geometry`；`production replay opens actual exterior detonation`；四种步长（1/30、1/60、1/144、0.001 s）均 `replay validates` |
| 长杆 APFSDS（long rod） | `armor_impact_profile` 长杆分支 | `run_long_rod_checks` / `_content_` / `_damage_` | **56 / 24 / 57** | `actual complete long-rod replay validates`；`replay independently catches changed angular resistance`；`mixed normal firing conserves physical ammunition` |
| 化学射流 HEAT | `chemical_jet_system`、`chemical_profile` | `run_chemical_checks` / `_content_` | **92 / 31** | `damage callback stops jet and reset prevents late damage`；`reject inconsistent chemical replay: budget/path/direction/link/time/version/damage_budget/carrier_direction/trigger_frame`；`viewing jet replay never repeats live damage` |
| 被动复合装甲（分层通道） | `armor_layer_profile`、`vehicle_armor_layers` | `run_composite_checks` | **117/117** | `replay rejects mismatched frozen composite response: contact_profile/frame_profile/layer_version/layer_channel/coefficient/moved_layer` |
| 单次 ERA（权威一次消耗） | `reactive_armor_profile` | `run_era_checks` / `_binding_` | **73 / 119** | **`duplicate authoritative transaction cannot apply twice`**；**`stale query generation is rejected through the actual projectile authority path`**；`reentrant reset prevents late records or damage after atomic armor call`；`seeking ERA replay cannot consume or restore live vehicle charge`；`vehicle reset restores independently initialized charge` |
| 定向破片（穿后） | `fragment_system`、`spall_profile` | `run_spall_checks` / `_content_` | **78 / 33** | `same shot seed reproduces real directions after reset`；`production replay opens actual directional-spall shot`；`seeking spall replay never repeats live damage`；`reject inconsistent spall replay: budget/origin/direction/link/version/frame/family/missing_fragment` |
| 弹药舱 / 弹架损失 | `ammo_compartment_profile`、`ammo_inventory` | `run_ammo_compartment_checks` | **63/63** | **`lost source or destination cancels stale transfer without duplication`**；**`actual damage obeys isolation and inventory state: empty`**；`replay rejects altered rack transaction: negative/float/missing/reserve/health/amount` |
| 装填 / 待发架 / 搬运 | `loading_rules`、`ammo_inventory` | `run_loading_checks` | **62/62** | **`destination reservation prevents duplicate move and external overflow`**；**`reconfiguration cannot revive a stale reservation token`**；**`broken in-progress mechanism cannot fire an empty chamber`**；**`same-tick recovery fire commits before loading completion and prevents a stale-capability chamber`**；`reset restores original typed loadout and three-person configuration` |
| 弹药守恒 | 生产 `Gunner` + `ProjectileManager` | `run_long_rod_content_checks` / `run_chemical_content_checks` / `run_spall_content_checks` | **24 / 31 / 33** | **`mixed normal firing conserves physical ammunition`**（三套件均有）；`reset restores initial mixed loadout and original chamber` |
| 回放与状态一致性 | `shot_record_*`、各 `*_record_validator` | `run_replay_checks` / `run_material_replay_checks` | **73 / 43** | `replay rejects altered contact effective_mm/path_thickness_mm/adjusted_angle_deg/material_multiplier/angle_deg/after_mm`；`fragment cannot acquire parent overmatch in replay`；**`ten replays do not alter real damage, ammunition or hits`**；`overflow shows unavailable instead of a truncated fake replay`；`record remains replayable after actual target deletion` |
| 履带/模块失能与恢复 | `damage_resolver`、`vehicle_capabilities`、`vehicle_recovery` | `run_track_damage_checks` / `run_damage_checks` | **21 / 57** | `reset restores both independent track abilities`；`reset callback cannot leave late damage or duplicate finish`；`actual path 5cm outside module misses it` |

## 2. 与裁决口径的对应

| 02 §07 必须验证 | 对应证据（本轮） |
|---|---|
| 标准板 / 复合 / 一次 ERA / 重复命中 / 空架满架 / 引信离体起爆各有夹具 | 逐格见上；重复命中 → ERA `duplicate … twice`；空架 → `empty chamber` / `inventory state: empty`；引信离体 → `exterior detonation` / `removed target detonation` |
| 同一发日志、状态变化与回放对应 | `run_replay_checks` 73、`run_material_replay_checks` 43、以及各家族的 replay 拒绝篡改用例 |
| 断带/失能/起火后的操作限制和恢复真实执行 | `run_track_damage_checks` 21、`run_damage_checks` 57、`run_loading_checks` 62（`reset restores original typed loadout`） |
| **未用写伤害/清冷却/换 resolver 过关** | 全部用例走生产 `Gunner`/`ProjectileManager`/`armor_resolver`/`VehicleActor` 路径；本轮**零运行时代码改动**（不含"作弊式"修正），仅新增导出工具与文档 |

## 3. 未覆盖 / 边界（如实）

- **网络 ERA / 网络弹道**：`run_era_network_checks`（58 项）等网络套件本单**未跑**（`NOT_RUN`）。
- 现代两车（T-80B / 豹 2A4）仍是 `candidate_only`、`combat_definition` 为空 → **现代弹族只在标准夹具验证**，不给样车强装不存在弹（与 `WT013_DELAYED_FUZE.md:31` 一致）。
- 回放仍为步末静态几何近似；有限体积、时变内构连续求交未实现（沿用 `WT013_DELAYED_FUZE.md:42` 的边界声明）。
