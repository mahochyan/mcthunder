# WT-CD-016 交付｜对标矩阵、两车完成样片与独立交付

**状态：COMPLETE（六项验收 CD16-T01…T06 全部执行并达到）**，其中真人体验与对外行为对照仍为 PENDING / NOT_COMPARED，
发布状态 `release_ready=false` / `public_release=false` / `candidate=true` / `human=PENDING`。

本文件按交付协议 `original/05_DELIVERY_AND_ACCEPTANCE.md` 的六类交付物组织，并附本包要求的
"战雷行为 → 代码位置 → 场景编号" 对照表。证据正文见 `COMBAT_DEEPEN01_CD016_EVIDENCE.md`（第 1–28 节），
结果记录见 `COMBAT_DEEPEN01_CD016_RESULTS.json`。

---

## 1. 生产实现（真实代码/配置/资源与必要迁移）

本单是出口单，不新增玩法规则；它把前十五单的实现集成、冻结并交付为一个可独立安装的内部开发包。本单自身改动的生产代码只有两处诊断验证器：

| 文件 | 改动 | 为什么 |
|---|---|---|
| `scripts/diagnostics/modern_match_verifier.gd` | 期望弹数由流程**自己的编辑动作**派生（`edited_count`），并新增一条自解释诊断 `MODERN_SPAWN` | 写死的 18 是两种弹时代的数；CD07 交付第三弹后同一编辑动作产生 24 |
| `scripts/diagnostics/modern_life_verifier.gd` | 座位移除"按工位 id 查乘员"，改走生产映射（工位→角色→人）；新生命弹数由夹具自身编辑派生 | CD08-T02 已把人身份与工位/角色分离，旧读法导致脚本敌方一炮未发 |

规则迁移共两条，均按协议记入 `COMBAT_DEEPEN01_RULE_MIGRATION.json`（第 34、35 条，20 字段，追加前对既有条目**逐字节自证**）：

- `cd16-modern-player-flow-derived-edit-v1`（18 → 派生）
- `cd16-modern-life-fixture-derived-edit-v1`（8 → 派生，并含座位置读法的修复）

## 2. 源码身份

| 身份 | 值 |
|---|---|
| `base_sha`（包基线／分支起点） | `cacc1ed3cc3a7e2b4f7cc0df66e6ca82e6c149ec` |
| `implementation_sha` | `dcc9e1c278483c07ef9260cc4fc14d23ae116306` |
| `tested_sha` | `dcc9e1c278483c07ef9260cc4fc14d23ae116306` |
| `final_sha` | `dcc9e1c278483c07ef9260cc4fc14d23ae116306` |
| 证据提交（与被测提交分开） | `b9f9e4b9`（T01–T06 证据）及本交付提交 |
| 引擎 | `4.7.2.stable.official.ed1daf0bf` |
| 内容/规则版本 | 见 `COMBAT_DEEPEN01_CD016_RESULTS.json` 的 `content_version` / `rules_version` |

包内 `BUILD_MANIFEST.json` 记录 `source_sha`、引擎、`release_ready=false`、`public_release=false`、
`modern_river_required=true`、`human=PENDING`、`full_player_flow=PENDING_SEPARATE_VERIFICATION`，
以及每个随包文件的大小与 sha256（`files` 7 条）。

## 3. 运行证据（实际命令、退出码、原始输出）

| 步骤 | 命令（工作目录 `E:\AIprogram\mcthunder-cont`） | 退出码 | 证据路径 |
|---|---|---|---|
| 建包 | `tests\build_release.ps1 -Candidate -ModernRiver -CommittedSnapshot` | 0（4692 秒） | `logs/031/dcc9e1c2…/build-20260920-040815-488/` |
| 包・现代玩家流程（T02/T03/T06） | `tests\run_modern_player_flow.ps1 -Executable …\package\PixelArmor.exe -SourceSha dcc9e1c2…` | 0 | `logs/WT040-modern-player/dcc9e1c2…/20260920-052633-232/` |
| 包・车库用例（T02 两车） | `tests\run_modern_package_checks.ps1 … -Case garage` | 0 | `logs/WT040-package/dcc9e1c2…/garage-*/` |
| 包・生命用例（T04） | `tests\run_modern_package_checks.ps1 … -Case life` | 0 | `logs/WT040-package/dcc9e1c2…/life-20260920-053054-775/` |
| 包・更宽玩家流程 | `tests\run_player_flow_checks.ps1 …` | 0 | `logs/034/dcc9e1c2…/20260920-053116/` |

建包内部步骤（各自判定）：`fresh_import` ✓、`regression`（候选模式容忍，交由登记表判定）、`export_release` ✓、
`engine_notices` ✓、`independent_default_start` ✓、`independent_content` ✓、`independent_window` ✓。

## 4. 操作证据（正常输入步骤、真实截图、事件记录）

四次包验证都是**打包后的可执行文件**用真实键鼠、真实等待、真实窗口驱动，各自重定向 `APPDATA`，
**不触碰用户自己的存档**；每次运行前后都校验 exe/pck 哈希未变。

| 验收 | 判定 | 真实截图 / 记录 |
|---|---|---|
| T02 两车入口与配装 | `MODERN_GARAGE_CHECKS_PASS`，37 项 0 失败 | `ussr_t_80b_garage.png`、`ussr_t_80b_river.png`、`germ_leopard_2a4_garage.png`、`germ_leopard_2a4_river.png` |
| T03 正常完整对局 | `MODERN_MATCH_PASS`，30 项 0 失败 | `00_prepared.png`、`01_deployed.png`、`03_driving.png`、`04_result.png`、`events.json`（含逐 10 秒遥测与玩家射击记录） |
| T03 下一局 | 同一检查内的 `05_next_match.png` | 新对局使用所选车辆与已保存配弹 |
| T04 同生命实弹再出击 | `PLAYER_LIVE_ROUND_PASS`，9 项 0 失败 | `waiting.png`、`respawned.png`、`evidence.json`（敌弹接触/伤害、一次死亡、扣票、新生命） |
| T06 关闭重启与独立路径 | 独立进程 `--resume-proof` exit 0；存档哈希前后一致 | `06_fresh_process.png` |
| 更宽玩家流程 | `PLAYER_FLOW_CHECKS_PASS`，**96 项** 0 失败 | 13 张（车库主菜单、挑战规则、侧翼起瞄、星光保存、真实射击回放、个人最佳、防御起始、M36 路线、两局对战、两局结算） |

夹具声明：T04 的 `--verify-modern-life` **自报**为平地对遇 + 脚本敌方操作手夹具（非自然对局）；两条自然流程
（`--verify-modern-match`、`--verify-player-flow`）无任何注入。

## 5. 当前限制

- **真人体验：PENDING**，不代签、不把截图当真人验收。
- **对外行为对照：NOT_COMPARED**（作为行为捕捉）。已存在的对照都是对**解包数据文件**的来源比对；证据状态保持
  "工程自洽版"，不宣称与战雷实际对局行为的数值一致。
- **性能：HOLD_BY_USER**，不做 FPS/p95/容量测量。
- **三个已登记红项仍然为红且可见**（候选模式按登记表容忍，理由与测量都已记录，既未修复也未隐藏）：
  `run_village_battle_checks`（残骸封死咽喉：路线 7→19 航点）、`run_industrial_battle_checks`（既有抵达红项）、
  `run_challenge_checks`（防御脚本夹具边界，两次同名失败）。登记表要求失败集**完全吻合**，任何新失败或多出失败仍会中止建包。
- `run_turret_tick_checks` 按自身守卫拒绝在 `--headless` 下运行（需要显示），记为 NOT_RUN 而非失败。
- 本机战雷安装、解包数据与解包工具**不在包内、不入库**；只提交派生值与来源。

## 6. 接续与回退

- **下一个依赖任务**：本单是包内最后一个子单；后续是用户侧真人试玩，以及对着同一战雷安装的完整性队列
  （真实乘员工位、其余损伤部件、改装清单、T-80B 的 ATGM、以及本项目未建模的三发弹）。
- **旧档兼容**：`settings_schema=2`、`profile_schema=3`、`challenge_rules=1`；本单两条迁移**不改变存档格式**，
  旧档保留原计数，仅断言的真实来源改变。
- **git 回退范围**：本单生产代码改动只有两处验证器（见 §1）；`git revert` 对应提交即可回到上一可运行状态。
  期望值迁移条目保留在迁移表中，不删除旧值。
- **旧候选包（可用于比对或回退）**：
  - `backups/builds/031/dcc9e1c2…/20260920-040815-488/PixelArmor-1.0.0-rc.3-dev-Windows-x64-dcc9e1c2-devcandidate.zip`（本交付）
  - `…/5c6a8919…/PixelArmor-…-5c6a8919-devcandidate.zip`（上一候选，生命用例在此暴露回归）
  - `…/4a2c9744…/PixelArmor-…-4a2c9744-devcandidate.zip`（首个成功候选，现代玩家流程在此暴露陈旧期望值）
- 不删除用户文件作为回退；用户未跟踪的 PNG 与 `backups/` 下的产物保持原样。

---

## 7. 战雷行为 → 代码位置 → 场景编号

对外来源：本机战雷安装 **2.59.0.13**，用 `wt_ext_cli v0.6.6` 解包（工具与解包结果在仓库外，仅提交派生值与来源）。
场景编号：**CD** = 执行包子单与验收场景；**BM** = `COMBAT_DEEPEN01_BENCHMARK_MATRIX` 行号；**EXP** = 经用户授权的包外扩展。

| 战雷行为（来源文件与值） | 本工程代码位置 | 场景编号 | 对照状态 |
|---|---|---|---|
| 125mm 3BM42 APFSDS 初速 **1700 m/s**（`125mm_2a46_2_user_cannon.blk`） | `configs/vehicles/engineering/ussr_t_80b.json` → `shell_catalog.shells.muzzle_velocity_mps`；发射路径 `scripts/gunner.gd` | CD04 / `BM-03-cd004-ballistics-v1` | **COMPARED_TO_SOURCE_FILE — EQUAL** |
| 120mm NATO APDS_FS 初速 **1650 m/s**（`120mm_rheinmetall_l44_user_cannon.blk`） | `germ_leopard_2a4.json` 同上字段 | CD04 / 同一 BM 行 | **COMPARED_TO_SOURCE_FILE — EQUAL** |
| 125mm HE 初速 **850 m/s** | `ussr_t_80b.json` 两处（`shell_catalog` 与证据声明） | CD07 / CD16（`cd16-he-velocity-850-v1`） | SOURCE_RULE（声明的行为变更，旧值 700 作为 before 保留） |
| 125mm HEAT 3BK12 **905 m/s**；NATO HEAT_FS **1140 m/s** | 两个包件的 `shell_catalog` | CD07 / CD13 | SOURCE_RULE |
| 行驶档位/加速度/转速（战雷 drive 文件） | 两个包件的 `drive_profile`；`scripts/tank.gd`、`scripts/powertrain` 路径 | CD11 / `BM-18-cd11-drive-profiles-v1` | **COMPARED_TO_SOURCE_FILE — EQUAL** |
| 装甲厚度：T-80B 首上 80/80/30/60/20、炮塔正面 250、侧面 157、顶 90、炮盾 50；豹2A4 首上 400、炮塔正面 250、侧面 160 | 两个包件的 `armor` 分区 | CD02 / CD05；`WT_ARMOR_COMPARISON.json`（34 行：27 精确匹配、7 候选包含之、0 无候选） | COMPARED_TO_SOURCE_FILE |
| 副武器：7.62 PKT 弹带 750 / 装填 8 s / 11.66 发秒 / 817.5 m/s；12.7 NSV 250 / 5 s / 11.666 / 865；7.92 MG3 200 / 8 s / 20 发秒 / 853 | `scripts/gunner.gd`（`install_secondary` / `try_fire_secondary` / `advance_secondary`）；两个包件的 `secondary_weapons` | **EXP-01**（授权扩展，探针 71 项 0 失败） | SOURCE_RULE（值取自枪文件） |
| 装填节奏：枪文件 `shotFreq` 0.16666（6 s） vs 本工程 `runtime.reload_time` **7.1 s** | 两个包件的 `runtime.reload_time` | 来源行（`docs/wt/wt-reference/README.md`） | **DIVERGENCE 已记录**（项目设计选择，非外部真值） |
| 弹道保留率 0.972/0.932/0.869/0.811 | `scripts/defs` 弹道剖面 + 火控求解 | CD04 / `BM-03` | COMPARED_TO_SOURCE_FILE（最大偏差 0.0034） |
| **未建模弹种**：`125mm_ussr_APDS_FS` 1760 m/s / 4.83 kg、`120mm_DM_APDS_FS` 1640 m/s / 4.3 kg、`125mm_ussr_ATGM` 27.5 kg | 尚未实现 | OPEN GAP（列在 `WT_REFERENCE_UNITS.json` / README） | **NOT_COMPARED** |
| 无公开可比版本（历史对标） | — | `BM` 行 "publicly comparable version" | **NOT_COMPARED** |

对照层四类互不替代，本单的分布：`SOURCE_RULE` 与 `PROJECT_FIXTURE` 为多数，**`COMPARED_TO_SOURCE_FILE` 3 行**
（CD04 弹道、CD11 行驶剖面、CD07 HE 家族），`WT_BEHAVIOR_COMPARISON` 行数为 **0**，`HUMAN_PLAYTEST` 为 **PENDING**；
矩阵不给任何伪精确的总体相似度百分比。
