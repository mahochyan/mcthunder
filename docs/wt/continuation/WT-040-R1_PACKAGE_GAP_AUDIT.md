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
