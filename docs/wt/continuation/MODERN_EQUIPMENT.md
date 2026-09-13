# 现代能力与模块依赖矩阵（WT-028-R1）

- 依据：`03_全部42项目标工作单.md` WT-028（行 1153-1192）
- 实现：新增 `scripts/content/modern_equipment.gd`（装备表 + 依赖矩阵 + 传感器/供电规则）
- 验证：新增 `tests/run_modern_equipment_checks.gd`（**55/55 PASS**）+ 回归 `run_observation_policy_checks` **PASS**、`run_vehicle_readiness_checks` **PASS**、`run_optics_checks` **PASS**

## 1. 首发必须能力（已冻结）

`rangefinding` · `sight` · `power` · `fire_control_dependency`（四项，套件断言存在且冻结）

## 2. 能力与模块依赖矩阵（交付物第一条）

| 装备 | 分级 | 依赖模块 | 需要供电 | 传感器通道 | 对应角色能力 |
|---|---|---|---|---|---|
| 测距仪 | **实验** | `rangefinder` | 否 | — | rangefinding |
| 光学瞄准镜 | **实验** | `optics` | 否 | optical | sight |
| 热像瞄准镜 | **实验** | `optics` | **是** | thermal | sight |
| 夜视 | **实验** | `optics` | **是** | thermal | sight |
| 火控计算机 | **实验** | `fire_control` | **是** | — | fire_control_dependency |
| 火炮稳定器 | **实验** | `turret_drive` | **是** | — | fire_control_dependency |

| 车型 | 装备（**逐车显式**） |
|---|---|
| T-80B | 测距 + 光学 + 热像 + **夜视** + 火控 + 稳定器 |
| 豹 2A4 | 测距 + 光学 + 热像 + 火控 + 稳定器（**无夜视**） |
| 未登记车型 | **无任何装备**（`not_equipped`） |

**依赖可追责**：`required_modules()` 输出真实模块 id（`optics`/`fire_control`/`turret_drive`/`rangefinder`），模块受损即可映射到能力失效。

## 3. 已支持 / 实验 / 未实现 能力列表（交付物第二条）

| 状态 | 内容 |
|---|---|
| **已支持（supported）** | **无**——本单不把任何现代能力标成"已完成" |
| **实验（experimental）** | 上表六项（全部 `provenance=game_rule`，**不声称历史性能**） |
| **未实现（unimplemented，需独立功能单）** | 激光告警接收机 · 雷达 · 主动防护 · 制导弹药 · 可编程弹药——每项均已登记**抽象可标定规则**（如"告警只给方向带，不给发射者身份或内构"） |

`fully_ready(vehicle, role)` 的判据是"该角色所需能力**全部由 supported 级装备满足**"→ 当前**任何现代角色都不得报告为完整就绪**（`reason=no_supported_tier_yet`），直接满足"未支持的装备车辆不被错误标成对应角色完整就绪"。

## 4. 传感器受损与权限回归（交付物第三条）

### 4.1 墙 / 烟 / 通道切换遵守信息规则
| 情形 | 结果 |
|---|---|
| 烟 + 光学 | **完全阻挡**（`blocked`） |
| 烟 + 热像 | **衰减 0.6（不阻挡）** —— 有自己的规则，非"所有烟对所有通道相同" |
| 建筑 + 热像 | **完全阻挡** → **热像不会把全场敌车涂白穿墙** |
| 开阔地 + 光学 | 衰减 0 |

规则来源统一：`sensor_visibility()` 直接调用 WT-017 的 `ObservationPolicy.attenuation/visual_blocked`（套件断言两者相等）。

### 4.2 供电损坏与"提示=实际能力"
| 情形 | 结果 |
|---|---|
| 断电 | 热像/夜视/火控/稳定器 → **`power_lost`**；**光学与测距仍可用** |
| 角色就绪 | 有电 → gunner 所需能力齐备；断电 → **不就绪且 `missing` 指名 `fire_control_dependency`**（提示可与现实对齐） |
| `power_report()` | 明确列出 `lost` / `kept` 两清单 |

### 4.3 关闭特效不会关闭玩法限制
- 模块**不引用**任何显示设置（套件对源码扫描 `AccessibilitySettings`/`fx_level`，均不存在）；
- 三段画质（0/1/2）下烟的**热像衰减完全一致** → 关特效不改变玩法传感器限制。

## 5. 明确不做（对齐父项）

- **不公开推导现实非公开防护/武器参数**：全部为 `game_rule` 设计值，`historical_values_claimed=false`（套件断言）。
- **不把一辆能力齐全样车当所有现代系统已完成**：`supported` 为空、五个高阶系统明确 `unimplemented`、完整就绪判据拒绝虚报。
- 两车**仍 `candidate_only`**，本单未改任何准入状态。

## 6. 未完成（如实）

- 装备**尚未接入** `VehicleActor` 生产光电路径（生产仍用 `configs/optics/*.tres` 的历史两车配置；现代车尚无 .tres 光电配置）→ 属 WT-028 剩余工作（需新增现代光电配置并在准入后接入）。
- 告警/雷达/APS/制导弹药/可编程弹药：**未实现**（各自独立功能单）。
- 窗口 UI 提示（供电/传感器受损）、真人 `NOT_RUN`；性能 `HOLD_BY_USER`。
