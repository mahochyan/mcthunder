# 第 ③ 步：**校验器亲自给出的缺口清单**（可执行 ✓）`tests/check_modern_package_gaps.gd`

> 做法 ✓：把**实测 geometry 草案** + **形状合规但内容为空**的占位（`facts/sources/assembly/compatible_shells/license/runtime/armor/modules/crew` ✓）
> 送进 `VehicleContentPipeline.validate_package` ✓ ⇒ **由校验器**枚举缺口 ✓。
> **性质** ✓：这是**缺口审计** ✗，**不是**"已完成" ✗，也**不是**准入 ✓；占位**故意为空** ✓，包**不注册、不落盘、不准入** ✓。

## 1. 结果
| | T-80B | 豹2A4 |
|---|---|---|
| 缺口数 | **24** ✓ | **25** ✓ |
| 差异 | — | 多 1 项：**`geometry.hull_rings`** ✓（＝已登记**作者项** ✓，**独立确认** ✓） |

## 2. 清单（校验器原话 ✓）
| 组 | 项 | 要求 |
|---|---|---|
| `assembly.*` ×7 | `variant` `suspension` `gun` `mount` `shell` | 非空字符串 ✓ |
| | `year` `caliber_mm` | 有限数值 ✓ |
| `crew.roles` | — | 数组 ✓ |
| `dimensions.width_m` / `reference_length_m` | — | **正数** ✓ ⇒ **参考尺寸必须成为 facts** ✓ |
| **`mobility.forward_speed_mps`** | — | 正数 ✓（**我此前未列出** ✗） |
| **`weapon.capacity`** | — | 正数 ✓（**我此前未列出** ✗） |
| `runtime.*` ×10 | `forward_max_speed` `reverse_max_speed` `acceleration` `hull_turn_speed` `reload_time` `rounds` `muzzle_velocity` | 有限正数 ✓ |
| | `pitch_min` `pitch_max` | 有限 ✓ |
| | `penetration_curve` | 数组 ✓ |
| `modules` / `crew` | — | "invalid count" ✓ ⇒ 需满足最小数量 ✓ |

## 3. 由此确定的实现顺序（下一轮起 ✓）
1. **facts 层** ✓：`dimensions.*`（参考尺寸 ✓）· `mobility.forward_speed_mps` ✓ · `weapon.capacity` ✓ · `armor.<zone>`（17 ✓）——**全部带出处** ✓（`warthunder_reference` + 行号 ✓）；
2. **`armor` + `runtime`** ✓：按两份映射表与档案可引值填 ✓（`reload_time`/`pitch_*`/`penetration_curve` 属**设计/资料** ✓，须您裁定或另行给值 ✓）；
3. **`assembly`** ✓：`gun`/`mount`/`shell`/`year`/`caliber_mm` 部分可引（`weapon_references` ✓）✓；
4. **`modules`/`crew`** ✓：由档案 `damage_module_references`（182 ✓）/ `crew_roster`（3–4 ✓）生成 ✓；
5. 之后**重跑本审计** ✓ ⇒ 缺口数应**逐项下降** ✓（可量化验收 ✓）。

## 4. 一项待查（不臆断 ✓）
`armor: {}` 时**未出现 17 个 zone 报错** ✗（按行序应在 `runtime` 之后 ✓）⇒ 下一轮以定向探针确认校验器的**判定顺序/短路点** ✓，再据此安排填字段次序 ✓。

---

## 5. 事实层落地与**缺口数三连下降**（✓ 可量化验收 ✓）
| 阶段 | T-80B | 豹2A4 | 关闭原因 |
|---|---|---|---|
| 初始 | **24** | **25** | — |
| 加入事实键 | **23** | **24** | `mobility.forward_speed_mps` ✓（校验器**确实**把该键当事实消费 ✓，0 报错 ✓） |
| **修正类别错误** | **20** ✓ | **21** ✓ | `forward_max_speed` / `reverse_max_speed` / `hull_turn_speed` 写入 **`runtime` 组件** ✓ |

### 我的类别错误（由审计抓到 ✓）
第一版我把 **`runtime` 的值**也写进了 **`facts`** ✗ ⇒ 校验器仍报缺 ✗ —— 因为它读的是 **`packet.runtime` 组件** ✓。
**正解** ✓：**值进 `runtime` 组件** ✓，**`facts` 负责出处**（及被其它检查查询的事实键，如 `mobility.forward_speed_mps` ✓）——两者**都需要** ✓。
（**这正是"缺口审计"存在的价值** ✓：让校验器纠正我，而不是我自己叙述 ✓。）

### 事实来源（**正确的那一层** ✓）
档案的 `fields` 数组是一层**规范化候选数据** ✓：`key` ✓ · **SI 单位 `candidate_value`** ✓ · `historical_verified:false` ✓ · **`locator:{group,line,section}`** ✓✓（＝**引用**）+ `note` ✓。
→ 事实**从此层生成** ✓（而非原始中文文本 ✗），每条带 `source_refs: ["wt-2.57.1.137#L20"]` ✓ 与 `location` ✓。
→ **档案自身**就带 `drive.arcade_power_multiplier` 的**警示 note** ✓✓ ⇒ 我"只作可引起点"的立场**由来源本身证实** ✓。

### 本轮**故意不发**的两类（并有理由 ✓）
1. **装甲 facts** ✗：17 zone 映射**待评审** ✓；
2. **尺寸 facts** ✗：档案**没有** ✓，而拿**我自己的测量**当"参考值"会让校验器的 **≤16% 包络互校循环自证** ✗✗ ⇒ 属**真实资料项** ✓。

### 仍缺（**依赖裁定/设计** ✓，逐项归属明确 ✓）
`assembly.*` ×7 ✓ · `crew.roles` ✓ · **`dimensions.width_m` / `reference_length_m`**（资料 ✓）· `weapon.capacity` ✓ · `runtime`：`acceleration`（**无候选值** ⇒ 设计 ✓）`reload_time` ✓ `rounds` ✓ `muzzle_velocity` ✓ `pitch_min/max` ✓ `penetration_curve` ✓ · `modules`/`crew` 数量 ✓
**并新增一处必需件** ✓：`model_binding: new vehicle requires explicit delivered model bindings` ✓（新车辆必须提供**显式交付的模型绑定** ✓）。

---

## 6. 缺口数**五连下降**（✓ 可量化验收持续有效 ✓）
| 阶段 | T-80B | 豹2A4 | 关闭的字段 |
|---|---|---|---|
| 初始 | **24** | **25** | — |
| 加事实键 | 23 | 24 | `mobility.forward_speed_mps` ✓ |
| 修类别错误 | 20 | 21 | `runtime.forward_max_speed` / `reverse_max_speed` / `hull_turn_speed` ✓ |
| 加武器/弹药（事实+组件） | 17 | 18 | `weapon.capacity` ✓ · `runtime.rounds` ✓ · `runtime.muzzle_velocity` ✓ |
| **修 assembly 接线** | **14** ✓ | **15** ✓ | `assembly.gun` ✓ · `assembly.shell` ✓ · `assembly.caliber_mm` ✓ |

### 新引入的数据（**逐车不同 + 带引用** ✓）
| 字段 | T-80B | 豹2A4 | 引用 |
|---|---|---|---|
| `assembly.gun` | `125mm_2A46_2_user_cannon` ✓ | `120mm_Rheinmetall_L44_user_cannon` ✓ | `weapon_references[primary]` ✓ |
| `assembly.shell` | `125mm_3bk_18m` ✓ | `120mm_dm12` ✓ | `shell.reference.bulletName` ✓ |
| `assembly.caliber_mm` | **125.0** ✓ | **120.0** ✓ | `wt-…#L443 / #L457` ✓ |
| `runtime.rounds` / `weapon.capacity` | **38** ✓ | **42** ✓ | `#L439 / #L453` ✓ |
| `runtime.muzzle_velocity` | **905** ✓ | **1140** ✓ | `#L445 / #L459` ✓（**注明为该弹种初速** ✓ 非笼统炮口属性 ✓） |

### **两次接线失误（均由审计抓出 ✓，均已修 ✓）**
1. `runtime` 的值曾只写进 `facts` ✗（校验器读 **组件** ✓）；
2. `assembly` 组件生成了却**没传进审计的 packet** ✗。
⇒ **教训** ✓：**生成 ≠ 接线** ✓；每次都必须以**缺口数下降**验证"数据真的到达了校验器" ✓。

### 剩余 14 项（归属明确 ✓）
**可继续闭合（无需裁定 ✓）**：`crew.roles` ✓ · `modules`/`crew` 数量 ✓（档案 182 refs / 3–4 名 ✓）· 待查 `assembly.suspension` ✓
**设计**：`acceleration` ✓ · `reload_time` ✓ · `pitch_min/max` ✓ · `penetration_curve` ✓ · `assembly.variant/mount/year` ✓
**独立资料**：`dimensions.width_m` / `reference_length_m` ✓（必须以**外部来源**提供 ✓，不得用我自己的测量以免循环 ✓）

---

## 7. 缺口数**六连下降**至 **13 / 14**：**无需裁定即可闭合的工作已做完** ✓
| 阶段 | T-80B | 豹2A4 | 关闭字段 |
|---|---|---|---|
| 初始 | 24 | 25 | — |
| 事实键 | 23 | 24 | `mobility.forward_speed_mps` |
| 修类别错误 | 20 | 21 | `runtime.forward/reverse_max_speed` · `hull_turn_speed` |
| 武器弹药 | 17 | 18 | `weapon.capacity` · `runtime.rounds` · `muzzle_velocity` |
| 修 assembly 接线 | 14 | 15 | `assembly.gun` · `shell` · `caliber_mm` |
| **本轮** | **13** ✓ | **14** ✓ | **`crew.roles`** ✓ |

### `crew.roles`（逐车差异＝真实性旁证 ✓）
| 车 | 值 | 引用 | 核对 |
|---|---|---|---|
| T-80B | `[tank_gunner, driver, commander]`（3 ✓） | `#L420` ✓ | 自动装弹机 ⇒ 无装填手 ✓ |
| 豹2A4 | `[tank_gunner, driver, loader, commander]`（4 ✓） | `#L433` ✓ | 人工装填 ⇒ 有装填手 ✓ |

### 校验器的两条**强约束**（新查得 ✓）
1. `modules` / `crew`：**非空且 ≤ 48** ✓（L138-139）——档案 **182** 条 refs ✗ ⇒ **必须筛选** ✓（**待评审判断** ✓，不静默决定 ✗）；
2. **弹药架容量之和必须 == `runtime.rounds`** ✓（L180-184）⇒ 38 / 42 ✓；每行需 `id`/`part`/`kind`|`role` ✓（L142）与证据键 `geometry.modules`/`geometry.crew` ✓（L173）。

### `assembly.suspension`：**不可闭合** ✓
档案**悬挂字段 = 0** ✓ ⇒ **设计/资料** ✓。

### 剩余 13 项的归属（**全部**依赖外部输入 ✓）
**设计**：`acceleration` · `reload_time` · `pitch_min/max` · `penetration_curve` · `assembly.variant/mount/year`
**独立资料**：`dimensions.width_m` / `reference_length_m`（**不得**以我自己的测量充当参考 ✓）· `assembly.suspension`
**待评审筛选**：`modules`（182 → ≤48 ✓ 且弹架之和＝rounds ✓）· `crew`（≤48 ✓）
**待裁定**：**armor 17 zone 映射**（粒度共用 / 多段取代表值 / **准入**）⇒ 裁定后**一次降 17** ✓
