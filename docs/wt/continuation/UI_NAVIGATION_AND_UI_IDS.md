# UI 导航状态图与 ui_id 映射（WT-UI-003 / MCT-UI-FIELDWORK-01）

> 本文件交付 `WT-UI-003` 要求的三件：**导航状态图与 ui_id 映射** · **前端导航/模态最小补丁** · **正常输入回归及重复进入退出记录**。
> 所有证据来自**真实鼠标/键盘事件**在**可见控件**上的操作；`show_page()`、emit 信号与 `request_spawn()` **未**被当作玩家证据。
> 被测源码：`work/ui-fieldwork-01`（本轮提交见文末）；工具：`scripts/diagnostics/window_input_driver.gd`（点击前断言可见且未禁用，失败即停止该段）。

## 1. 导航状态图

```
                        ┌────────────────────────── GarageShell（常驻） ──────────────────────────┐
                        │  bg(ColorRect, 装饰·IGNORE)   GarageControlSource(旧容器·始终隐藏)      │
                        │  Frontend（由 GarageFrontend.compose 组装，garage.theme=GarageTheme）    │
                        └──────────────────────────────────────────────────────────────────────────┘
   ┌─ tab.battle ─┐   ┌─ tab.loadout ─┐   ┌─ tab.training ─┐        ┌─ nav.research ─┐   ┌─ nav.settings ─┐
   │ pages[0] 作战 │⇄ │ pages[1] 配装 │⇄ │ pages[2] 训练  │        │ VehicleResearch│   │ InputSettings  │
   └───────┬───────┘   └───────────────┘   └───────┬───────┘        │ Tree（模态）   │   │ Panel（模态）  │
           │ loadout.open → pages[1]              │ 各训练入口      └───────┬────────┘   └────────────────┘
           │ nav.quit → AppDialog（模态）          │                        │ Esc / 返回
           │ deploy → 出战请求 → 比赛场景          └────────────────────────┘ Frontend 恢复 + refresh()
```
- **三主区**：作战 / 车辆配装 / 训练中心（`pages[0..2]`，`tabs[0..2]`）✓ 与工单一致，**未新增**强制宣传首页 ✓
- **科技树**为**独立入口**（`garage.nav.research`），打开时**隐藏 Frontend**，关闭时 `Frontend.show()+refresh()` ✓
- **模态**：`ModalNavigation.attach()`（科技树 `vehicle_research_tree.gd:83`、确认弹窗 `app_dialog.gd:30`、`InputSettingsPanel`、`waiting_panel` 等）
- **焦点/输入**：模态内 Tab 循环；Esc 关最上层；关闭后**恢复来源控件焦点**；非顶层模态不处理按键（不穿透）

## 2. ui_id 映射（实现后真实存在的稳定标识）

附在**既有控件**上的元数据（`set_meta("ui_id", …)`），**不加节点、不加信号、不改行为**；验证器只按 id 查找，**不按显示文字、不按子节点序号**。

| ui_id | 现实体 | ui_id | 现实体 |
|---|---|---|---|
| `garage.deploy` | 主出战按钮（`frontend.deploy`） | `garage.preview.viewport` | 3D 载具视口（**保留自身拖拽输入**） |
| `garage.nav.research` | 科技树入口 | `garage.preview.inspect` / `.inspect_row` | 查看档案 / 外观·装甲·内构行 |
| `garage.nav.settings` / `.quit` | 设置 / 退出 | `garage.loadout.open` | 作战页"调整携弹与出战阵容" |
| `garage.tab.battle` / `.loadout` / `.training` | 三主区页签 | `garage.challenge.open` | 战术挑战 |
| `garage.card.<vehicle_id>` | 每辆车的卡片（实测 7 张） | `garage.training.river_team` / `.river_survey` / `.river_drive` | 训练中心河谷三项 |
| `garage.vehicle.title` / `.nation_role` / `.stats` | 车型标题 / 国家·类型 / 配置摘要 | `garage.training.start` / `.case` / `.shell` / `.rounds` | 自由靶场控件 |
| `garage.vehicle.picker` / `.dossier` | 车辆选择 / 档案 | `garage.preparation.mode` / `.map` / `.difficulty` | 对局规则 / 行动区域 / 对手难度 |
| `garage.deploy.result` / `garage.error` | 出战结果 / 错误文本 | — | — |

**自检实测**（`ui_navigation_verifier`）：必需 id **全部存在** ✓ · **无重复 id** ✓ · 车卡 id **7** 张 ✓。

## 3. 最小补丁（改动清单）

| 文件 | 改动 | 性质 |
|---|---|---|
| `scripts/ui/garage_frontend.gd` | 新增 `tag()` 助手 + `compose()` 末尾附 ui_id；`_decorative_rects()` 收集**前端内全部** `ColorRect` 并设 `MOUSE_FILTER_IGNORE`；`loadout_open`/`settings_button`/`quit_button` 改为具名局部变量（供打标，**行为不变**） | 元数据 + 装饰输入 |
| `scripts/core/garage_shell.gd` | 全屏背景 `bg`：改为令牌背景色 `background #10171B` 且 `MOUSE_FILTER_IGNORE` | 装饰输入 + 令牌 |
| `scripts/ui/vehicle_research_tree.gd` | **先 `ModalNavigation.attach()` 再隐藏 Frontend**（原顺序导致来源焦点丢失，Esc 无法恢复） | **行为修正** |
| `scripts/core/app_flow.gd` | 新增 `--verify-ui-navigation` 宿主分支（与既有 6 个 `--verify-*` 同模式） | 测试宿主 |
| `scripts/diagnostics/ui_navigation_verifier.gd` | 新增：真实输入导航/焦点/模态验证器 | 测试 |
| `scripts/ui/ui_tokens.gd` · `garage_theme.gd` · `core_ui.gd` | （WT-UI-002 已交）令牌化 | — |

**两条拒收条件均守住** ✓：**未**重新 `show()` 旧 `GarageControlSource` ✗ · **未**修改任何全局战斗按键 ✗

## 4. 正常输入回归与重复进入退出记录（实测）

命令：
```
Godot_v4.7.2-stable_win64_console.exe --path <repo> --resolution 1280x720 \
  -- --verify-ui-navigation --shot-dir logs/WT-UI-FIELDWORK-01/wt-ui-003
⇒ exit=0 ; === ui navigation: 39 checks, 0 failed === ; UI_NAVIGATION_CHECKS_PASS ; driver checks=17 driver failed=0
⇒ 实拍 6 张：nav_00_battle_page / nav_01_loadout_page / nav_02_training_page / nav_03_research_tree / nav_04_confirm_dialog / nav_05_after_deploy
```
覆盖（全部为真实输入）：
1. 初始态：page 0 · 另两页隐藏 · 旧容器仍隐藏
2. ui_id：必需 id 齐备 · 无重复 · 车卡 7 张
3. 隐藏页**不参与焦点**（可见可聚焦控件 25 项，落在隐藏页者 **0**）· 装饰矩形**不截取鼠标**（2 个可见矩形，越界 **0**）· 载具视口**保留**自身输入
4. **重复两轮**：点击 `tab.loadout` → `tab.training` → `tab.battle`（每轮 3 次断言全过）
5. `garage.loadout.open` 真实进入配装页并返回
6. 科技树：真实点击打开 → **Tab 焦点留在模态内** → **Esc 关闭** → Frontend 恢复 → **焦点回到 `garage.nav.research`**
7. 退出确认弹窗：真实点击打开 → **Esc 关闭** → **不真退出** → **焦点回到 `garage.nav.quit`**
8. 出战：`garage.deploy` 可见可用 → 真实点击 ⇒ **真实出战请求并进入比赛** → 返回后车库可用、所选车型保持（`player_tank`）

### 4.1 本轮定位并修掉的 4 处问题（含 2 处我自己的误判 ✗）
| # | 现象 | 真因 | 处置 |
|---|---|---|---|
| 1 | 装饰矩形 1 个仍截取鼠标 | 我只处理了已知的 `line`；`GaragePreparation` 移入的页内分隔件 + `GarageShell` 全屏背景未处理 | 改为**遍历全部** `ColorRect`；背景单独设 IGNORE |
| 2 | "点科技树未打开" | 我按**节点名** `VehicleResearchTree` 查找 ✗（实际名不同） | 改按 `frontend.research_tree` **引用**查（模态注册本来已 PASS） |
| 3 | Tab 未留在模态内 | #2 的连带（引用为 null） | 随 #2 修复 |
| 4 | **Esc 后焦点未恢复（null）** | **真缺陷** ✗：原代码**先隐藏 Frontend 再挂模态** ⇒ 隐藏即刻丢焦点 ⇒ 模态无从记录来源控件 | 改为**先 attach 再 hide**（1 行顺序修正） |

## 5. 复现方式（自证）

```
powershell -File tests/... （本轮无需专用脚本）
& <godot> --path <repo> --resolution 1280x720 -- --verify-ui-navigation --shot-dir <dir>
```
日志：`logs/WT-UI-FIELDWORK-01/wt-ui-003.log`（含 56 条 PASS、0 条 FAIL、`driver checks=17 driver failed=0`）。
