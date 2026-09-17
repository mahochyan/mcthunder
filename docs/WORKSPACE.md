# 统一工作区 — 2026-09-11

## 2026-09-17 分支收拢（最新）

按用户“合并掉多余分支”要求，`main` 已从 `a1bac406` 快进到现代河谷后继 `a005b681`。后续在 **E:/AIprogram/mcthunder 的 main** 开发。本地分支从 33 个减为 1 个，删除的 32 个中，29 个提交历史已包含于 main，另 3 个保留精确恢复标签：

- `archive/20260917/004-acceptance`：旧阶段状态说明，当前说明已更新，不回写旧内容。
- `archive/20260917/027-input`：已等价合入的输入改键提交；旧工作区未提交翻译修改仍保留。
- `archive/20260917/art-pilot`：22 个早期美术试验提交，原样归档，未覆盖当前模型。

旧工作树及 `E:/AIprogram/mcthunder-cont` 已在各自原提交脱离分支，文件和验证产物原位保留。它们只用于恢复、查看已有日志和包，不再作为并行开发线。没有删除远端分支或推送。

恢复目录：`E:/AIprogram/mcthunder-archive/branch-cleanup-20260917`。保存清理前的全部分支 SHA、工作树列表、main 和旧翻译工作区的二进制补丁、6 个用户修改文件的 SHA-256、53 个阻挡合并的本地生成 UID 原文件。`VERIFIED.json` 确认全部 33 个旧分支顶点仍可从 main 或恢复标签找到；main 的 6 个用户文件逐字节未变，旧翻译工作区补丁也未变。UID 使用新主线已提交的身份，旧身份可从备份恢复。

`a005b681` 的独立内部包已完成构建与内容/窗口验证，仍为 `release_ready=false / public_release=false`。本轮自然 AI 河谷整局为 8 项中 1 失败（仅 5 槽位开火），新包正常现代/历史完整玩家流程尚待复验。分支合并不代表产品整体验收通过。

下文是 2026-09-11 整理时的历史快照。

游戏入口：`E:/AIprogram/mcthunder/START_GAME.bat`。当前分支 `main`，由旧 29376e2 快进至最新游戏主线 9f59025，再加入本次模型展厅与整理。主目录原 AGENTS.md / project.godot 修改保存在 Git stash `workspace-consolidation-root-edits`，未用旧配置覆盖新游戏。

## 目录用途

| 目录 | 内容 |
|---|---|
| assets | 游戏实际使用的模型、纹理、声音、字体 |
| scenes / scripts / configs | 场景、逻辑与玩法数据 |
| authoring | 可编辑模型与制作脚本，由 .gdignore 排除运行时导入 |
| tests / docs / logs | 检查工具、开发路线、真实验证记录 |
| tools/godot | 本机引擎，不入 Git / 游戏包 |

车库顶栏“模型展厅 / Models”实际载入三款现代坦克，支持旋转、俯视、侧视与缩放。每次只保留一个模型，静止时不持续渲染展厅视口。四款原有战斗车辆继续使用原车型定义。现代车装甲、内构、火控、驾驶与联网规则仍待主线开发，展厅不将其伪装成完整战斗车型。

| 新资源 | 成品 | 可编辑源 |
|---|---|---|
| Leopard 2A7V | assets/vehicles/leopard2a7v/leopard2a7v.glb，10000 三角面，重设计涂装 | authoring/vehicles/leopard2a7v/leopard2a7v.blend |
| M1A1 HC | assets/vehicles/m1a1/m1a1.glb，3896 三角面，production_lods 带烘焙纹理成品 | authoring/vehicles/m1a1/m1a1.blend |
| ZTZ-99A | assets/vehicles/ztz99a/ztz99a_4000.glb，3996 三角面；保留 1K/2K 档 | authoring/ztz99a |

M1A1 的早期 stageB 源文件仍在 authoring/m1a1_stageB，因用户 Blender 正在打开它，未搬移或关闭该文件。展厅采用较新的 production_lods 成品。旧来源报告中的相对路径属于归档前结构。

## 旧目录与恢复

`E:/AIprogram/mcthunder-archive/workspace-content.zip` 是按内容 SHA-256 去重的快照；manifest.json 将每个原始路径映射到 ZIP 内 objects/<sha256>。37629 个文件对应 6851 个唯一内容对象，已逐对象复算 SHA-256，结果见旁边 VERIFIED.json。Git 历史与所有旧分支仍保留；主线 730 个未跟踪文件已复制回统一工程，无同路径内容冲突。

自动审批拒绝批量强制删除（仅返回 blocked by policy），因此没有声称已永久删除。5 个旧 Git 工作区、试玩副本、旧交付/测试目录和根目录模型试验文件夹已可恢复地搬入 `mcthunder-archive/retired`，不再占据活动项目目录。归档目前同时保留可恢复目录和压缩快照，尚未释放这些重复内容的磁盘空间。其他项目 idlgame、共享 tools、research-sources 未移动。

恢复单文件：按 manifest.json 查原路径，取 workspace-content.zip 中对应 objects/<sha256>，写入另一个恢复目录，再比对 SHA-256。不要直接覆盖当前源码。移动归档中的 Git 工作区请继续使用 git worktree move。

历史测试日志和 BASELINE.json 保留测试当时路径与提交，未篡改成当前目录。

## 本次验证

- 统一目录导入成功；基础驾驶/射击 217 项、HullFrame 25 项通过。
- 最终资源重导入成功；模型展厅 15 项、原有 Blender 战斗资产 16 项通过。
- 实际 Compatibility 窗口从车库按钮进入展厅、切换三车并返回，18 项通过；三张真实截图位于 docs/evidence/workspace-model-0.png 至 workspace-model-2.png，已目视检查。
- 完整命令、输出和退出码见 logs/workspace-consolidation。此次未重跑后期大规模对战帧率测试，不将展厅验证当成现代车战斗验收。
