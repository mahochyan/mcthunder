# WT-036-R1：`run_industrial_battle_checks` 两项失败的分类（含**可检验预测**）

## 1. 套件结构
16 项检查，**逐 seed 运行**（本轮观测 seed **23023** 与 **23024**）；每 seed 检查：
```gdscript
check(reached.size()>=6 and reached_teams[1].size()>=3 and reached_teams[2].size()>=3, "at least three actual slots from each team physically reach central approaches")
check(shots.size()>=6, "at least six actual AI slots acquire targets and fire")
check(max_still<90, "no healthy actor trying to drive stays stationary for 90 seconds")
```
观测：**seed 23023 全绿** ✓；**seed 23024 两项失败** ✗（该局 4v4 占点，`victory`，**476.7 s**，tickets {1:109, 2:0}，shots=11）。

## 2. 基线对照（未改动 main）—— 已完成
```
baseline exit=1  PASS=15  FAIL=1
  [FAIL] at least three actual slots from each team physically reach central approaches
```
| 检查 | 基线 | 本分支 pre-fix | 定性 |
|---|---|---|---|
| **每队 ≥3 实体抵达中央** | **FAIL** ✗ | FAIL | **既有基线红**（与本分支无关）✓ |
| **无健康实体静止 ≥90 s** | **PASS** ✓ | **FAIL** ✗ | **疑为本分支引入** ✗ → 待 post-fix 实测 |

## 3. 机制解释与**可检验预测**
- pre-fix 本分支的失败形态：AI 车正面对峙时**双方长期 `yielding`**（`has_goal` 仍为真 ⇒ 检查视其为"**正在尝试行驶**"却在原地 ✗）⇒ `max_still ≥ 90` ✗
- 本轮修法改为：对峙**有限次重规划后显式失败**（`failed("mutual_yield")`，`has_goal=false`）⇒ 该实体**不再"正在尝试行驶"** ⇒ 应**不计入** `max_still` ✓
- **预测（下一轮对账）**：post-fix 运行时
  1. `no healthy actor … stationary for 90 seconds` 应**转绿** ✓；
  2. `at least three actual slots … reach central approaches` **仍失败**（既有红 ✓）。
- 若预测①不成立 ⇒ 说明仍存在"正在尝试行驶却不动"的实体，须继续定位（届时用套件的 `[battle] seed=… actors={…}` 逐 30 s 诊断读具体实体）✓

## 4. 处置（依对账结果）
- 既有红（抵达项）→ **登记**，与 `T018-H01` 同类（既有 + 场景相关），并建议独立立项（工业图中央抵达率）；
- 若②之外仍有引入项 → 按产品修复流程（含六套件回归）✓
