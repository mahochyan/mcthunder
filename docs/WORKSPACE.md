# 统一工作区 — 2026-09-11

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
