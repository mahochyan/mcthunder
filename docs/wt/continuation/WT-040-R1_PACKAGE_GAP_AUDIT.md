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

---

## 8. 第七轮：**自我更正 + 陷阱拒绝** ⇒ 缺口 13 → **11**（豹2 14 → 12）
### 我上一轮的结论**差两项** ✗（已更正 ✓）
我曾写"无需裁定即可闭合的工作已做完" ✗ —— 复查后**还有两项可闭合** ✓：
| 新闭合 | 来源 | 备注 |
|---|---|---|
| `assembly.variant` | 头部原始字段 **`模型名`** = `t_80b` / `leopard_2a4` ✓ | 带行号 ✓ |
| `runtime.acceleration` | 原始字段 **`加减速度 = 4.0 / 8.0`** 的**首值** ✓ | **解析规则已声明** ✓（首值＝加速 ✓） |

### **陷阱被抓并拒绝** ✓✓
头部 `首发日期 = 2018-09-11 / 2018-06-06` ✗ 是**参考游戏的上线日期** ✗，**不是**车辆历史年份 ✗
⇒ 用作 `assembly.year` 就是**错误声明** ✗ ⇒ **明确拒绝并记录** ✓（输出中可见 ✓）。

### 穷尽核查（边界由此**确证** ✓）
| 核查项 | 结果 |
|---|---|
| `reload`/`pitch`/`elevation`/`penetration` 候选键 | **均不存在** ✗ |
| 生产包 `penetration_curve` | **多点列表** `[[0,150],[500,125],[1500,95]]` ✓ ⇒ 单点造"曲线"＝**退化编造** ✗ ⇒ 留设计 ✓ |
| 生产包 `reload_time` / `pitch_min` / `pitch_max` | **8.5** / **−10** / **20** ✓ ⇒ **设计值** ✓ 非事实 ✓ |
| `shell.reference.hitPower` | **两车同为 260.0** ✗ ⇒ 档案数值**部分归一化**的又一旁证 ✓ |

### 剩余 11 项（T-80B）—— **全部**需外部输入 ✓
**设计取值**：`runtime.reload_time` · `pitch_min` · `pitch_max` · `penetration_curve` · `assembly.mount` · `assembly.year`（车辆历史年份需**史料** ✓）· `assembly.suspension`
**独立资料**：`dimensions.width_m` / `reference_length_m`（**不得**以我自己的测量充当 ✓）
**待评审筛选**：`modules`（182 → ≤48 ✓ 且弹架之和＝rounds ✓）· `crew`（≤48 ✓）
**待裁定**：**armor 17 zone 映射** ⇒ 裁定后**一次降 17** ✓

---

## 9. 第八轮：`crew` 组件闭合 ⇒ 缺口 **11 → 10**（豹2 12 → 11）
### 项目自己的词汇（照它做 ✓，不自创 ✗）
| 组件 | 生产包实况（4 辆历史车） | 关键约束 |
|---|---|---|
| `modules` | **9–10 行** ✓；字段 `{id, kind, part, position, size, external, ammo_capacity?}` ✓；**7 种 kind**：`ammo` `engine` `transmission` `fuel` `breech` `turret_drive` `track` ✓ | **弹药容量之和必须精确等于 `rounds`** ✓✓（M26：10+30+30 = **70** ✓） |
| `crew` | **5 行** ✓；字段 `{id, role, part, position, size}` ✓；role ∈ `driver` `assistant_driver_bow_gunner` `gunner` `commander` `loader` ✓ | — |

### 诚实判断 ✓
档案 **182** 条 module refs 是 **WT 内部粒度** ✗，且**不含位置** ✗ ⇒ 与项目模型**结构不同** ✗ ⇒ **不可机械搬运** ✓；
但**可做有据派生** ✓（role **引用** ✓ + 位置由**实测盒**派生并**标注** ✓）。

### 结果 ✓
```
ussr_t_80b       → gunner@turret, driver@hull, commander@turret             （3 ✓ 自动装弹机 ⇒ 无装填手 ✓）
germ_leopard_2a4 → gunner@turret, driver@hull, loader@turret, commander@turret（4 ✓ 人工装填 ⇒ 有装填手 ✓）
```
（`crew` 缺口**已从审计中消失** ✓；位置/尺寸标注 `derived` ✓ 且说明作者可替换 ✓。）

### 又修掉一个**反复踩的坑** ✗✓
`Dictionary.get()` 返回 **Variant** ✗ ⇒ `var role := ROLE_MAP.get(...)` 触发 "类型由 Variant 推断" 的**编译错误** ✗ ⇒ 改**显式类型** ✓。

### 剩余 10 项
**下一步可派生闭合**：`modules` ✓（项目 7 kind ✓ + 派生位置 ✓ + 弹架之和＝rounds ✓）
**设计**：`reload_time` · `pitch_min` · `pitch_max` · `penetration_curve` · `assembly.mount` · `assembly.year`（需史料）· `assembly.suspension`
**独立资料**：`dimensions.width_m` / `reference_length_m`

---

## 10. 第九轮：`modules` 闭合 ⇒ 缺口 **10 → 9**，**可派生工作已穷尽核实** ✓
`modules` 草案 ✓（`tests/build_modern_modules_draft.gd` ✓）：**10 行** ✓（与生产包同规模 ✓），kind 依生产包 7 种 ✓，位置**由实测盒派生并标注** ✓，且**弹药精确配平** ✓：
| 车 | 弹架 | 合计 | 引用容量 |
|---|---|---|---|
| T-80B | `ammo_ready 10` + `hull_left 14` + `hull_right 14` | **38** ✓ | `primary.capacity` ✓ |
| 豹2A4 | `10` + `16` + `16` | **42** ✓ | 同上 ✓ |
⇒ 满足校验器"**弹架容量之和 == `runtime.rounds`**" ✓（M26 的 10+30+30=70 ✓ 同构 ✓）。

### 缺口轨迹（**九连** ✓）
```
T-80B : 24 → 23 → 20 → 17 → 14 → 13 → 11 → 10 → 9 ✓
豹2A4 : 25 → 24 → 21 → 18 → 15 → 14 → 12 → 11 → 10 ✓
```

### 剩余 9 项（**穷尽核实后确认全部需外部输入** ✓）
`assembly.suspension`（档案 0 字段 ✓）· `assembly.mount`（仅有 `source_weapon_id` ✓）· `assembly.year`（需史料 ✓；WT 上线日期已拒绝 ✓）· `dimensions.width_m` / `reference_length_m`（**独立资料** ✓）· `runtime.reload_time` · `pitch_min` · `pitch_max` · `penetration_curve`（**设计** ✓，生产包为多点列表 ✓）

---

## 11. 一条命令的管线 ✓ + 追查出**三层环境陷阱**（并纠正我一次"忽略证据"）
### 管线 ✓ `tests/run_modern_vehicle_pipeline.ps1`
```
pwsh -File tests/run_modern_vehicle_pipeline.ps1
```
步骤：`import → geometry → facts → geometry_check → crew → modules → gap_audit` ✓
判据：**退出码 + 日志扫描**（不靠 stderr ✓）；输出**缺口数**作为验收信号 ✓。
**结果** ✓：`7 ok, 0 failed` · `MODERN_PIPELINE_OK` ✓ · `geometry_check` **29/29** ✓ · 缺口 **9 / 10** ✓。

### 管线**立刻抓出我早前的一次错误** ✗→✓
我曾把 `geometry_check` 的 `[exit code: 1]` 当作**管道假象**忽略 ✗ —— 管线证明它是**真实失败** ✗✓。

### 三层陷阱（每一层都由"让失败自解释"的诊断暴露 ✓）
| # | 陷阱 | 机制 | 修法 |
|---|---|---|---|
| 1 | **`.ps1` 被按 ANSI 解析** ✗ | Windows PowerShell 读**无 BOM** 的 `.ps1` 会把中文#破坏 ✓ | 脚本内**不写中文** ✗ |
| 2 | **argv 中文路径不可靠** ✗ | 子进程传参丢失/损坏 ✓ | 只传 **ASCII 车辆 id** ✓ |
| 3 | **PowerShell 自动展开单元素数组** ✗✗ | `$j.model_candidates.glb_path` 看似对象访问 ✓，实为**数组** ✓ | GDScript 侧**兼容数组与字典** ✓ |

### 反复出现的元教训（已第三次）
**PowerShell 的 JSON 显示会隐瞒真实形状** ✗（单元素数组被悄悄展开 ✓）⇒ 判断形状必须用 `GetType().Name` ✓ 或直接在**目标语言**里验证 ✓。
另外 ✓：`Dictionary.get()` 返回 Variant ⇒ 必须**显式类型** ✓（本会话已第二次踩 ✓）。

### 良性警告不再中断管线 ✓
Godot 会把**无害警告**写到 stderr（如 `backups/` 下的 `project.godot` 被忽略 ✓），而 PowerShell 会把**原生 stderr** 当错误记录 ✓ ⇒ 已改为**不以 `ErrorActionPreference=Stop`** 中止 ✓，判据只看退出码与日志 ✓。

---

## 12. **重要更正**：我此前报的"缺口数"只是 **shape 门** 的数字 ✗✓（并证明 armor 草案有效 ✓）
`validate_package` 第 6-7 行：**`check_shape` 一旦报错即立即返回** ✗ ⇒ 第 12-41 行的**内容校验**（17 armor zone ✓ · geometry 15 字段 ✓ · runtime 10 字段 ✓ · **包络 ≤16% 互校** ✓ · layout ✓ · 弹种目录 ✓）**根本不执行** ✗✗。
⇒ 我此前把 "9 项" 当作"总缺口"是**低估** ✗ —— 应称 **"shape 门缺口 9 项"** ✓。

### 用**探针**让内容校验真正执行后（探针值明确标注 ✓，**绝不写入任何包** ✓）
| 层 | T-80B | 豹2A4 |
|---|---|---|
| shape 门 | **9** ✓ | **10** ✓ |
| **shape 门之后** | **4** ✓ | **1** ✓ |
| 报出的内容缺口 | `geometry` / `runtime` / `modules` / `crew`：**actual content differs from field record** ✗ | 同类 ✓ |

### 两项澄清 ✓
1. **armor 草案其实生效** ✓✓：内容层**未报任何 `armor.*` 缺口** ✓ —— 此前"加入草案后数字不变"**纯粹因 shape 门挡住** ✓✓，**不是草案无效** ✓；
2. **真实剩余范围很小** ✓：补齐 9 项后内容层仅剩 **1–4 项**，属**新类别**（"实际内容与字段记录不符" ✓）。

### 教训（已第四次同类 ✓）
**"通过/失败"必须看它是在哪一道门测的** ✗ —— 短路会让人把"第一道门"误当"全部" ✓。

---

## 13. 内容层再降（4 → 1）与**一条次序要求** ✓
`tests/build_modern_evidence_record.gd` ✓ 按第 174 行的要求生成**四个自证式证据事实** ✓（`geometry.exterior` ✓ · `runtime.simulation` ✓ · `geometry.modules` ✓ · `geometry.crew` ✓，值＝组件本身 ✓，状态 `derived_from_draft` ✓）：
| 层 | T-80B | 豹2A4 |
|---|---|---|
| shape 门 | 9 ✓ | 10 ✓ |
| shape 门之后 | **4 → 1** ✓ | 1 ✓ |

**剩下的 1 项是探针假象** ✓：探针往 packet 塞了 4 个**设计值**（`reload_time`/`pitch_min`/`pitch_max`/`penetration_curve` ✓），而证据记录是从**真实 runtime 草案**（5 字段 ✓）复制的 ✓ ⇒ 二者**必然不等** ✗ —— 不是真实缺口 ✓。

⇒ **次序要求（重要 ✓）**：**设计值落地时，必须先写入 runtime 草案 ✓，再重新生成证据记录 ✓**，否则 `runtime.simulation` 与 packet 会再次不符 ✗。

### 同时确认（探针已通过更早的三道 profile 关口 ✓）
`VehicleEquipmentProfiles` ✓ · `AmmoCompartmentProfile` ✓ · `VehicleArmorLayers` ✓ **均未报错** ✓；
`wheel_count ≤ 12` ✓ · `rounds` 整数 ✓ · `hull_rings` 高度递增 ✓ · `armor.<zone>.fact == "armor."+zone` ✓ · `forward_max_speed == mobility.forward_speed_mps` ✓ · `rounds == weapon.capacity` ✓ · 弹架之和 == rounds ✓ —— **全部满足** ✓✓。

---

## 14. **层级探针**：内容门之后的各层已开始暴露真实问题 ✓（全程无需裁定 ✓）
`tests/probe_package_layers.gd` ✓ 直接调用公开 API（绕过被 9 项 shape 缺口挡住的入口 ✓）：
`HistoricalVehicleGeometry.build` ✓ → `LayoutValidator.validate` ✓ → `VehicleShellCatalog.build` ✓ → `definitions_for` + 各定义 `validate()` ✓。
探针值明确标注 ✓，**绝不写入任何包** ✓。

**首跑即报出两处真实（可复现）问题** ✓：
| # | 报错 | 含义 |
|---|---|---|
| 1 | **`Invalid access to property or key 'hull_rings' on a base object of type 'Dictionary'`** ✗ | `HistoricalVehicleGeometry.build` 直接读 `g.hull_rings` ✓ ⇒ **豹2A4 必然崩溃** ✓（其 `hull_rings` 正是**作者项** ✓）—— **此前只是推断，现已实测证实** ✓✓ |
| 2 | **`Invalid access to property or key 'crew.placement'`** ✗ | `LayoutValidator.validate` 需要**特定结构的证据字典** ✓ ⇒ 该层有**自己的**接口要求 ✓ |

⇒ **结论** ✓：内容门之后仍有若干**独立层**（layout ✓ · 弹种目录 ✓ · 定义校验 ✓），**各有自己的要求** ✓；
层级探针把它们从"未知"变成**可复现的具体错误** ✓ —— 这是**不需要任何外部输入**就能推进的工作 ✓。

**下一步（继续 ✓）**：让探针**逐层收敛**：① 为 `geometry.build` 提供**形状安全的**几何（豹2缺环时给出**明确标注的占位环** ✓ 以观察后续层 ✓）；② 按 `LayoutValidator` 的真实接口**构造**证据字典 ✓（读其源码 ✓，不猜 ✗）；③ 直至跑通 `definitions.validate()` ✓。

---

## 15. 深层接口查明 ⇒ **新车辆需要的完整工件清单**（实测 ✓，非推断 ✓）
### `LayoutValidator.validate(layout, evidence_keys, field_evidence_doc)` ✓
`check_evidence_consistency`（`scripts/layout/layout_validator.gd:206` ✓）**空字典直接报错** ✓：
> `field evidence registry missing for <tier> layout (**configs/evidence/<identity>.json**)` ✗
且对 `content_tier == "test"` **提前返回** ✓ ⇒ **这解释了为何 `configs/evidence/` 里只有 1 份** ✓（M4A3 ✓；其余 3 辆历史车为 test 级 ✓）。

### 证据登记表的**真实形状** ✓（`configs/evidence/us_m4a3_75w_vvss_1944.json` ✓）
```
顶层: identity_id · runtime_note · source_registry · evidence_keys · fields
evidence_keys[]（11）: {key, source_id, origin, title, applies_to, read_state,
                        applies_to_identity_ids[], excluded_identity_ids[]}
fields[]（16）:        {field_path, origin, status, source_refs[], original_value,
                        original_unit, derivation, uncertainty_note}
  例: overall.length_m = "20 ft 7 in" → derivation "20.583 ft * 0.3048 = 6.274 m" ✓
      overall.width_m  = "8 ft 9 in"  ✓
```
⇒ **校验器要的 `dimensions.width_m` / `reference_length_m` 在项目机制里就是 `overall.width_m` / `overall.length_m`** ✓，
且**必须带文献原值与推导**（`original_value` + `derivation` ✓）⇒ 我此前把尺寸判为"**独立资料**"**完全正确** ✓，现已确定**字段名与格式** ✓。

### 因此，一辆**新生产车**的**完整工件清单**（实测所得 ✓）
| 工件 | 状态 |
|---|---|
| `geometry`（15 必需字段 ✓） | **已测得并校验** ✓（29/29 ✓；豹2 缺 `hull_rings` ⇒ 作者项 ✓） |
| `runtime`（10 必需字段 ✓） | 6 项**已带引用** ✓；4 项**设计值**待输入 ✓ |
| `armor`（17 zone ✓） | **草案已备好** ✓（待裁定 ✓），内容层**已通过** ✓ |
| `modules`（7 kind ✓，≤48 ✓，弹架==rounds ✓） | **已派生** ✓ |
| `crew`（角色引用 ✓ + 位置派生 ✓） | **已派生** ✓ |
| `assembly`（7 字段 ✓） | 4 项已带引用 ✓（`gun`/`shell`/`caliber_mm`/`variant` ✓）；3 项待史料 ✓ |
| `facts` | **逐条带引用** ✓ + **四个自证式证据事实** ✓ |
| **`configs/evidence/<id>.json`** | **尚缺** ✗ ⇒ 其 `fields[]` 需 `overall.width_m`/`overall.length_m`（**文献** ✓）等 |
| **`model_binding`** | **尚缺** ✗（校验器：新车辆**必须**有显式交付的模型绑定 ✓） |
| `layout`（由 `HistoricalVehicleGeometry.build` 生成 ✓） | **已探测：会因 `hull_rings` 缺失而崩** ✗（豹2 ✓） |

---

## 16. 层级探针**贯通到最后一层** ⇒ 完整层级图（实测 ✓）
`tests/probe_package_layers.gd` ✓（占位环与探针登记表**均明确标注** ✓，绝不写入任何包 ✓）：
| 层 | T-80B 实测 |
|---|---|
| `HistoricalVehicleGeometry.build` | **ok ✓**（`parts=6` ✓ · **`armor_patches=56`** ✓ ⇒ 布局**确实能建** ✓） |
| `LayoutValidator.validate` | **388 errors** ✗ · 2 warnings · 1 suspicious（探针 registry：keys 21 ✓ fields 62 ✓） |
| `VehicleShellCatalog.build` | `ok=false` ✗ · 1 error · 0 options |
| `definitions_for` | `vehicle_content_pipeline.gd:230` **构造器报错** ✗ ⇒ 提前返回 ✓ |

### 388 项里绝大多数是**探针登记表自身的机制缺陷**（非车辆数据缺口 ✓）
```
evidence key 'armor.<zone>' does not apply to identity 'ussr_t_80b'   ← 探针键的 applies_to_identity_ids 为空 ✗
field record ... references unregistered source 'probe'               ← source_refs 必须指向已登记来源 id ✓（大小写须一致 ✗）
```
⇒ **登记表的形状已被证明可用** ✓；其**必需内容**同时确定 ✓：
逐键 **`applies_to_identity_ids`** ✓（否则"不适用身份" ✗）· **`source_refs` 必须命中已登记来源** ✓ · **来源表须含 `url`(https) + `sha256`(64hex) + `read_state`** ✓。

### 顺带纠正了我自己的一次误判 ✓
`historical_vehicle_geometry.gd:113` 读 `packet.facts["crew.placement"].status` ✓ ⇒ 我先前以为存在"扁平/嵌套两套键约定" ✗ —— 实为**该键缺失** ✓（源码一读即明 ✓）。

### 下一步（继续 ✓，不需外部输入）
修探针登记表的**两项机制缺陷**（`applies_to_identity_ids` ✓ + `source_refs` 指向已登记来源 ✓）⇒ 388 项应**大幅坍缩** ✓，**剩下的才是真正的车辆数据要求** ✓✓ —— 这就是"把未知变成清单"的最后一步 ✓。

### 附注 ✓
探针命令在 600s 被工具超时**杀掉** ✗（日志 412 行已完整 ✓）⇒ 属**进程存活**问题 ✓，**非逻辑挂起** ✓；门禁 `pwsh-38` 仍在跑 ✓，**全程未触碰其进程** ✓。

---

## 17. 探针机制修正生效 ⇒ **388 → 136**（降 65% ✓）
### 修正的两处（均为"**一致性**"类 ✓）
1. **`applies_to_identity_ids` 补上身份** ✓（此前为空 ⇒ 校验器判"该键不适用于本身份" ✗）；
2. **`source_refs` 指向已登记来源 id** ✓（`PROBE` ✓，大小写一致 ✓）。

**结果** ✓：`LayoutValidator.errors` **388 → 136** ✓（warnings 2 ✓ · suspicious 1 ✓）；`geometry.build` 仍 **ok**（`parts=6` ✓ · `armor_patches=56` ✓）。

### 第 230 行错误现已**精确显示** ✓
```
SCRIPT ERROR: Invalid call. Nonexistent 'Vector3' constructor.
```
⇒ `v.drive_collision_size = Vector3(HistoricalEvidenceGate.value(packet,"dimensions.width_m"), …)` ✓
⇒ 该 gate **对不合格事实返回 null** ✗ ⇒ 构造 `Vector3(null,…)` 失败 ✗。
**根因仍是同一类** ✓：我的探针 `dimensions.*` 事实 `status:"probe"` ✗、`origin:"probe"` ✗ **未在来源表登记** ✗。

### 下一步（继续 ✓）
把 `dimensions.*` 探针事实的 **origin/source_refs/status 与来源表对齐** ✓ ⇒ 越过第 230 行 ✓ ⇒ 观察 `definitions_for` 之后的**最后一层**要求 ✓；
并对 **136 项**做**去重归类** ✓，区分"**探针机制残留**"与"**真正的车辆数据要求**" ✓✓。

### 附注 ✓
探针改用 **PowerShell 后台作业** ✓ 规避工具 600s 超时 ✓（上轮日志 412 行完整 ✓ ⇒ 属**进程存活**问题 ✓）。

---

## 18. **里程碑：探针贯通到终点，两车 definitions 全部 0 错误** ✓✓✓
| 层 | T-80B | 豹2A4 |
|---|---|---|
| `geometry.build` | **ok** ✓（parts=6 · patches=**56**） | **ok** ✓（parts=6 · patches=**49**） |
| `LayoutValidator` | **136** ✗（2 warn · 1 susp） | **121** ✗（8 warn · 3 susp） |
| `VehicleShellCatalog` | `ok=false` ✗：**`vehicle has no admitted shell set`** | 同类 ✓ |
| **`definitions`** | **vehicle 0 ✓ · gun 0 ✓ · shell 0 ✓** ✓✓✓ | **vehicle 0 ✓ · gun 0 ✓ · shell 0 ✓** ✓✓✓ |

### 136 项的**完全归类**（探针机制 vs 真实要求 ✓）
| 数量 | 错误 | 性质 |
|---|---|---|
| 56 | `armor_patches[n].thickness_status: field record references **unregistered source**` ✗ | **探针机制** ✗（`source_refs` 须为**来源 id** ✓，不能带 `#L<n>` 定位符 ✗） |
| 56 | `armor_patches[n].geometry_status: **unknown status 'estimated'**` ✗ | **登记表须承认 `estimated`** ✓ |
| 3+3+3 | `crew_stations[]`：`volume_status` 无字段记录 ✗ / `role_placement_status` 未登记状态 ✗ | **探针机制** ✗ |
| **3** | `duplicate, miswound or **non-manifold edge**`（part hull/barrel）✗✗ | **真实几何问题** ✓（我的生成器产生的非流形边 ✓） |
| **1** | `vehicle has **no admitted shell set**` ✗ | **真实** ✓ ⇒ 需弹种集（**设计/资料** ✓） |

### 结论（**范围已收缩到极小且具体** ✓）
新车辆距"可校验通过"只剩：**① 3 条非流形边**（我方可修 ✓）· **② 弹种集**（设计/资料 ✓）· **③ 探针登记表机制**（非车辆数据 ✓）。
而 **runtime/assembly/crew/modules/armor 的数据在项目自己的定义校验下已自洽** ✓✓。

---

## 19. 三条根因精确落定（含**我生成器的一个真实缺陷** ✓✓）
| # | 完整原文 | 真实原因 | 修法 |
|---|---|---|---|
| 1 | `field record 'armor_patches.hull_0_0.thickness_mm' references unregistered source '**PROBE**'` ✗ ×56 | 校验器查的是**登记表自身的 `source_registry`** ✗ —— 而我的 `_registry_from` 返回 `"source_registry": {}` **空表** ✗✗ | 把来源 id 填进 `source_registry` ✓ |
| 2 | `armor_patches[n].geometry_status: unknown status` ✗ ×56 · `crew_stations[].role_placement_status: unknown status 'reference'` ✗ ×3 · `crew_stations[].volume_status: no field evidence record covers` ✗ ×3 | 登记表**缺少对应 claim 的字段记录** ✗（`geometry_status` ✗ · `volume_status` ✗ 从未出记录 ✓） | 为**每一个 claim 字段**出具记录 ✓ |
| 3 | `armor_patches(part hull): duplicate, miswound or **non-manifold edge** … **y=1.857**` ✗ ×8（+ barrel ×4） | **我生成器的真实缺陷** ✓✓：`ring_half = 1.474` ✗ **大于实测车顶半宽 0.869** ✗ ⇒ **座圈开口比车顶还大** ✓ ⇒ 生成面必然非流形 ✓✓ | **规则** ✓：`ring_half ≤ 车顶半宽`（我此前的"取炮塔底部轮廓一半"派生法**错** ✗） |

### 附带 ✓
`source_refs` 已按契约改为**裸来源 id** ✓（`wt-2.57.1.137` ✓ / `mcthunder_pipeline` ✓），**行号保留在 `location`** ✓（更符合"id 与定位分离" ✓）；两车 **definitions 仍全 0 错误** ✓✓。

### 结论 ✓
第 3 条是**探针价值的实证** ✓：把"**看似合理的派生**"变成"**可复现的几何错误**" ✓✓ —— 而它**完全在我方**（无需任何外部输入 ✓）。
