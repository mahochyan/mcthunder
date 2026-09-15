# 第 4 阶段素材：**验证证据表**（每条数字 → 可复现出处 ✓）

> 用途 ✓：任何结论都能被**独立复核** ✓；本表在**对账中发现并更正**了我先前两处表述失准 ✗（已标注 ✓）。

## 1. 缺口轨迹（**出处**：`logs/WT-040-R1/package-gap-audit*.log` ✓）
| 阶段 | 日志 | T-80B | 豹2A4 |
|---|---|---|---|
| 初始（shape 门） | `package-gap-audit2.log` | **24** ✓ | **25** ✓ |
| 加事实键 | `audit3` | 23 | 24 |
| 修类别错误（runtime 进组件 ✓） | `audit4` | 20 | 21 |
| 武器/弹药（事实+组件 ✓） | `audit5` | 17 | 18 |
| 修 assembly 接线 ✓ | `audit6` | 14 | 15 |
| `crew.roles` ✓ | `audit7` | 13 | 14 |
| `variant` + `acceleration` ✓ | `audit8/9` | 11 | 12 |
| `crew` 组件 ✓ | `audit10` | 10 | 11 |
| `modules`（弹架配平 ✓） | `audit11` | **9** ✓ | **10** ✓ |
| 内容层（探针 ✓） | `audit14` | BEYOND=**4** ✓ | — |
| 修证据记录后 ✓ | `audit15` | BEYOND=**1** ✓ | — |

**更正** ✗：先前我把 9/10 与 1/1 的出处写成 `layer-probe10.log` ✗ —— 实为上述 `package-gap-audit*.log` ✓。

## 2. 各层校验（**出处**：`logs/WT-040-R1/layer-probe10.log` ✓）
| 层 | T-80B | 豹2A4 |
|---|---|---|
| `geometry.build` | ok ✓ parts=6 ✓ patches=56 ✓ | ok ✓ parts=6 ✓ patches=49 ✓ |
| `LayoutValidator.errors` | **4** ✓ | **7** ✓ |
| `VehicleShellCatalog` | `no admitted shell set` ✗（设计/资料 ✓） | 同类 ✓ |
| **`definitions`（车/炮/弹）** | **0 / 0 / 0** ✓✓ | **0 / 0 / 0** ✓✓ |

## 3. 其它证据 ✓
| 结论 | 出处 |
|---|---|
| `geometry` 自校验 **29/29** ✓ | `pipeline-geometry_check.log` ✓ |
| `run_modern_model_mount_checks` **41/0** ✓（回归已关闭 ✓） | `mount-recheck2.log` ✓ |
| `run_track_damage_checks` **单独 3s 通过** ✓ ⇒ 门禁停滞＝**并发** ✗ | `track-alone.log` ✓ |
| 流水线 **9 步全绿** ✓ | `pipeline-*.log` ✓ |

## 4. 改动范围对账（**更正后的精确版** ✓）
| 项 | 真实增删 | 判定 |
|---|---|---|
| `scripts/content/modern_model_mount_adapter.gd` | **0** ✓ | **逐字节等于基线** ✓ |
| `scripts/maps/river_junction_navigation.gd` | **0** ✓ | **逐字节等于基线** ✓ |
| `scripts/content/role_mapping_audit.gd` | **8** ✓ | **唯一**产品代码改动 ✓＝有意的 `GUN_MESH_HINTS` 修正 ✓（已回归 ✓） |
| `assets/vehicles/adapters/*`（8 个二进制 ✓） | — | **按设计** ✓：T-80B 新建 ✓ · 5 辆无炮车移除虚假原点标记 ✓ |

**更正** ✗：先前笼统称"产品代码处于基线" ✗ —— 精确表述见上表 ✓（1 处 8 行修正 + 产物按设计更新 ✓）。

---

## 5. **数据完整性验证**：armor 映射**逐条回查档案原文** ✓（独立核对 ✓）
方法 ✓：读 `modern_armor_draft.json` 的 17 个 zone ✓，按其 `location` 中的**行号与节点名** ✓，
回到 `assets/reference_data/candidates/<id>.json` 的 `armor_groups[].nodes[]` ✓ **重新取出**该行的
`armorThickness` ✓ 与 `id` ✓，与草案值逐条比对 ✓（**不信任我自己的转录** ✗）。

| 车 | 一致 | 不一致 |
|---|---|---|
| `ussr_t_80b` | **17** ✓ | **0** ✓ |
| `germ_leopard_2a4` | **17** ✓ | **0** ✓ |

⇒ 我**手写**的两份 17-zone 映射表**无转录错误** ✓✓：来源节点 ✓ · 行号 ✓ · 厚度值 ✓ **均与档案原文吻合** ✓。
（该检查正是为捕捉"**看似合理但实则错**"的数字而设 ✓ —— 本次结果为零错误 ✓。）

---

## 6. **第二项完整性验证**：facts **逐条回查档案候选层** ✓ —— 并**抓到一个真实问题** ✓✓
方法 ✓：读 `modern_facts_draft.json` 每条事实的 `location` 行号 ✓ → 回到档案 `fields[]` 取该行的 `candidate_value` ✓ → 比对 ✓。

| 标记 | 判定 |
|---|---|
| `mobility.engine` `power_hp:1100.0` vs `1100` ✓ | **仅 int/float 表示差异** ✗ ⇒ 非数据错误 ✓ |
| `forward_speed_mps` `20.8333333333333` vs `20.833333333333336` ✓ | **浮点精度损失（~1e-14）** ✓ ⇒ 可忽略但**如实记录** ✓ |
| **`runtime.acceleration` `4.0` vs 档案 L23 = 空** ✗✗ | **真实问题** ✓✓：档案自己的键名是 **`drive.acceleration_unspecified_units`** ✗ ⇒ **档案未标明单位** ✗ ⇒ 我取 **m/s²** 属**假设** ✗ ⇒ **已写入事实 `location` 与 `notes`** ✓ |
| `crew.roles` · `forward_max_speed` 跳过 ✓ | 属**派生**事实 ✓（非转录 ✓） |
| 其余（`hull_turn_speed` 等 ✓） | **每车 3 条精确一致** ✓ |

### 处理 ✓
在生成器中把该**假设显式化** ✓：`... the dossier's own key is drive.acceleration_unspecified_units (empty), so the unit is NOT stated; read as m/s^2 by assumption` ✓
（**不隐藏假设** ✗ —— 这正是本检查存在的意义 ✓。）

---

## 7. **第三项完整性验证**：crew / assembly / modules 回查档案 ✓ —— **全部一致** ✓✓
| 检查 | 结果 |
|---|---|
| **`crew.roles`** vs 档案 `crew_roster[].roles`（**手写扁平化** ⇒ 必须回查 ✓） | T-80B `tank_gunner,driver,commander` ✓ **一致**；豹2 `tank_gunner,driver,loader,commander` ✓ **一致** |
| **`assembly`** vs 档案 `weapon_references[primary].source_weapon_id` ✓ · `shell.reference.bulletName` ✓ · `shell.caliber_mm` ✓ · `primary.capacity` ✓ | T-80B `125mm_2A46_2_user_cannon` ✓ `125mm_3bk_18m` ✓ **125.0** ✓ **38.0** ✓；豹2 `120mm_Rheinmetall_L44_user_cannon` ✓ `120mm_dm12` ✓ **120.0** ✓ **42.0** ✓ |
| **`modules` 弹架之和** vs 草案声明（**独立复核**校验器已验的规则 ✓） | **38 = 38** ✓ · **42 = 42** ✓ |

### 数据层的验证总览（**三重** ✓）
1. **armor 17 zone** ⇒ 逐条回查档案原文 ✓（**17/17 ×2 零不一致** ✓）；
2. **facts** ⇒ 逐条回查候选层 ✓（每车 3 条精确 ✓；2 条表示差异无碍 ✓；**抓到并显式化 1 个隐藏假设** ✓：加速单位 ✓）；
3. **crew / assembly / modules** ⇒ 本次全部一致 ✓✓。
⇒ **草案数据层不含未声明的假设或转录错误** ✓（**除已显式标注的那一处单位假设** ✓）。
