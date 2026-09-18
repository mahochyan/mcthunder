# UI-BIZ-01 · 阶段 0 现状清单与基线（只读勘察 + 运行一次 + 基线抓帧）

- 工作树：`E:\AIprogram\mcthunder-ui-biz`（独立 git 工作树，**未触碰** `E:\AIprogram\mcthunder`(main) 与 `E:\AIprogram\mcthunder-cont`(另一条线)）
- 本阶段分支：`work/ui-biz-01`（从 `work/ui-fieldwork-01` @ `16065fec` 新建）
- 回退基线：**`work/ui-fieldwork-01` @ `16065fec`（本地=远端，已推送 ✓）= 未改造的原始 UI** ✓
- 勘察方式：只读（`git ls-files/ls-tree/rev-parse`、`Get-ChildItem/Test-Path`、文件读取）；改动仅限本工作树内新增的基线产物与本文档

## 1. 技术栈与框架（文件事实）

| 项 | 值 | 出处 |
|---|---|---|
| 引擎/语言 | Godot 4.7.2-stable 普通版（非 .NET）+ GDScript | `README.md` L13；`project.godot` L12 `"GL Compatibility"` |
| 工程名/版本 | `PixelArmor` / `1.0.0-rc.3-dev` | `project.godot` L9、L10 |
| 主场景 | `res://scenes/app.tscn` | `project.godot` L11 |
| 视口 | 1280×720，可缩放 | `project.godot` L17-19 |
| 依赖清单 | **不存在任何语言包管理器清单**（`package.json`/`requirements.txt`/`pyproject.toml`/`pubspec.yaml`/`vcpkg.json`/`conanfile.txt`/`CMakeLists.txt` 两个树内均 False） | 实测 | 
| 唯一外部依赖 | 引擎本体（`tools/godot/`，已用**硬链接**接入本树 ✓） | `START_GAME.bat` L6-14 |

## 2. 构建与启动命令（原始出处）

| 用途 | 命令 | 出处 |
|---|---|---|
| 启动（正式入口） | 双击 `START_GAME.bat` | `README.md` L13；`开始试玩.txt` L3/L12；`PLAY_BASELINE.md` L6 |
| 该脚本内部真正执行 | `"%GODOT_EXE%" --path "%PROJECT_DIR%." %*` | `START_GAME.bat` L20（首次自动导入 L16-18） |
| 单套自检 | `tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/run_armor_checks.gd` | `README.md` L46 |
| 图形+输入演示 | 同引擎 `--path . --resolution 1280x720 --max-fps 60 -s res://tests/run_armor_demo.gd` | `README.md` L48 |
| 全套回归 | `pwsh -File tests/run_suite_checks.ps1 -Order 024 -TimeoutSeconds 600` | `README.md` L43 |
| 导出可玩包 | `tests/build_release.ps1 -Candidate -ModernRiver`（预设 `Windows Release`） | 脚本 L1-6；`export_presets.cfg` L46-47 |

## 3. 本次"跑起来一次"的实测（1280×720，真实窗口）

| 步骤 | 命令（要点） | 退出码 | 结果标记 | 日志 |
|---|---|---|---|---|
| 导入 | `--headless --path <树> --editor --import` | **0** | `SCRIPT ERROR=0` | `logs/UI-BIZ-01/baseline/00_import.log` |
| 导航/布局/S06-S08 抓帧 | `--path <树> --resolution 1280x720 -- --verify-ui-navigation --shot-dir <相对路径>` | **0** | `UI_NAVIGATION_CHECKS_PASS` | `…/01_nav.log` |
| HUD/炮镜抓帧 | `… -- --verify-ui-hud --shot-dir <相对路径>` | **0** | `UI_HUD_CHECKS_PASS` | `…/02_hud.log` |
| 车库四分辨率抓帧 | `… -s res://tests/run_garage_frontend_checks.gd -- --shot-dir <相对路径>` | **0** | `GARAGE_FRONTEND_CHECKS_PASS` | `…/03_four.log` |
| 组件实验场抓帧 | `… -s res://tests/run_ui_component_playground.gd` | **0** | `UI_PLAYGROUND_PASS` | `…/04_playground.log` |
| 官方 autoshot（靶场/HUD 13 步） | `… -- --autoshot --shot-dir logs/UI-BIZ-01/baseline/autoshot` | **0** | `[autoshot] done: shots_saved=13 errors=0` | `…/05_autoshot.log` |

**一次我自己的传参错误（已修正、如实记录）** ✗：首次给 `--shot-dir` 传了**绝对路径**，`scripts/main.gd`（L46 默认 `"docs"`、L63 赋值、L1099-1100 拼接保存）按**工程内相对路径**处理，于是路径被拼成 `E:/…/mcthunder-ui-biz/E:\…` ⇒ 13 张全部保存失败、exit=1。改用相对路径后 **13/13 成功、exit=0** ✓。

## 4. 基线截图（回退基线，46 张真实窗口抓帧）

| 目录 | 张数 | 覆盖 |
|---|---|---|
| `logs/UI-BIZ-01/baseline/nav` | **16** | 车库/作战页、配装页、训练中心、科技树（紧凑/宽屏）、确认弹窗、真实出战、配装三类组、零弹架错误态、结算卡、挑战卡、训练课目卡、搜索空态、2560×1440、3440×1440 |
| `logs/UI-BIZ-01/baseline/hud` | **5** | HUD 正常（紧凑）、炮镜、宽屏、提示队列、125% 字号 |
| `logs/UI-BIZ-01/baseline/four` | **8** | 车库 1280×720 / 1920×1080 × 100% / 125% + 720 车辆页/装备页/训练页 |
| `logs/UI-BIZ-01/baseline/autoshot` | **13** | 靶场与战斗：第三人称、炮镜、移动后、暂停、恢复、双车、炮镜见 B、课目完成/重试、HUD 等 |
| `logs/WT-UI-FIELDWORK-01/wt-ui-002-playground` | **4** | 组件七态（normal/hover/pressed/focused/disabled/busy/error）+ 真实组件（见阶段 1/2 复用） |

## 5. UI 代码与资源清单（阶段 3 的改造对象）

- **界面脚本** `scripts/ui/`：24 个 `.gd`（+22 `.uid`）
  `ui_tokens.gd` · `garage_theme.gd` · `garage_frontend.gd` · `app_dialog.gd` · `battle_hud.gd` · `hud_presenter.gd` · `minimap_presenter.gd` · `modal_navigation.gd` · `input_focus_router.gd` · `input_settings_panel.gd` · `input_binding_service.gd` · `accessibility_settings.gd` · `display_settings.gd` · `localization_service.gd` · `battle_ui.gd` · `battle_intel.gd` · `sight_graduations.gd` · `vehicle_research_tree.gd` · `research_model_view.gd` · `research_trial_drive.gd` · `river_junction_atlas.gd` · `river_junction_survey.gd` · `river_objective_hud.gd` · `vehicle_display_metadata.gd`
- **宿主与流程** `scripts/core/`：34 个文件（含 `core_ui.gd` 组件工厂、`app_flow.gd`、`garage_shell.gd`、`garage_preparation.gd`）
- **设计令牌**：`configs/ui/ui_tokens.json`（1 个，原件；运行时读取者 `scripts/ui/ui_tokens.gd`）
- **图标**：`assets/ui/icons/` 19 个文件（17 SVG + `ICON_MANIFEST.json` + `generate_icons.ps1`）
- **字体**：`assets/fonts/NotoSansCJKsc-Regular.otf`（15.7 MB）+ `OFL.txt`（SIL Open Font License ✓ 授权明确 ✓）
- **场景**：`scenes/app.tscn`（主场景）· `scenes/main.tscn`（靶场）· `scenes/tank.tscn`

## 6. 阶段 3 逐屏改造清单（来自第 4 节基线，共 ~34 屏/状态）

车库与作战页 · 车辆配装页（三类组）· 训练中心页 · 科技树（紧凑/宽屏/空态）· 确认危险弹窗 · 真实出战过渡 · 零弹架错误态 · 结算卡 · 挑战卡 · 训练课目卡 · 超宽屏（2560/3440）· HUD 正常/炮镜/宽屏/提示队列/125% · 靶场 13 个状态（第三人称/炮镜/移动/暂停/恢复/双车/命中/课目完成/重试/HUD）

## 7. 未确认 / 卡点（不猜）

1. **`--autoshot` 只接受工程内相对路径**（本次实测结论；绝对路径会拼错）——不是缺陷，但写进了本文档以免再犯。
2. 本树 `START_GAME.bat` 依赖 `tools/godot` 的两枚 exe（已用硬链接补齐 ✓，不占额外空间）；若要在这条线上导出，仍需 `%APPDATA%\Godot\export_templates\4.7.2.stable\`（**实测已存在** ✓ `windows_release_x86_64.exe` 104.2 MB）。
3. 阶段 1 需要的**外部素材**（图标/字体/纹理）尚未下载，授权需逐个到来源页核实并登记——**未登记前不使用**。
