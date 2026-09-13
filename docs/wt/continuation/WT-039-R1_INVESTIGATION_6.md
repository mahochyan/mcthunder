# WT-039-R1 结论 · 第 6 轮（**"整平侧翼路"假设被否证并已回退**；附带解决一个门内 DEFERRED）

- 承接第 5 轮（根因：刚体包络被坡脊楔住；烘焙因 `exclude=[ground]` 漏检；新增检查 `T018-03b` 报 **38** 个受阻采样）
- 本轮尝试**修复路线 A**（地形/道路整平），**实测变差 → 按纪律立即回退**，并记录否证与后续选项

## 1. 被否证的修复（负结果，按纪律记录）

| 项 | 内容 |
|---|---|
| 假设 | 把 x≈−120 的侧翼路做成**公路切坡**（走廊内按两端线性纵坡、外侧渐回解析地形）即可让 8.5 m 刚体盒通过 |
| 实现 | `village_world.gd`：新增 `FLANK_CORRIDOR` + `graded_height()`，`ground()` 改用它采样 4 m 网格 |
| **实测结果** | `T018-03b` 受阻采样 **38 → 55（更差）**；宽体代理山丘检查**仍失败** |
| 原因分析 | 我的切坡只做到 **C0 连续**：走廊横向从"坡道平台"渐回解析丘体时形成**新的横向坡度**（≈15.6°），与纵向 8.4° 叠加 → 在平台边缘**制造了新的楔入点**；纵向端点也非 C1 |
| 处置 | **立即回退**（不改地图数据） |

## 2. 回退证据（可复核）

```
git diff --stat a1bac406..HEAD -- scripts/maps/village_world.gd   →  （空：该文件在全分支上从未改动）
git diff --name-only -- scripts/maps/village_world.gd             →  （空：工作区与 HEAD 一致）
```
回退后实跑 `run_map_checks`：
```
[PASS] T018-03 every authored road has real ground and clears maximum vehicle envelope
[FAIL] T018-03b … (blocked samples=38)          ← 回到 38，证明 55 是我这次改动造成且已消除
PASS=46 FAIL=3
```

## 3. 附带收获：门内一个 DEFERRED 已解决

| 套件 | 回归门（120 s 看门狗） | 本轮（600 s 预算） |
|---|---|---|
| `run_village_battle_checks` | `DEFERRED`（超时仍在输出） | **21 PASS / 0 FAIL（206.8 s）** ✓ |
| `run_structure_checks` | PASS | **54 PASS / 0 FAIL（46.8 s）** ✓ |

→ 村庄整局与结构套件在**原始地形**下均**全绿**；说明侧翼坡道的包络问题**不影响**这两条主流程验收。

## 4. 后续选项（按代价/风险排序，下一轮首选②）

| # | 方案 | 依据/代价 |
|---|---|---|
| ① | **C1 连续**的地形整平（Hermite/clothoid 融合，横向与纵向同时 C1） | 修正我这次的 C0 缺陷；代价中等，需完整地图回归 |
| ② | **提高地形网格分辨率**（4 m → 2 m） | **最省**：直接检验"受阻是否来自 4 m 面片与解析曲面的偏差"；可逆、单一变量；若受阻降为 0，则根因是**网格离散化**而非山体解析曲率 |
| ③ | 重新定义 `max_vehicle_size` 的语义（**刚体**包络 vs **包围**包络） | 属设计决策：真实车辆带悬挂/履带多接触点（M26 孤立运行可通行），而测试代理是**无悬挂刚体盒**；改变语义会**削弱**检查，须显式说明并获认可 |
| ④ | 仅登记缺口 | 缺陷仍在，不单独采用 |

**红线遵循**：不为让检查变绿而放宽阈值；不动 `DRIVE_MAX_SLOPE_DEG`、车辆定义与战斗参数；若最终落在车辆机动参数 → **只登记为参数冲突**。

## 5. 本轮边界

- `scripts/maps/village_world.gd`：**净零改动**（改后回退，工作区与 HEAD 一致）；
- 产品侧唯一保留改动是上一轮的**烘焙诊断字段**（`curvature_failures`，不改 `ok` 语义）；
- 未触碰：车辆定义、图数据、脏文件、构建流程。
- 证据：`logs/WT-039-r1/run_map_checks-after-grading.log`（55）、`…-after-revert.log`（38）、`run_village_battle_checks-after-grading.log`、`run_structure_checks-after-grading.log`。
