# WT-001-R1 设计页（保全本地候选与未提交成果）

- 对应父项：WT-001（本地主线保全、状态追平与可复现候选）
- 依赖：无；基线 `main @ a1bac406d2bc12b32c7f7d130590f1c1a17907c9`（2026-09-13 01:32 +0800）
- 依据材料：`02_首轮10张执行单.md` §01、`06_直接发给执行模型.txt` 第 3/9 段、`03_全部42项目标工作单.md` WT-001（行 27-49）

## 1. 现状（实测）

| 事实 | 证据 |
|---|---|
| HEAD=`a1bac406d2bc12b32c7f7d130590f1c1a17907c9`，分支 `main` | `git rev-parse HEAD` / `--abbrev-ref HEAD` |
| 已跟踪修改 6、已跟踪删除 0、未跟踪目录级 373、暂存 0 | `git status --porcelain` |
| 未跟踪文件级展开约 3.6 万项（目录级 373 是折叠计数） | `git ls-files --others --exclude-standard` |
| 6 个修改属同一条工作流：M1A1 15k 重制 + 展厅外观试驾 | `git diff --stat HEAD`：`m1a1.glb` Bin 3869232→7866852；`MODERN_ASSETS.json` status/条目更新；`write_modern_asset_manifest.py` +4-1；`SOURCE_NOTES.md` +2；`MODELING_STANDARD.md` +4；`model_showroom.gd` +32 |
| 仓库体积：`.git` 2755 MB、`logs/` 130 MB；磁盘余 464.7 GB | 实测 |
| 外部依赖：引擎 `tools/godot/Godot_v4.7.2-stable_win64_console.exe`（175 MB 级，工程内）；`E:/AIprogram/tank_data/cache`、`E:/AIprogram/aimodel` 为外部只读来源 | BASELINE.json、NEXT_ACTION.md |

## 2. 目标

1. 取得**可恢复、可辨别来源**的当前候选，任何现存源文件与二进制在接续中不被覆盖。
2. Git 历史、二进制改动、未跟踪源文件**分别保全**并各自有哈希清单。
3. 原工作区**除获授权改动外保持不变**：不 `git add .`、不 stash/reset/clean/checkout、不丢文件。

## 3. 接口与数据结构（本单新增产物）

| 产物 | 位置 | 结构 |
|---|---|---|
| 冻结工作树副本 | `E:/AIprogram/mcthunder-archive/continuation-preserve-20260913/tree/` | 完整目录镜像（排除 `.git`/`.godot`/`.tmp-edge*`） |
| Git 历史备份 | 同根 `mcthunder-all-refs.bundle` | `git bundle --all` + `bundle verify` |
| 恢复验证记录 | 同根 `restore_check.txt` | 6 修改逐项 src/snap 哈希比对 + 未跟踪抽样 300 项 + 源目录事后未变 |
| 清单目录 | 同根 `manifest/` | `git_refs.txt`、`HEAD.txt`、`status_porcelain.txt`、`index_ls_files_s.txt`、`tracked_changes.patch`（含二进制）、`tracked_changes_stat.txt`、`untracked_list.txt`、`modified_hashes.json`、`untracked_hashes.json`、`untracked_rollup.json`、`tool_identity.json`、`log_200.txt` |
| 工单清单（入库） | 隔离工作树 `docs/wt/continuation/` | `WT-001-R1_DESIGN.md`（本页）、`WORKSPACE_SNAPSHOT.json`、`dirty_file_ownership.json`、`WORKSPACE_RESTORE_CHECK.md` |
| 隔离续作环境 | `E:/AIprogram/mcthunder-cont`（分支 `work/continuation-20260913`） | 从 `a1bac406` 干净检出，`git status` 为空 |

**保全脚本**：`E:/AIprogram/mcthunder-archive/continuation-preserve-20260913/preserve.ps1`（纯增量：只读源仓库 + 只写快照根目录，绝不写源目录）。

## 4. 改动路径

- 不改任何游戏源码、配置或文档。
- 新增：快照根目录（归档区，仓库外）、隔离工作树目录、`docs/wt/continuation/*`（在隔离工作树内小步提交）。
- 隔离工作树中**不并入** M1A1 脏二进制与其 showroom 修改（按 `02` §03“M1A1 脏二进制不默认加入”与 `06` 第 9 段“未知来源的 M1A1 资产与 showroom 修改保持隔离”），仅登记来源与哈希。

## 5. 正反测试

| 类型 | 用例 | 期望 |
|---|---|---|
| 正 | 在新临时目录恢复快照后比对 HEAD 与 6 个修改文件哈希 | 全部 MATCH |
| 正 | 未跟踪文件随机抽样 300 项比对哈希 | 全部 MATCH |
| 正 | `git bundle verify` | 历史完整可校验 |
| 正 | 保全后重算源目录 6 文件哈希 + `status --porcelain` 计数 | 哈希 UNCHANGED、计数仍 6/373、HEAD 不变 |
| 反 | 快照缺失/哈希不符 | 记为 FAIL 并暂停该写路径，不写 PASS |
| 反 | 外部资源（引擎/模板/外部只读来源）缺失 | 单列缺失项，不视为快照失败但不得写 PASS |

## 6. 验收标准（对 03 WT-001 行 40-44）

- 新临时目录恢复后 HEAD、二进制与未跟踪源文件哈希与清单一致；缺外部资源单列。
- 原工作区未变；无批量 add、无 reset/clean、无丢失文件。
- 未跟踪项按 **源文件 / 素材 / 证据 / 临时文件** 四类归档（`untracked_rollup.json` + 分类说明）。

## 7. 明确不做

不推送、不改 remote、不做 LFS/历史瘦身、不删除归档或 `.tmp-edge*`、不合并三个未合并分支、不整理 15.3 GB 归档、不跑性能采样（HOLD_BY_USER）、不代签真人验收。

## 8. 回滚

本单只新增文件与一个隔离分支/工作树，回滚 = 删除 `continuation-preserve-20260913` 目录、`git worktree remove E:/AIprogram/mcthunder-cont`、`git branch -D work/continuation-20260913`；源仓库无需回滚（未被改动）。
