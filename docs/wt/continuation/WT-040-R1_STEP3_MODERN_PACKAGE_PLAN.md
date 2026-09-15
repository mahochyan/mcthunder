# 第 ③ 步计划：两辆现代样车的**战斗包**（用户指令第 1 条）

> 用户要求：「**先补齐两辆样车的战斗包。可从模型测量的轴心、炮口和几何由工具生成并核对；需要设计或资料的字段列清楚，不能全部笼统归为"等待作者"，也不能用通用模板冒充具体车型。**」
> 本文件把每个字段**归类**并写明来源与验收 ✓（不笼统 ✓、不用通用模板 ✓）。

## 1. 现状（实测）
| 对象 | 路径 | 性质 |
|---|---|---|
| 生产战斗包（4 辆历史车 ✓） | `configs/vehicles/historical/<id>.json`（~28 KB） | 14 键：`schema_version, id, display_name, facts, sources, assembly, compatible_shells, geometry, runtime, armor, modules, crew, license, limitations` |
| 两车现有材料 | `assets/reference_data/candidates/{ussr_t_80b,germ_leopard_2a4}.json`（~210 KB） | **研究档案** ✓：`raw_fields, fields, gaps, armor_groups, weapon_references, damage_module_references, crew_roster, ammo_racks, model_candidates, source, historical_verified` |
| 两车模型 | 96 个适配产物（**我生成并自校验** ✓ `delta=0` ✓） | 可用于**实测几何** ✓ |
| 准入闸门 | `ModernModelMountAdapter.SPECS` ⇒ `preview_only` ✗；`admission == "candidate_only"` ⇒ `not_applicable` + `config_incomplete` ✗ | 需**改为按完整配置与验证状态**判定 ✓ |

## 2. 逐字段归类（**三类，各自标明来源**）
### A. 可由**模型实测**并工具生成 ✓（`geometry` 共 16 字段）
| 字段 | 来源 |
|---|---|
| `turret_origin` / `gun_origin` | 角色节点实测（**已有** ✓ `logs/WT-030D-r2/draft_binding_inputs.json` ✓：35t ✓ / KPz70 ✓ / M48 ✓；两车同法可测 ✓） |
| `barrel_length` | 炮口实测偏移 ✓（同上 ✓，并**标注基准** ✓ —— 早前已记录"枢轴 vs 网格端点"的不确定性 ✓） |
| `hull_rings` / `turret_outline` / `turret_bottom` / `turret_top` / `turret_taper` / `ring_half` / `open_top` / `mantlet_half_width` / `mantlet_half_height` | 由适配产物的**网格包围盒与剖面**实测 ✓（工具生成 ✓，逐项写入**测量方法** ✓） |
| `wheel_count` / `track_width` / `wheel_radius` | 适配产物的**负重轮节点**实测 ✓（`SPECS` 已含 `wheel_prefix` ✓ ✓） |
| `muzzle_brake` | 炮口网格是否存在制退器的**几何判定** ✓（记录判定依据 ✓） |

### B. 可从**候选包资料**取值（**逐字段标注出处** ✓，并标"待设计确认" ✓）
| 字段 | 来源（候选包内） |
|---|---|
| `armor`（17 分区）+ `facts`/`sources` | `armor_groups` + `raw_fields` + `source` ✓（**每区必须挂到一条 fact** ✓ —— 这正是 `validate_package` 的硬要求 ✓） |
| `modules` | `damage_module_references` ✓ |
| `crew` | `crew_roster` ✓ |
| `runtime` 中的 **弹种相关**（`muzzle_velocity` / `penetration_curve` / `rounds`） | `weapon_references` + `ammo_racks` ✓ |
| `evidence_profile` | 取 `game_reference` ✓（**不冒充** `historical_verified` ✗ —— 该值需史料级验证 ✓） |

### C. **纯设计项**（无资料可依 ⇒ **逐条列出** ✓，不写"等作者" ✓）
| 字段 | 需谁定 | 说明 |
|---|---|---|
| `runtime`：`forward_max_speed` / `reverse_max_speed` / `acceleration` / `hull_turn_speed` / `turret_yaw_speed` / `turret_pitch_speed` / `reload_time` / `pitch_min` / `pitch_max` | **设计** | 属游戏初值 ✓（项目明令**不得**冒充现实性能 ✓）⇒ 由设计给定或按同代历史车**同档**取值并**显式标注"设计初值"** ✓ |
| `assembly`（火炮/弹种装配） | **设计** | 可参照 `configs/shells/historical_loadouts.json` 的既有范式 ✓ |
| `compatible_shells` | **设计** | 同上 ✓ |
| `license` / `limitations` | **资料** | 与素材许可一并登记 ✓（**E3 未授权** ⇒ 保持 NOT_RUN ✓） |
| 平衡（分房/票数影响） | **设计** | 不擅自改 ✗ |

## 3. 工具设计（落到文件与函数 ✓）
`tests/generate_modern_combat_package.gd`（新增 ✓）：
1. 读适配产物 ✓ → 复用 `export_draft_binding_inputs.gd` 的**树内实测**方法 ✓（**教训**：绝不在未入树的场景上读 `global_position` ✗）；
2. 产出 `geometry` 全 16 字段 ✓，每字段附 `{"method": ..., "measured": true}` ✓；
3. 从候选包**带出处**填 B 类 ✓，未取到者写入 `gaps` ✓；
4. C 类写入 `design_required` 清单 ✓（**逐条** ✓）；
5. **不写** `combat_definition` 冒充完整 ✓ —— 产出物明确标 **draft** ✓，并在验收前**不**改准入闸门 ✗。

## 4. 验收（做完才改闸门 ✓）
1. 生成包通过 `VehicleContentPipeline.validate_package` ✓（`evidence_profile = game_reference` ✓）；
2. **几何自校验**：`geometry` 的实测字段与**模型重测**一致 ✓（容差 1 mm ✓，`delta=0` 式断言 ✓）；
3. `armor` 每区都能解析到 `facts` 中的一条 ✓（**无孤儿区** ✓，无证据者不入包 ✓）；
4. 两车加入 `VehicleContentRecord` 后 `VehicleReadiness` 返回 **ok** ✓（**只有此时**才把 `preview_only` 硬拒改成"按配置完整性判定" ✓）；
5. 回归：`run_vehicle_readiness_checks` ✓ · `run_content_record_checks` ✓ · `run_reference_admission_checks` ✓ · `run_model_binding_checks` ✓ 全绿 ✓；
6. **明确不声称**：C 类未定前不得声称"两车已可正式出战" ✗。

---

## 5. 执行进展：两车适配产物已生成 ✓，并发现**自校验盲区** ✗
| id | 源哈希 | 适配哈希 | 炮口偏移 | 方法 | 自校验 |
|---|---|---|---|---|---|
| `germ_leopard_2a4` | `4e7a3515…` | `d83daabe…` | (0, −0.0116, −5.697) | `barrel_mesh_extremity_composed_through_parent_chain` | `verified=True` ✓ |
| `ussr_t_80b` | `8f47a0a2…` | `40707c9f…` | **(0,0,0)** | **`none`** | `verified=True` ✗ **空洞通过** |

**盲区（必须修 ✓）**：自校验只断言"产物里的标记位置 == 记录的偏移" ✓，而**未要求该偏移非零、方法非 `none`** ✗ ⇒ 测量失败时**照样通过** ✗。
⇒ 加固项（下一轮）：
1. `assert offset.length() > 0` ✓ 且 `method != "none"` ✓，否则**判失败** ✓；
2. 对 `ussr_t_80b` 追查**角色映射为何失败** ✓（其 `SPECS` 期望 `root/gun_mesh` ✓ 与真实节点可能不符 ✓）；
3. 两车源路径（供复现 ✓）：T-80B `E:/AIprogram/aimodel/苏联/中型坦克/ussr_t_80b/制作中/vehicle.glb` ✓；豹2A4 `E:/AIprogram/aimodel/_制作记录/德国/candidates/germ_leopard_2a4/vehicle.glb` ✓；
4. 工具已支持 `<id>=<绝对路径>` 与 `root=<目录>` ✓（含中文路径 ✓ 实测可用 ✓）。

**说明** ✗：`ussr_t_80b` 的产物**不足以**用于几何生成 ✓（炮口无效 ✓）⇒ 在加固与修好映射前，**不得**用它的 `MuzzlePoint` 生成 `geometry` ✗。

---

## 6. 记录修复 + 确定性验证 + 盲区量化（本轮实测）
| 项 | 结果 |
|---|---|
| `adapter_artifacts.json` | 被 2 车运行**覆盖**为 2 行 ✗ ⇒ **已一次性重跑 96+2 修复为 98 行** ✓ |
| 自校验汇总 | `verified=True` **98/98** ✓ · `source_unchanged=True` **98/98** ✓ |
| **确定性** | 重导出 98 个 GLB 与修复前 **逐字节相同（0 差异）** ✓✓ ⇒ 适配生成**可复现** ✓ |
| **盲区实例** | **6 辆** `method=none` 却 `verified=True` ✗：`9a33bm3` · `iris_slm_fcs` · `iris_slm_launcher` · `leichter_ladungstrager_303a` · `truck_sdkfz_6_2_tent` · **`ussr_t_80b`** |

**精确定性** ✓：前 5 辆为**卡车/发射车/载具**（**无炮口** ✓）⇒ 对它们"`none`"正确 ✓，但**不应**产出原点 `MuzzlePoint` ✗；**`ussr_t_80b` 是坦克** ✗ ⇒ 其 `none` 为**真实失败** ✗。

**加固项（精确化）**：
1. 仅当该车**存在炮角色**时，要求 `method != "none"` **且** `offset.length() > 0` ✓，否则**判失败** ✓（不再空洞通过 ✗）；
2. 无炮车辆**不产出 `MuzzlePoint`** ✗，改标 `no_muzzle` ✓；
3. **追查 `ussr_t_80b` 映射失败** ✓（`SPECS` 期望 `root`/`gun_mesh` 与真实节点核对 ✓）。

---

## 7. T-80B 炮口测量失败：**根因一行常量 + SPECS 与模型不符**（已修并验证 ✓）
**根因（探针实测）** ✓：T-80B 的炮管网格名为 **`Gun`** ✓（结构 `TurretPivot → Turret → GunPivot → Gun` ✓），而
`role_mapping_audit.gd:49` 的 `GUN_MESH_HINTS` **不含 `"gun"`** ✗（只有 `maingunandmuzzl/maingun/barrel/kanone/rohr/cannon` ✓）
⇒ 无 barrel ⇒ `method=none` ✓；同时 `modern_model_mount_adapter.gd` 的 `SPECS.ussr_t_80b.gun_mesh` 写作 **`"MainGun"`** ✗ 与真实节点不符 ✓。

**修复（两处，均为数据/常量对齐模型 ✓）**：
1. `GUN_MESH_HINTS` **末位追加 `"gun"`** ✓（具体名优先 ⇒ 已成功者不受影响 ✓）；
2. `SPECS.ussr_t_80b.gun_mesh`：`"MainGun"` → **`"Gun"`** ✓。

**验证（同批 ✓）**：
| 项 | 结果 |
|---|---|
| `run_role_mapping_checks` / `run_model_binding_checks` / `run_model_binding_probe_checks` | **72/0** ✓ · **63/0** ✓ · **60/0** ✓ |
| 98 车偏移**变化数** | **恰好 1**（仅 `ussr_t_80b` ✓；其余 97 未变 ✓✓） |
| T-80B 修复后 | offset **`(0,0,−6.1341)`** ✓ · method `barrel_mesh_extremity_composed_through_parent_chain` ✓ · `verified=True` ✓ · 新哈希 `a6c69564…` ✓ |
