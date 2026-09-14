# WT-036-R1：8.5 m 刚体包络的**声明变更**（用户裁定 D2）

## 1. 裁定
用户在裁定包中选 **D2**：把 `MapDefinition.max_vehicle_size = (4.2, 2.4, 8.5)` 所代表的**刚体包络**明确为
**设计目标（design goal，非硬性需求）** ⇒ **文档与口径同步更新** ✓

## 2. 依据（本会话已实测）
| 证据 | 内容 |
|---|---|
| 仓库内**无车辆达到 8.5 m** | 最大实测为 M26 `(3.51 × 1.68 × 6.15)` ✓ |
| **仅刚体盒被楔住** | 作为无悬挂、无履带接触的**刚体盒**烘焙时 **38 / 1786** 采样受阻 ✓；**生产车辆**（有悬挂/多接触点）在孤立运行中**可通行** ✓ |
| 语义来源 | `max_vehicle_size` 在仓库内**无原始论证注释**（先前调查结论 ✓） |

## 3. 本次改了什么
| 文件 | 改动 |
|---|---|
| `scripts/maps/map_definition.gd` | 在**声明处**加注释：该包络为**声明的设计目标**，并说明**数值不变**的原因 ✓ |
| `tests/run_map_checks.gd` | 原"design-goal check, currently failing"**断言**改为**信息报告**（`[T018-03b design-goal, informational] … blocked samples=38 of 1786`）✓ ⇒ 地图套件由 **48/1 → 48/0（exit=0）** ✓ |

## 4. 本次**没有**改什么（明确边界）
- **数值不变** ✓：`max_vehicle_size` 仍为 `(4.2, 2.4, 8.5)`；
- `validate()` 仍以它的**宽度**做图门控 ✓；
- 烘焙与 `world_props` / `run_structure_checks` 仍消费该值 ✓；
- **未删除任何测量**：受阻采样数仍**逐次打印**（信息项 ✓），可随时复查 ✓。

## 5. 影响与回滚
- **影响**：地图套件由"1 项设计目标失败"转为**全绿** ✓；门禁 111 套件的失败项由 2 项减为 **1 项**（仅 `challenge` 防守夹具边界 ✓）；
- **回滚**：单提交可退（`54e54cfe`）✓ —— 把信息行恢复为断言即可 ✓。

## 6. 验证（本次实跑）
```
run_map_checks               exit=0  PASS=48  FAIL=0   ✓（含 informational 行）
run_village_battle_checks    exit=0  PASS=21  FAIL=0   ✓
run_slope_pivot_checks       exit=0  PASS=3   FAIL=0   ✓
```
