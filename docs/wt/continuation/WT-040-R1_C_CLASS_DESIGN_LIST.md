# 第 ③ 步 C 类：**纯设计项与可引项清单**（两车通用框架 ✓）

> 依据：`validate_package` 硬要求 ✓ + 两车档案 `raw_fields` 实测 ✓。
> **重要性质声明** ✓：档案值来自 `warthunder_reference` ✓（`historical_verified=false` ✓），且含 **`街机功率倍率=×1.5`** ✗
> ⇒ 属**另一款游戏的街机数据** ✓ ⇒ 只能作**可引起点** ✓，**不得**当作现实性能 ✗ 或本项目设计 ✗。

## A. 原本以为要"设计"、实则**档案可引**（⇒ 移入 B 类 ✓，带行号 ✓）
| 项目字段 | 档案字段 | T-80B | 豹2A4 |
|---|---|---|---|
| `runtime.forward_max_speed` | 前进极速 | 75.0 km/h（=20.83 m/s ✓） | 同 ✓ |
| `runtime.reverse_max_speed` | 倒车极速 | 10.0 km/h ✓ | 同 ✓ |
| `runtime.hull_turn_speed` | 最大车体转速 | 30.0 °/s ✓ | 同 ✓ |
| `runtime.acceleration` | 加减速度 | 4.0 ✓ | 同 ✓ |
| `runtime.rounds` | 备弹（主炮 ✓） | **38** ✓ | **42** ✓ |
| `runtime.turret_yaw_speed` / `turret_pitch_speed` | 转速 yaw/pitch | **24 / 3.35** ✓ | **40 / 40** ✓ |

## B. **仍需设计（无档案依据）** ✗ —— 逐条列出"需谁定" ✓
| 字段 | 需谁定 | 说明 |
|---|---|---|
| `runtime.reload_time` | **设计** | 档案未见 ✓ ⇒ 按同代车同档取值并由设计确认 ✓ |
| `runtime.pitch_min` / `pitch_max` | **设计** | 档案给的是**转速** ✗ 非**俯仰限位** ✓ ⇒ 需设计或另行查资料 ✓ |
| `runtime.muzzle_velocity` | **资料/设计** | 档案弹药段可能有 ✓ ⇒ 取用时**带行号** ✓ |
| `runtime.penetration_curve` | **资料/设计** | 需明确"初值曲线"口径 ✓（不得冒充实测 ✓） |
| `assembly`（火炮/口径/装配 ✓） | **资料+设计** | 武器段可引（`weapon_references` ✓ 含 `125mm_2A46_2` ✓ / `120mm` ✓） |
| `compatible_shells`（可配弹种 ✓） | **设计** | 参照既有 `configs/shells/historical_loadouts.json` ✓ |
| `license` / `limitations` | **用户/授权** | **E3 未授权** ✓ ⇒ 保持 NOT_RUN ✓ |
| `evidence_profile`（`game_reference` ✓） | **用户裁定** | 与"准入"同一判断 ✓ |

## C. 我**不会**做的事 ✗
- 不把 `×1.5 街机功率倍率` 当作本项目规则 ✗；
- 不用"通用模板数值"冒充具体车型 ✗；
- 不擅自把 `runtime_admitted:false` 的档案升格为战斗配置 ✗（须您裁定 ✓）。
