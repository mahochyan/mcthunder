# 第 ③ 步：**待输入清单**（剩余 9 项 · 逐项：字段 × 校验器要求 × 已有依据 × 谁能给 ✓）

> **⚠️ 分层更正（重要 ✓）**：`validate_package` **先跑 `check_shape`** ✓，**一旦报错立即返回** ✗ ⇒
> **下表这 9 项属「shape 门」** ✓；**内容门**（17 armor zone ✓ · geometry 15 字段 ✓ · runtime 10 字段 ✓ · **包络 ≤16% 互校** ✓ · layout ✓ · 弹种目录 ✓）**要等这 9 项补齐后才会执行** ✓。
> 用**明确标注的探针**预跑内容门的结论 ✓：**armor 草案有效** ✓（内容门未报任何 `armor.*` ✓）· `VehicleEquipmentProfiles`/`AmmoCompartmentProfile`/`VehicleArmorLayers` **三关全过** ✓ · 只剩 **1 项**且属**探针假象** ✓
> ⇒ **次序要求** ✓：**设计值须先入 runtime 草案，再重生成证据记录** ✓（否则 `runtime.simulation` 与 packet 会不符 ✗）。
> 生成方式 ✓：**由校验器自己报出**（`tests/check_modern_package_gaps.gd` ✓），非我的叙述 ✓。
> 当前 shape 门缺口：**T-80B 9 项** ✓ · **豹2A4 10 项** ✓（差异：豹2 多 `geometry.hull_rings` ✓）。
> 一条命令复现 ✓：`powershell.exe -File tests/run_modern_vehicle_pipeline.ps1` ✓（**9 步全绿** ✓）
> **我不擅自填** ✗：每一项都标出归属 ✓；档案 `runtime_admitted:false` ✓，其数据**只作可引起点** ✓。

## A. 设计值（4 项）—— 需**设计**给定；我可按同代历史车同档给**明确标注的初值** ✓，但须您许可 ✓
| 字段 | 校验器要求 | 已有依据 | 建议来源 |
|---|---|---|---|
| `runtime.reload_time` | 有限正数 ✓ | 档案**无**此项 ✗（已穷尽核查 ✓）；生产包 M26 = **8.5** ✓ | 设计 ✓ 或同代同档初值 ✓ |
| `runtime.pitch_min` | 有限 ✓ | 档案**无** ✗；M26 = **−10** ✓ | 设计 ✓ |
| `runtime.pitch_max` | 有限 ✓ | 档案**无** ✗；M26 = **20** ✓ | 设计 ✓ |
| `runtime.penetration_curve` | **数组** ✓（生产包为**多点列表** ✓ `[[0,150],[500,125],[1500,95]]` ✓） | 档案仅有 `hitPower=260`（**两车相同** ✗⇒部分归一化 ✓） | 设计 ✓（**单点即退化编造** ✗，我不做 ✓） |

## B. 史料（3 项）—— 需**史料/文档** ✓
| 字段 | 要求 | 已有依据 | 说明 |
|---|---|---|---|
| `assembly.year` | 有限数值 ✓ | 档案仅有**参考游戏上线日期**（2018-09-11 / 2018-06-06）✗ —— **已明确拒绝** ✓ | 需车辆**历史年份**的史料 ✓ |
| `assembly.suspension` | 非空字符串 ✓ | 档案**悬挂字段 = 0** ✓（已核查 ✓） | 需史料 ✓ |
| `assembly.mount` | 非空字符串 ✓ | 档案仅有 `weapon_references[].source_weapon_id` ✓ | 需炮架型号（如生产包的 `M67` ✓ 格式）✓ |

## C. 独立尺寸资料（2 项）—— **必须外部来源** ✓
| 字段 | 要求 | 为何不能由我给 ✗ |
|---|---|---|
| `dimensions.width_m` | 正数 ✓ | 校验器用它做 **≤16% 包络互校** ✓ —— 若填**我自己的测量** ✓，该检查将**循环自证** ✗✗ |
| `dimensions.reference_length_m` | 正数 ✓ | 同上 ✓ |

## D. 待裁定（非缺口，但决定 B 类能否落盘 ✓）
**armor 17 zone 映射三项** ✓：① 档案粒度粗于项目时**是否接受同值** ✓；② 多段（炮塔侧/顶）**取哪段代表值** ✓；③ **准入判断** ✓（档案自称 `runtime_admitted:false` ✓）。
⇒ 一旦裁定 ✓，我可按已备好的两份映射表生成 `armor` 17 项 ✓（`facts` 带 `wt-2.57.1.137#L<行号>` 引用 ✓），预计缺口**一次降 17** ✓。

## E. 已完成（**无需任何输入** ✓，均已由管线验证 ✓）
`geometry`（由模型实测 ✓，29/29 校验通过 ✓）· `facts`（逐条带引用 ✓：速度/倒车/转速/质量/发动机/弹药容量/乘员角色 ✓）· `assembly.gun`/`shell`/`caliber_mm`/`variant` ✓ · `runtime.rounds`/`muzzle_velocity`/`acceleration`/`forward_max_speed`/`reverse_max_speed`/`hull_turn_speed` ✓ · `crew`（角色引用 + 位置派生 ✓）· `modules`（7 kind ✓ + 弹架精确配平 ✓）
**缺口从 24 → 9**（豹2 25 → 10）✓，每一步下降都对应实际提供并接线的字段 ✓。

---

## F. 裁定后**立即落盘**的准备已完成 ✓
`tests/build_modern_armor_draft.gd` ✓ 已按两份映射表生成 **draft** ✓（**待评审** ✓，不注册、不写配置 ✓）：
| 车 | zones | 材料分布 | 代表值（带引用 ✓） |
|---|---|---|---|
| T-80B | **17** ✓ | `cast×5` · **`unknown×12`** ✓（其档案**车体行不带 armourClass** ✗ ⇒ **如实取 unknown，不硬套** ✓） | `turret_front 250` ✓ `#L91` · `turret_sides 157` ✓ |
| 豹2A4 | **17** ✓ | `rolled×14` · `composite×1` · `cast×2` ✓ | `turret_front 250` ✓ `#L113` · `turret_sides 160` ✓ |
每 zone 均含：来源节点 ✓ · **行号** ✓ · `mapping_note`（粒度共用/多段取值的说明 ✓）；状态 `reference_pending_review` ✓。
⇒ **裁定一句话，17 项即可落盘** ✓。
