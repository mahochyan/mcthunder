# WT-001-R2 设计页与验证记录（台账追平、构建身份、入口索引）

- 对应父项：WT-001；依赖：WT-001-R1（`208648ae`，PASS）
- 依据：`02_首轮10张执行单.md` §02；`03_全部42项目标工作单.md` WT-001 行 30-44；`06_直接发给执行模型.txt` 第 11 段

## 1. 现状（实测）

| 事实 | 证据 |
|---|---|
| 台账基线 `5f24ae6`(2026-09-12) 落后源码 `a1bac406` **20 提交** | `git rev-list --count 5f24ae65..a1bac406` |
| WT-032 台账 `planned`，但 4 提交 + 4 篇 WT032 文档 + 3 份 RESULTS.json 已实施 | `git log --name-only 5f24ae65..a1bac406`、`logs/WT032-*/RESULTS.json` |
| 显示版本停在 `1.0.0-rc.2`，而源码含 RC3 与 20 提交 | `project.godot:10` |
| 交付路径引用失效（工作区整理后迁入归档） | `README.md:58,127`、`NEXT_ACTION.md:127`；归档实测存在 |
| `docs/ARCHITECTURE.md` 为 004 版（覆盖到 008） | 文档标题与章节 |
| 无 CI；测试入口 131 checks + 9 demo + 18 player + 30 ps1 | 实测计数 |

## 2. 改动点（本单，全部在隔离分支）

| 类别 | 文件 | 改动 |
|---|---|---|
| 台账 | `docs/wt/EXECUTION_PLAN.json` | **仅 1 处状态更正**：WT-032 `planned→in_progress` + `status_note` + 该项目五列；其余字段原样 |
| 台账增量 | `docs/wt/continuation/EXECUTION_PLAN_ADDENDUM.json`（新） | 触及的 13 项五列 + 其余 29 项"源台账 + NOT_RUN"规则 + `completed_count=0` |
| 状态说明 | `docs/wt/continuation/LEDGER_DELTA.md`（新） | 20 提交→工作项映射、冲突登记、五列口径、本单不做 |
| 状态页 | `docs/wt/CURRENT_STATUS.md` | 顶部新增 WT-001-R2 增量登记节（保留全部历史节） |
| 基线 | `docs/wt/BASELINE.json` | 追加 `current_candidate` + `source_report_preserved`；源报告字段未改写 |
| 身份约定 | `docs/wt/continuation/BUILD_IDENTITY.md`（新） | 四层身份、显示点、历史包路径映射、回滚 |
| 身份实现 | `scripts/core/build_identity.gd`（新） | `VERSION/BUILD_ID/SOURCE_BASE_COMMIT/RELEASE_READY` + `describe()` |
| 身份显示 | `scripts/core/garage_shell.gd:74`、`scripts/ui/garage_frontend.gd:110` | 菜单与页脚改用 `BuildIdentity.describe()` |
| 版本串 | `project.godot:10` | `1.0.0-rc.2` → `1.0.0-rc.3-dev` |
| 架构索引 | `docs/wt/continuation/ARCHITECTURE_RESPONSIBILITY_INDEX.md`（新） | 22 模块责任 + 入口/场景 + 关键不变量 + 文档缺口 |
| 测试入口 | `docs/wt/continuation/TEST_ENTRY_LIST.md`（新） | 四层入口 + 门禁判读规则 + 未运行项 |
| 优先项 | `NEXT_ACTION.md` | 顶部新增"当前唯一优先项"块（单一项） |
| 验证入口 | `tests/run_build_identity_checks.gd`（新，headless）、`tests/run_build_identity_window.gd`（新，真实窗口） | 身份一致性与显示点接线 |

## 3. 兼容与迁移

- 台账为**追加式**：源字段全部保留，新增字段不破坏既有消费者（`EXECUTION_PLAN.json` 与 `GAP_REGISTER.json` 仍可被原脚本解析）。
- 旧 RC1/RC2 包身份不变，仅建立"旧路径 → 归档路径"映射，不搬运文件。
- `export_presets.cfg` **未改动**（改导出路径属构建/发布流程变更，超出授权）；`backups/*` 路径失效仅登记在文档。
- 版本串变更只影响显示与导出预设的产品版本字段（`export_presets.cfg` 内 `product_version` 未改，保持与历史包一致；若需同步另开单）。

## 4. 验证（本单实际执行）

### 4.1 headless 身份检查 —— `BUILD_IDENTITY_CHECKS_PASS`（8/8，exit 0）
```
[PASS] BuildIdentity.VERSION matches project.godot config/version (1.0.0-rc.3-dev)
[PASS] build id is the fixed continuation build id
[PASS] source base commit is a full 40-character SHA
[PASS] candidate never claims release_ready
[PASS] describe() carries version, build id, base SHA and the non-release state
[PASS] describe() is informative enough for the menu line
[PASS] menu identity wired into res://scripts/core/garage_shell.gd
[PASS] menu identity wired into res://scripts/ui/garage_frontend.gd
```
命令：`Godot_v4.7.2-stable_win64_console.exe --headless --path <cont> -s res://tests/run_build_identity_checks.gd`

### 4.2 真实窗口运行 —— `BUILD_IDENTITY_WINDOW_PASS`（6/6，exit 0）
```
[info] frames waited = 1
[PASS] running menu shows the build id
[PASS] menu line carries the display version
[PASS] menu line carries the source base SHA
[PASS] menu line declares a development candidate, not a release
[PASS] menu line never claims release readiness
[PASS] real-window menu screenshot saved to res://docs/evidence/WT-001-r2/menu_identity.png
```
命令：`Godot_v4.7.2-stable_win64_console.exe --path <cont> --resolution 1280x720 -s res://tests/run_build_identity_window.gd`
断言方式：在实际运行的应用场景树上遍历 `Label`，要求存在同时含 **build id / 版本 / 基线 SHA / "开发候选"** 且不含"发布就绪"的标签——**这是"主菜单显示开发候选身份"的可观测证据**。

### 4.3 图形证据的诚实边界
- 截图：`docs/evidence/WT-001-r2/menu_identity.png`（1280x720，156439 B）。
- **本模型不具备图像输入能力**，无法亲自目视；已登记为 `visual_review_by_agent = NOT_RUN`。
- 替代客观校验：运行期 UI 树文本断言（4.2）+ PNG 头直读尺寸 + 像素非空校验（见 `logs/WT-001-r2/` 记录）。
- 人工目视请由用户或具备图像能力的模型执行，本单不代签。

### 4.4 其他验证
- 5 份 JSON 全部可解析（`BASELINE` / `EXECUTION_PLAN` / `EXECUTION_PLAN_ADDENDUM` / `WORKSPACE_SNAPSHOT` / `dirty_file_ownership`）。
- 原 `main` 工作区未被本分支改动：`HEAD=a1bac406…`、porcelain 仍 379。
- 导入 `--import` exit 0，无 SCRIPT ERROR。

## 5. 未运行（如实）

| 项 | 状态 |
|---|---|
| 全量套件回归 | `NOT_RUN`（本单只整理入口，未重跑历史长测） |
| 性能/容量 | `HOLD_BY_USER` |
| 真人验收 | `NOT_RUN` |
| 云 CI | 未接入（仅定义本地门禁接口） |
| 截图人工目视 | `NOT_RUN`（本模型无图像输入） |

## 6. 回滚

本单 3 个提交（`81d848b9` 文档/身份、`1e098ca1` 验证入口与证据）可用 `git revert` 逐个回退；不影响引擎、导出预设或历史包。台账若需回到纯净源值，可用 `E:/AIprogram/mcthunder-archive/continuation-preserve-20260913/manifest/tracked_changes.patch` 与快照 tree 恢复。
