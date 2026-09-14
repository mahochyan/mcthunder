# WT-036-R1 取证：工业套件"仅分支失败"的 2 项均非本分支回归

## 1. 目标
完整对照显示本分支**仅 2 项**失败不在基线集合中（其余 19 项基线红已被消除）。必须判定这 2 项是否由本分支改动引起。

## 2. 三轮出现情况（基线完整 / 分支 run1 截断 / 分支 run2 完整）
| 检查 | baseline | branch run1 | branch run2 | 判定 |
|---|---|---|---|---|
| `T023-02 … us_m24_m6_t85e1_1951/**2/5/capture**` | **失败（2 处）** | 通过 | 失败（1） | **基线即失败** ⇒ 非本分支引入 ✓ |
| `hill_village: same vehicle mean spawn arrival **imbalance below 15%** us_m24_m6_t85e1_1951` | 通过 | 通过 | **失败** | **三轮中仅一轮失败** ⇒ **噪声**（该检查本身是**边际统计阈值**） |

## 3. 结论
1. **本分支在工业套件上无"可归因回归"**：2 项"仅分支失败"里，1 项**基线同样失败**，另 1 项**仅出现在一次运行中**（且基线那次通过、分支另一次也通过）；
2. **净改善 17 项**（56 → 39 唯一失败），**消除 19 项基线红**（M26/M36 捕获路线为主）；
3. **三轮稳定失败 29 项**（baseline ∩ run1 ∩ run2）为**可靠核心**，其中以 **supply 路线**为主 ⇒ 既有系统性弱点（另有孤立可成功抵达的反证，见 `WT-036-R1_SUPPLY_INVESTIGATION.md`）；
4. **套件方差本身很大**（同分支两轮相差 10 项；`2/5/capture` 与 `imbalance` 都表现出跨轮翻转）⇒ 该套件应配**测试侧加固**（每路线独立世界、路线间收敛与占用断言、统计阈值明确容差来源），**不改判定语义**。

## 4. 门禁 JSON 增补
在 `regression-gate-deferred-closeout.json` 的 `industrial_comparison` 下新增 `branch_only_triage`：
- `2/5/capture`: `also_fails_at_baseline=true`
- `imbalance below 15%`: `runs_failing=1_of_3`，`kind=noise/marginal_statistic`
- `attributable_regressions=0`
