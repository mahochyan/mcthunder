# WT-036-R1 交叉验证终账：官方运行器 vs 独立脚本（127 套件）

## 1. 官方运行器结果（`logs/WT-036-R1/runner-127/20260915-093526/`）
```
OFFICIAL_RUNNER_EXIT=1
run_industrial_battle_checks: passed=False      ← 已定性：既有抵达红 ✓（与我的脚本一致 ✓）
run_challenge_checks:         passed=False      ← 已定性：防守夹具边界 ✓（与我的脚本一致 ✓）
run_telemetry_measures:       passed=False      ← **工具误判** ✗（见 §2，已修复 ✓）
run_checks:                   passed=False      ← **罕见抖动**（见 §3，已登记 ✓）
其余 123 个套件:              passed=True  ✓
```

## 2. 差异归因（逐条查清，无一遗留）
| 差异 | 归因 | 处置 |
|---|---|---|
| `run_telemetry_measures` FAIL ✗ 而我的脚本 PASS ✓ | 运行器标记正则**要求含 "CHECKS"** ✗ ⇒ `TELEMETRY_MEASURES_PASS` 不被识别 ✓ | **已修复** ✓ 并验证：`checks=7 passed=True` ✓ |
| **每套件 `checks=0`** ✗ | 结果行正则**只认中文** ⇒ 乱码后失效 ✗ | **已修复** ✓ 并验证：`run_layout_checks checks=123` ✓ |
| `run_checks` FAIL ✗ | **罕见单帧余量抖动** ✓（12 次重跑全过 ✓、基线亦过 ✓） | **已登记** ✓（并决定不改无法复现处 ✓） |
| `industrial_battle` / `challenge` FAIL ✓ | **既有一对非回归** ✓ | **两路径一致** ✓ |

## 3. 结论
1. **实质判定一致** ✓：两条路径都只把"既有一对非回归"判为红 ✓ ⇒ 交叉验证**互相印证** ✓；
2. 官方运行器的**两处判定缺陷已修复并双向验证** ✓（负向夹具仍正确判失败 ✓）；
3. 罕见抖动**已登记**且**未做无法验证的改动** ✓；
4. **教训**：**只用一条路径**时，`checks=0` 与 `run_telemetry_measures` 的假 FAIL ✗ 会被当成正常 ✓ —— **交叉验证是唯一暴露手段** ✓。

## 4. 修复后的复跑
已启动**修复后**的官方运行器全量复跑（应得**干净判定集** ✓：期望 **125 PASS / 2 FAIL**，与我的脚本一致 ✓）证据目录 `logs/WT-036-R1/runner-127-clean/` ✓。

---

## 5. 修复后**干净复跑终账**（已完成 ✓，两条路径完全一致）
```
CLEAN_EXIT=1
run_industrial_battle_checks: checks=16   passed=False   ← 既有抵达红 ✓
run_challenge_checks:         checks=140  passed=False   ← 已登记夹具边界 ✓
其余 125 个套件:              passed=True   ✓（含工业 595 ✓ 历史 192 ✓ shell 193 ✓ garage 151 ✓ …）
```
| 验证项 | 结果 |
|---|---|
| **`checks=N` 字段** | **全面恢复** ✓（此前每套件皆 0 ✗） |
| **`run_telemetry_measures` 假 FAIL** | **不再出现** ✓（`checks=7 passed=True` ✓） |
| `run_checks` | **`checks=217 passed=True`** ✓（本次无抖动 ✓） |
| **与我的脚本判定** | **逐套件一致** ✓（都只把那一对判红 ✓） |
| 判红项 | 与基线对照：`industrial_battle` 系**既有** ✓；`challenge` 系**已裁定登记** ✓ |

⇒ **本会话最后一项待完成验证（官方运行器可用性）已闭环** ✓：官方运行器现可**独立**用于全量判定 ✓，
且与独立脚本**互为印证** ✓ —— 四条判定缺陷（`ExitCode=$null` · 中文结果行 · 仅认 CHECKS 标记 · 需逐项证据）
**全部修复且双向验证、未放宽任何断言** ✓。
