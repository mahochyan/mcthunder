# COMBAT_DEEPEN01_BASELINE.md —— MCT-COMBAT-DEEPEN-01 阶段 1 基线清单（只读勘察）

- 分支：`work/combat-deepen-01`（自最新获准主线 `main` = `3b2fe165a69e1a777c5c4d02b852b7e5438e3388` 新建 ✓）
- 方法：**纯只读**勘察（读文件 + `git grep` 调用点），未改任何实现 ✓
- 状态：**阶段 1 的"基线清单"部分完成**；"按 16 子单排依赖图"部分**阻塞** —— 执行包未到位（见文末）。
- 纪律：本文件只记录**实测事实**（文件:行 可复核 ✓）；凡属我的**观察/疑点**单列一节并标注"观察"，**不冒充执行包要求** ✓。

---

## 1. 五块的实现位置与入口（实测 ✓）

### 1.1 弹药（含装填、隔舱、配装服务）
| 角色 | 位置 | 入口 / 数据结构 |
|---|---|---|
| 库存与三态 | `scripts/damage/ammo_inventory.gd`（10,463 B） | `class_name AmmoInventory`；`racks` / `chamber` / `in_transfer` / `rack_capacities` / `allowed_shells`；`configure_loadout(counts, rack_ids, capacities, first_shell, distribution)`、`total_available()`、`static proportional_allocation(left, room)` |
| 装填机构（按车） | `scripts/damage/loading_mechanism.gd`（11,351 B） | `STATES`(8) / `CHANNELS=["loader","mechanism","power","breech","fire"]` / `MECHANISMS` / `VEHICLES` / `INVENTORY_MAPPING`；`mechanism_for()`、`definition_for()`；车级：`ussr_t_80b`=autoloader_carousel(ready 28/reserve 10)、`germ_leopard_2a4`=manual_loader(ready 15/reserve 27)（两者 `admitted:false`） |
| 装填规则门 | `scripts/damage/loading_rules.gd`（1,479 B） | `static compute(profile: LoadingProfile, state) -> Dictionary`、`module_available(state,id)` |
| 装填剖面（数据） | `scripts/defs/loading_profile.gd`（6,444 B） | `initial_rack_order()`、`validate()`、`static from_packet()`、`validate_bindings(layout)` |
| 弹种定义 | `scripts/defs/shell_definition.gd`（3,661 B） | `validate()`（Resource） |
| 隔舱/弹药舱政策 | `scripts/damage/ammo_compartment_profile.gd`（9,522 B） | `VERSION="wt015-rear-bustle-v1"`；`validate()`/`check(packet)`/`can_vent(policy,state,ammo,rack)`/`valid_record(event)`；**明确排除搬运中**：`in_transfer>0 and transfer_from==rack ⇒ false`（:53、:88） |
| 配装服务（唯一提交口） | `scripts/garage/garage_service.gd`（4,492 B） | `default_loadout(id)`、`build_loadout(value)`（**校验+拒绝原因**）、`install(vehicle, loadout)` |
| 弹种目录 | `scripts/content/vehicle_shell_catalog.gd`（10,654 B）、`scripts/content/historical_shell_catalog.gd`（6,421 B） | 目录数据 |

### 1.2 装甲
| 角色 | 位置 | 入口 |
|---|---|---|
| 命中求解 | `scripts/armor/armor_resolver.gd`（5,711 B） | `static resolve(contact: Dictionary, direction: Vector3, budget: Dictionary) -> Dictionary`；输出含 `rules_version = GameConfig.ARMOR_RULES_VERSION` |
| 被动复合层剖面 | `scripts/armor/armor_layer_profile.gd` | `VERSION="wt012-passive-composite-v1"`、`CHANNELS=["kinetic","chemical","fragment"]`；`response(value, projectile, thickness, angle)` |
| 全口径/长杆/化学剖面 | `scripts/armor/armor_impact_profile.gd`（8,771 B） | `VERSION="wt012-full-caliber-v1"`、`LONG_ROD_VERSION="wt012-long-rod-v1"`、`CHEMICAL_VERSION="wt012-chemical-v1"`、`UNIT="game_rha_equivalent_mm"`；`validate()`、`response(profile,material,caliber,thickness,angle)`、`fragment_profile(parent)` |
| 反应装甲 | `scripts/armor/reactive_armor_profile.gd` | `VERSION="wt012-reactive-v1"` |
| 穿深曲线 | `scripts/armor/penetration_curve.gd` | `validate(points)`、`sample_mm(points,distance_m)` |
| 车体装甲数据 | `scripts/content/vehicle_armor_layers.gd`（6,802 B） | 层数据 + 断言 `claim.origin=="game_rule" && status=="estimated"`（:53） |
| 几何/补片 | `scripts/layout/armor_patch_definition.gd`、`armor_patch_mesh.gd`、`layout_validator.gd`（39,229 B） | 逻辑区/补片/校验 |

### 1.3 毁伤（穿后）
| 角色 | 位置 | 入口 |
|---|---|---|
| 内构毁伤求解 | `scripts/damage/damage_resolver.gd`（3,338 B） | `static target_key(event)`、`item_key(event)`、`next_contact(query,interior,seen,before_distance)`、`resolve(event, available_mm, snapshot)` |
| 破片/喷流/引信 | `scripts/projectiles/spall_profile.gd`（`wt013-directional-spall-v1`）、`shell_effect_policy.gd`（`021-toy-inside-v1`）、`shell_fuze.gd`（`wt013-delay-v1`）、`chemical_profile.gd`（`wt013-chemical-jet-v1`） | 破片分配/方向、内爆效应、延时装定 |
| 模块/乘员数据 | `scripts/layout/module_volume_definition.gd`、`scripts/damage/crew_roster.gd`、`scripts/damage/vehicle_capabilities.gd`（能力输出，:64 调 `LoadingRules.compute`） | 模块体、乘员分配、能力汇总 |

### 1.4 战损能力（修复/灭火/减员影响）
| 角色 | 位置 | 入口 |
|---|---|---|
| 战损与恢复 | `scripts/damage/vehicle_recovery.gd`（8,039 B） | `static source_from(record)`、`on_direct_damage(state, ammo, record)`、`ignite(state, module_id, source)`、`handle_command(state, cmd, speed)`、`step(state, delta, speed, cmd)` |
| 恢复规则常量 | `scripts/damage/recovery_rules.gd`（880 B） | `VERSION="recovery-test-v1"`；`EXTINGUISH_CHARGES=2`、`EXTINGUISH_SECONDS=4.0`、`REPAIR_SECONDS=12.0`、`REPAIR_TARGET=0.5`、`REPAIR_MAX_SPEED=0.2`、`REPLACEMENT_SECONDS=8.0`、`FIRE_IGNITION_INTEGRITY=0.25`、`FIRE_TICK_SECONDS=1.0`、`FIRE_MODULE_DAMAGE=0.05`、`FIRE_CREW_EXPOSURE_SECONDS=20.0`、`REPAIR_PRIORITY=[...]` |
| 视觉 | `scripts/damage/recovery_visuals.gd` | `BURN_SECONDS=45`、`SMOKE_SECONDS=60` |
| 支援动作 | `scripts/battle/support_actions.gd`（11,703 B） | 维修/灭火/换人等战场动作 |

### 1.5 结算
| 角色 | 位置 | 入口 |
|---|---|---|
| 进程服务（发奖） | `scripts/garage/progression_service.gd`（2,854 B） | `REWARDS={victory:60,defeat:30,draw:40,abandoned:0}`；`register_match(config)`、`bind_director(token,director)`、`apply_result_once(token,result)` |
| 挑战结算 | `scripts/challenges/challenge_progression.gd`（2,097 B）、`challenge_score.gd` | `settle(attempt_id)`；`evaluate(c,stats,passed)`、`best_row(result)`、`describe_best(row)` |
| 网络收据/权威 | `scripts/network/network_result_receipt.gd`（4,122 B） | `TRUST_SERVER/HOST`、同款 `REWARDS`；`issue(...)`、`claim(token,digest)`、`trusted_result_tokens()`、`domains()` |
| 流程终点 | `scripts/core/app_flow.gd:457-458` | `func _settle_match(token,result)` → **`progression.apply_result_once(token,result)`（实测全仓唯一发奖调用点，2 处命中=定义+调用 ✓）** |

---

## 2. 端到端链路（实测调用点 file:line ✓）

```
瞄准/查询        gunner.gd:180                      ShotQueryService.query({...})   ← 带 _aim_query_cache
                 ai/ai_perception.gd:36/159         ShotQueryService.query(...)     ← AI 预览（同契约 ✓）
                 camera_rig.gd:117/279              ShotQueryService.query(...)     ← 相机防穿（同契约 ✓）
几何命中         query/shot_query_service.gd        query(request, snapshots)
                 query/query_snapshot_builder.gd    build_from_vehicle(vehicle, layout)
                 query/world_query_adapter.gd       query_world_stop(...)
装甲求解         vehicle_actor.gd:228               ArmorResolver.resolve(actual, direction, budget)
                 projectiles/projectile_manager.gd:462-463   ArmorResolver.resolve(...)（含反应装甲分支）
                 projectiles/fragment_system.gd:92  resolve_armor.call(...)         ← 观察①：绑定式调用
                 replay/shot_record_builder.gd:241  ArmorResolver.resolve(...)       ← 回放复算校验
毁伤求解         vehicle_actor.gd:240               DamageResolver.resolve(event, available_mm, damage_snapshot)
战损能力         vehicle_actor.gd:243/249           VehicleRecovery.source_from / on_direct_damage(state, gunner.inventory, record)
                 vehicle_actor.gd:389               VehicleRecovery.step(state, delta, forward_speed, cmd)
能力门           damage/vehicle_capabilities.gd:64 LoadingRules.compute(loading_profile, state)
结算             core/app_flow.gd:458               progression.apply_result_once(token, result)   ← 唯一发奖入口 ✓
记录与版本       projectiles/projectile_manager.gd:599/684  记录 rules_version（damage/armor）
                 replay/shot_record_builder.gd:83/125       记录并校验 rules_versions（armor/damage/recovery）
```

**结论（实测）**：五块**已经在一条链上**（几何→装甲→毁伤→战损→结算），且弹道记录**已携带规则版本**并被回放校验 ✓。**未发现**"另起一套弹药/装甲/伤害旁路"的第二套实现 ✓（发奖仅 1 处 ✓）。

---

## 3. 我的观察（**不是执行包要求**，供定契约时参考 ✓）

- **观察①（旁路风险面）**：`fragment_system.gd:92` 通过**绑定 Callable**（`resolve_armor`）调用装甲求解 ✓。它不是绕过契约，但**调用面是间接的** ⇒ 契约落定后需确认破片路径与主路径**同参数同版本**。
- **观察②（规则版本命名）**：现行 `GameConfig.ARMOR_RULES_VERSION="armor-test-v1"`、`DAMAGE_RULES_VERSION="direct-hit-test-v1"`、`RecoveryRules.VERSION="recovery-test-v1"`、`ShellEffectPolicy.VERSION="021-toy-inside-v1"` —— 均**自称 test/toy** ✗。指令第 7 条要求"新弹道/装甲/伤害/模式有独立规则版本和迁移"，但**迁移条目表与目标版本名属执行包内容** ⇒ **等包**，我不自行命名 ✓。
- **观察③（弹药三态读取面）**：`chamber|in_transfer|racks` 全仓读取点 **46 处** ✓（AI/相机/UI/HUD/回放/挑战都在读）⇒ CD001"膛内/搬运/在架不得双重占用"的**风险面很宽**，修复须同时覆盖这些读取者 ✓。
- **观察④（现代两车 admitted 标记）**：`loading_mechanism.gd:31-32` 两车均为 `admitted:false` ✗ ⇒ 与"最终必需两车"交付要求的关系**需在子单里确认**（我不猜语义 ✓）。
- **观察⑤（旧队标保留面）**：`MatchRulePreset.ID="team_standard_300"`（`match_rule_preset.gd:10-11`）✓ 指令要求保留 ⇒ 迁移时必须**并存**而非替换 ✓。

---

## 4. 现有验收资产（可复用，非新增 ✓）

装填/弹药：`run_loading_checks`、`run_loading_mechanism_checks`、`run_ammo_compartment_checks`、`run_shell_checks`、`run_shell_cycle_player_checks`、`run_engineering_loading_checks`、`run_engineering_compartment_checks`、`run_engineering_material_checks`
装甲/材料：`run_armor_checks`、`run_material_response_checks`、`run_material_replay_checks`、`run_era_checks`、`run_era_binding_checks`、`run_composite_checks`、`run_chemical_checks`、`run_long_rod_checks`、`run_reference_admission_checks`
毁伤/破片：`run_damage_checks`、`run_spall_checks`、`run_fuze_checks`、`run_engineering_damage_checks`、`run_track_damage_checks`
战损/恢复：`run_recovery_checks`、`run_recovery_player_checks`、`run_ai_recovery_checks`、`run_support_actions_checks`
结算/流程：`run_app_flow_checks`、`run_challenge_checks`、`run_match_event_checks`、`run_balance_match_checks`、`run_garage_checks`、`run_modern_garage_checks`
门/包：`tests/build_release.ps1`（`-Candidate -ModernRiver`）+ 登记表（两条已裁定例外）

---

## 5. 阻塞（阶段 1 的依赖图部分 + 阶段 2 起全部）

**执行包缺 6 项**（`07_WORK_ORDERS.json`(CD) · 16 张子单正文 · 96 个验收场景 · 04/05 接口契约 · 规则迁移条目表 · 交付模板[或确认用项目自有那份]）⇒ 已按预案 1 停下并请用户确认 ✓。
**在包到位前**，我只会做**只读**工作（本文件即其一），**不会**：编造子单编号/场景内容/契约字段/迁移条目/战雷数值 ✓；跳过测试改实现 ✓；无对照删旧规则 ✓；改验收期望值 ✓。
