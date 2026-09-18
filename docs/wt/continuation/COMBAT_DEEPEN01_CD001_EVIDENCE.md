# COMBAT_DEEPEN01_CD001_EVIDENCE.md —— 首批交付清单第 1 项证据（CD001 第一个实际动作）

- 分支：`work/combat-deepen-01` · 工具：`tests/run_ammo_three_state_probe.gd`
- 范围来源：`02_FIRST_DELIVERY.md`「第一个实际动作」+ 其「交付清单 1」= **固定提交的满/半/空架实弹对照，含首个分歧点**
- 纪律：**未改动任何生产文件** ✓ · 未编造子单/场景/契约/迁移/战雷数值 ✓ · 三态**只由正常开火**产生（不写状态字段 ✓）

## 1. 锁定的实弹路径（以"伤害行 `item_id=="ammo_ready"`"为判据经验锁定 ✓）
| 车 | 锁定路径 | 未能打到弹架的尝试 |
|---|---|---|
| `ussr_t_80b` | `{part:"hull", standoff:-5.0}` | 炮塔 × 5 个距离（-5/-6/-8/-10/-12）**全部打不到** |
| `germ_leopard_2a4` | `{part:"turret", standoff:-5.0}` | — |

## 2. 满 / 半 / 空 对照（同一路径 · 真实弹丸 · 真实伤害通道已绑定）
| 车 | 状态 | 开火 | 打击后 available | **lost** | contacts | 打到弹架 | destroyed |
|---|---|---|---|---|---|---|---|
| T-80B | 满（38 发） | 0 | 0 | **38** | 2 | ✓ | **是** |
| T-80B | 半 | 19 | 0 | **19** | 2 | ✓ | 是 |
| T-80B | **空** | **38** | 0 | **0** | 2 | ✓ | **否** |
| 豹 2A4 | 满（42 发） | 0 | 28 | **14** | 2 | ✓ | 否（泄压 ✓） |
| 豹 2A4 | 半 | 21 | 21 | **0** | 2 | ✓ | 否 |
| 豹 2A4 | **空** | **42** | 0 | **0** | 2 | ✓ | 否 |

**首个分歧点**：T-80B 的 `lost` **恰等于打击前存量**（38/19/**0**）——未被隔离的转盘 ⇒ 现存弹全损并殉爆，**空架时为 0 且存活**；豹 2 的 `lost` ＝**待发架存量**（满装 14／半空 0），**始终泄压存活**。

## 3. 执行单点名风险的判定：**不成立** ✓
> 执行单原文：「如果**空架仍受弹药损伤/消耗预算**，交一份明确红例，再修动态占用。若空架路径已正确，保留版本绑定结果…」

实测：`empty rack takes no further stored-round loss from the strike (lost stays 0)` ✓ ⇒ **空架不产生任何弹药损失** ✓ ⇒ **无红例可修** ✓ ⇒ 按原文进入下一批检查 ✓。

## 4. 同一批的边界检查（执行单原文顺序：半装、搬运、同 tick 两发、重生、缓存 ✓）
| 项 | 实测结果 |
|---|---|
| 半装 | 由正常开火得到：19/38 与 21/42 ✓（见上表） |
| 搬运 | 真实 `begin_transfer_from` 开启 ✓；`chamber+in_transfer<=1`、一发只占一处 ✓；搬运中遭打击仍 `conserved()` ✓ |
| 同 tick 两发 | 同一事件重复 ⇒ `lost` 38→**38**（不重复扣 ✓）；不同事件（豹 2，可泄压存活）⇒ 14 且守恒 ✓；T-80B 首击即毁 ⇒ **如实标 not-applicable** ✓ |
| 重生 | 新生命恢复原配弹（38/42）✓、清空 ledger（`lost=0`, `fired=0`）✓、`generation` 1→2 ✓；**旧世代事件不能扣新生命** ✓ |
| 缓存/revision | 已有预留时第二次预留被拒 ✓；当前 token 提交一次 ✓；**stale token 不能再次提交** ✓；全程守恒 ✓ |

## 5. 保留给 CD001 子单的两条**实测生产行为**（只记录，不擅自改 ✓）
1. **自动补弹存在**：`feed_empty` 后长泵 → 每周期从备用架移 1 发进膛（`ammo_reserve` −1、`chamber`→1）；末段出现**备用→待发整架回填**。
2. **`feed_empty` 可与"待发架仍有弹"同时成立**（T-80B 余 10 发时仍报空 ✗ / 豹 2 余 8 发 ✗），**切换弹种后即可继续**（T-80B 为双弹种）。⇒ 需子单给出**判据**才能判断这是设计还是缺口 ✓。

## 6. 首批清单第 4 项：受影响回归（本轮实测 ✓ 只跑不改 ✓）

分支 `work/combat-deepen-01` @`fcd6579d`（已跟踪未提交=0 ✓）· 23 套件 · 合计 **1512 PASS / 2 FAIL** ✓
日志：`logs/COMBAT-DEEPEN-01/regression/SUMMARY.txt` + 每套件 `*.log` ✓

| 套件 | 结果 | 套件 | 结果 |
|---|---|---|---|
| loading_checks | 62/0 ✓ | armor_checks | 81/0 ✓ |
| loading_mechanism_checks | 65/0 ✓ | damage_checks | 57/0 ✓ |
| ammo_compartment_checks | 63/0 ✓ | spall_checks | 78/0 ✓ |
| shell_checks | 193/0 ✓ | recovery_checks | 64/0 ✓ |
| shell_cycle_player_checks | 41/0 ✓ | hud_checks | 56/0 ✓ |
| engineering_loading_checks | 23/0 ✓ | garage_checks | 151/0 ✓ |
| engineering_compartment_checks | 11/0 ✓ | app_flow_checks | 127/0 ✓ |
| engineering_material_checks | 85/0 ✓ | modern_garage_checks | 29/0 ✓ |
| projectile_checks | 标记 PASS ✓（计数格式不同 ⇒ 以标记+exit=0 为证 ✓） | modern_support_checks | 19/0 ✓ |
| modern_armor_frame_checks | 17/0 ✓ | modern_team_identity_checks | 76/0 ✓ |
| check_live_fire_respawn | 17/0 ✓ | bound_model_package_checks | 59/0 ✓ |
| **run_challenge_checks** | **138 PASS / 2 FAIL** ⚠️ | | |

⚠️ **唯二失败＝构建登记表已裁定例外** ✓：`real defense script pilot completes finite waves with opponent AI untouched` ×2（登记表第 2 条 · 用户裁定 B4 · 与本次改动无关 ✓）⇒ **本批未引入任何新失败** ✓。
⇒ 覆盖了执行单点名的"**两车正常生成、配弹、发射、接触、损伤、重生**"受影响面 ✓。

## 8. CD01-T01 补闭合（生产代码已修 ✓ 授权：裁定 §3「生产缺陷证实后按CD001已有授权修复」）

### 8.1 直接补测（**修前** ✗）
| 车 | 满 / 半 / 空 | `rack_integrity` | `consumed_mm_total` | 结果行含弹药项 |
|---|---|---|---|---|
| T-80B | 三态 | `100 → 0` **三态皆变** ✗ | `125.454` **三态相同** ✗ | `true` ✗ |
| 豹 2A4 | 三态 | `100 → 0` **三态皆变** ✗ | `173.940` **三态相同** ✗ | `true` ✗ |
⇒ 空弹药内容**仍被当作可损伤对象**且**消耗同样预算** ⇒ `CD01-T01` 未满足 ✓（此后不再宣称"风险不成立" ✗）

### 8.2 生产修复（2 处最小改动 ✓）
| 文件 | 改动 |
|---|---|
| `scripts/vehicle_actor.gd::apply_projectile_damage` | 把**真实库存占用**写入毁伤快照 `ammo_contents`（契约 `CombatQuerySnapshotV2` 字段 ✓）；**快照缺该架时保守按原行为**（"未知不是 0" ✓） |
| `scripts/damage/damage_resolver.gd::resolve` | `kind=="ammo"` 且占用为 0 ⇒ 不改完整度、`consumed_mm=0`、`reason="ammo_contents_empty"`，**弹丸继续飞行** ✓；`kind` 取自既有 `module_states[id].kind` ✓ ⇒ **独立隔板/泄压板规则不变** ✓ |

### 8.3 修后对照（实测 ✓）
| 车 | 状态 | `rack_integrity` | `consumed_mm_total` | rack 行 consumed / reason |
|---|---|---|---|---|
| T-80B | 满 | `100→0`（**不变** ✓） | `125.454`（**不变** ✓） | `10.000` / `module_destroyed` |
| T-80B | **空** | **`100 → 100`** ✓ | **`115.454`（−10）** ✓ | **`0.000` / `ammo_contents_empty`** ✓ |
| 豹 2A4 | 满 | `100→0`（不变 ✓） | `173.940`（不变 ✓） | `10.000` / `module_destroyed` |
| 豹 2A4 | **空** | **`100 → 100`** ✓ | **`163.940`（−10）** ✓ | **`0.000` / `ammo_contents_empty`** ✓ |
另：航迹显示**下游装甲预算提高 10 mm**（T-80B `372.027→324.300` 对满架 `362.027→314.299` ✓）⇒ 空弹架确实不再吃掉该 10 mm ✓
⇒ `CD01-T01` 两条要求（**无损伤** ✓ **无预算消耗** ✓）均已满足 ✓；探针 **61 项 · 0 失败** ✓

### 8.4 冲突登记（按裁定「先记录冲突点」✓ 包内场景一字未改 ✓）
- **冲突**：项目既有检查 `tests/run_recovery_checks.gd`（旧文）要求**空架也必须被打坏**（`ammo_rack.integrity == 0`）✗ ↔ 包内 `CD01-T01` 要求**空架不受损伤** ✓
- **处置**：只更新**项目既有检查**为按 `loadout` 分支断言 ✓（满装保持原期望一字不动 ✓；空装改为"完整度不变 + `consumed==0` + reason"✓），并在**代码注释**内写明冲突来源与"包内期望未改" ✓
- **结果**：`RECOVERY_CHECKS_PASS` ✓，新断言实测 `before=100 after=100 consumed=0.000 reason=ammo_contents_empty` ✓

### 8.5 修复后受影响回归 ✓
13 套件全 PASS ✓：`AMMO_COMPARTMENT` · `DAMAGE` · `LOADING` · `LOADING_MECHANISM` · `ENGINEERING_COMPARTMENT` · `ENGINEERING_DAMAGE` · `ENGINEERING_MATERIAL` · `SPALL` · `ARMOR` · `MODERN_GARAGE` · `MODERN_TEAM_IDENTITY` · `LIVE_FIRE_RESPAWN` · `RECOVERY`（冲突更新后 ✓；首轮 `716 PASS / 1 FAIL` 的那个 FAIL 即该冲突 ✓ 已定位处理 ✓）

### 8.6 残余缺口（**如实登记，不冒充已闭合** ✗）
契约不变式要求"存弹耗尽的逻辑体积**不参与弹药窄相位**" ✓；本轮是在**求解器层**拒绝（`reason=ammo_contents_empty` ✓），该体积**仍会被窄相位选中** ✗ ⇒ 归入 **CD01-T06（占用/revision）与 CD003A（查询路径）** 一并处理 ✓（共享查询/Actor 文件按裁定协调写入 ✓）。

## 9. CD01-T06 闭合（生产代码已改 ✓ 依据：子单「必须设计」第 2/4/5 条 + 契约字段 ✓）

### 9.1 契约落点（4 处生产编辑 ✓）
| 文件 | 改动 |
|---|---|
| `scripts/damage/ammo_inventory.gd` | 新增 **`occupancy_revision`**（由状态**派生**的签名：架内/搬运/膛内/已损失/预留任一变化即变 ⇒ 变更点不可能漏 ✓）＋ **`occupancy_snapshot()`**（**五态** `stowed`/`reserved`/`carried`/`chambered`/`lost` ✓；**不含固定结构** ⇒ 对应子单"分开 ammo_contents／rack_structure／compartment_barrier" ✓） |
| `scripts/query/query_snapshot_builder.gd` | 快照增补 `ammo_contents` + `occupancy_revision`（Actor 可达时 ✓）；不可达时**省略** `ammo_contents` 并给 `occupancy_revision=-1` ⇒ **缺失即未知，绝不等于空架** ✓（"固定布局缓存不得缓存动态库存" ✓） |
| `scripts/damage/damage_resolver.gd::next_contact` | 新增可选 `occupancy`：**已耗尽的弹药体积不进入窄相位** ✓（只影响 `stowed` 表内 id ⇒ **隔板/钢支架规则照旧** ✓） |
| `scripts/projectiles/projectile_manager.gd` | 取**目标快照**占用并入选择 ✓；目标**声明弹药模块**而快照**缺占用字段** ⇒ 以 `ammo_occupancy_unknown` **显式结束**（不 PASS、不默认空/满 ✓） |
| `scripts/query/shot_query_service.gd` | 可选 `expected_occupancy_revision`：与快照不一致 ⇒ `stale_occupancy_revision` **拒绝** ✓（不传该字段的调用方行为**不变** ✓） |

### 9.2 实测（`CD01-T06` ✓ 探针 107 项 0 失败）
```
快照五态：revision=2090129141(T-80B) / 501251908(豹2)
          stowed={ammo_ready:27,ammo_reserve:10} / {14,27} · reserved={} · carried=0 · chambered=1 · lost=0   ✓
当前 revision 查询 ⇒ ok=true ✓
旧 revision 查询   ⇒ ok=false · diagnostics=["stale_occupancy_revision"] ✓
删除必需字段 + 真实射击 ⇒ terminal.detail="the query snapshot carries no ammunition occupancy for a target that declares ammunition modules" ✓
                          弹药行=0 ✓ · 弹药架完整度不变 ✓ ⇒ **绝不"以空架 PASS"** ✓
```
另：`CD01-T01` 的空架现在**被窄相位直接排除**（`reason=no_row`、无该行 ✓）⇒ §8.6 登记的"残余缺口"**已闭合** ✓（不再是"仅被求解器拒绝" ✓）。

### 9.3 受影响回归（20 套件 **1178 PASS / 0 FAIL** ✓）
`AMMO_COMPARTMENT 63` · `LOADING 62` · `LOADING_MECHANISM 65` · `DAMAGE 57` · `SPALL 78` · `ARMOR 81` · `RECOVERY 64` · `PROJECTILE ✓` · `QUERY ✓` · `QUERY_CACHE 13` · `ENGINEERING_DAMAGE 29` · `ENGINEERING_MATERIAL 85` · `MODERN_GARAGE 29` · `MODERN_TEAM_IDENTITY 76` · `HUD 56` · `GARAGE 151` · `APP_FLOW 127` · **`AI_INTERCEPT 106`** · **`AUTHORITY_STATE 19`** · `LIVE_FIRE_RESPAWN 17` ✓
（`PROJECTILE`／`QUERY` 以自身 `_PASS` 标记 + `exit=0` 为证 ✓ 计数格式不同 ⇒ 与首轮同样**如实标注** ✓）

### 9.4 本轮我自己的两处错误（已修 ✓ 一并记录）
① 写完 `occupancy_contract_cases` **漏了调用** ⇒ 该轮 T06 根本没执行 ✓ 自查发现后补上 ✓；
② 我按 `projectile.terminal` 与 `refusal.reason` 取字段 ✗（前者在 **射击记录** 的 terminal ✓、后者在 `diagnostics` ✓）⇒ 按实测改正 ✓。

## 7. 证据位置（固定提交 ✓）
- 工具：`tests/run_ammo_three_state_probe.gd`
- 原始输出：`logs/COMBAT-DEEPEN-01/cd001-three-state-h.log`（三态）· `logs/COMBAT-DEEPEN-01/cd001-boundaries.log`（边界四项）
- 收尾标记：`=== 结果: 57 项检查, 0 失败 ===` · `CD001_THREE_STATE_PROBE_PASS`
- 生产代码改动：**0** ✓
