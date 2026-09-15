# 第 ⑤ 步**现状审计**（完整流程 + 独立包 ✓ 代码级 ✓）

## 1. 各环节覆盖（`git grep` ✓）
| 环节 | 脚本 | 测试 | 关键套件 |
|---|---|---|---|
| **科技树选车** ✓ | `scripts/content/tech_segment.gd`（**148 行** ✓） | ✓ | `run_tech_segment_checks.gd` ✓ |
| 配弹 / 挂载 ✓ | 25 ✓ | 30 ✓ | — |
| 交火 ✓ | 16 ✓ | 16 ✓ | `record_river_ai_match.gd` ✓ |
| **阵亡 / 再出击** ✓ | **64** ✓ | **67** ✓ | — |
| 结算 ✓ | 3 ✓ | 3 ✓ | `run_duel_checks.gd` ✓ |
| **下一局** ✓ | 3 ✓ | 3 ✓ | **`run_app_match_cycle.gd`** ✓ |
| **重启保存** ✓ | 5 ✓ | 10 ✓ | — |

**更正** ✗：首轮 grep 把"科技树"记成 **0 脚本** ✗ —— 实为**检索式假象** ✓（`tech_segment.gd` 148 行 ✓ 与套件均在 ✓）。

## 2. **真正的端到端套件**（第 ⑤ 步的核心 ✓）
| 套件 | 性质（自述 ✓） |
|---|---|
| `run_app_flow_checks.gd` ✓（84 行） | 驱动真实 `AppFlow` ✓：车库 ✓ 档案 ✓ **有界等待转场** ✓ · 缺资源可恢复 ✓ · 错误返回保留档案与可玩车库 ✓ |
| `run_app_match_cycle.gd` ✓（52 行） | **"Natural matches: no injected outcome, damage, tickets or accelerated rule timers"** ✓ ⇒ 从**正常车库**开局 ✓ → 等到 `finished`（`tickets`/`time_limit` ✓）✓ |
| `run_player_flow_checks.ps1` ✓（44 行） | 需 `Executable` + `SourceSha` ✓ 并读 `BUILD_MANIFEST.json` ✓ ⇒ **导出包的玩家流程校验** ✓（**独立包验证路径** ✓） |

## 3. 结论（与第 ④ 步审计一致 ✓）
- **第 ⑤ 步同样不缺实现** ✗：从科技树到存档、从对局循环到导出包校验**全部存在且有门禁** ✓；
- **真正待做的**是**在真实成品上完整走一遍** ✓（第 3 阶段要求：真实命令 ✓ 完整输出 ✓ **UI 可复现步骤** ✓）；
- 其**前置**仍是：① 两车战斗包收口 ✓（**2 项几何修正已预验证** ✓ + **G–L 输入** ✓）；② **河谷战场级联**解开 ✓（**b 的设计已备好** ✓）。
