# UI_BASELINE.md — MCT-UI-FIELDWORK-01 / WT-UI-001

> 交付物：`WT-UI-001` 要求的"入口/绑定/风险表 + 当前基线截图及 source_sha"。
> 机器可读绑定表见同目录 `UI_BINDING_MAP.json`（只关联现有类，不复制业务逻辑）。
> 本文件只记录**现有/复用/需补**与风险，不做全仓审计，不表示任何设计已经实施。

## 1. 身份（开工核对，仅一次）

| 项 | 值 |
|---|---|
| 被测源码 | `source_sha = a005b681bc157f32cee2dc45959f072f856c2460` |
| UI 隔离分支 | `work/ui-fieldwork-01`（指向上述 SHA） |
| 开工时状态 | detached HEAD `a005b681`；已跟踪未提交 **0**；未跟踪用户文件原样保留（4 张 `concept_atlas_v1.png` + `live_fire_respawn.png`） |
| 基线关系 | `a1bac406` 仍存在，且是 `main`(c164511e) 与 HEAD 的共同祖先 ⇒ 原 main 未被改写 |
| **后继成果（保留，不切回、不重做）** | `fc177eb3..a005b681` 共 **13 提交**，全部为现代车/河谷/打包工作：`499dcde4` 现代车接地与已保存河谷工程局 · `9c4b69e8` 受阻河谷入口与让路 · `82f54838` 权威据点显示 · `7b8d1837` T-80 自动装填 · `2922587b` 按队分配现代车 · `7f89c941` 材料与弹架策略 · `a005b681` 包内现代车按声明队伍校验 |
| 设计输入 | `UI设计单_阅读版.html`（90351 B，已抽取为 `logs/WT-UI-FIELDWORK-01/design_spec_extract.md`，1867 行）· `03_ALL_WORK_ORDERS.md` · `06_NEXT_IMPLEMENTER_MESSAGE.txt` · 设计图 1 张 |
| **缺失输入（如实登记）** | `07_UI_TOKENS.json`、`08_VIEW_CONTRACTS.json`、`09_ACCEPTANCE_CASES.json`、`10_WORK_ORDERS.json` —— 设计单原文点名这四个"机器可读设计"，但**未随本次转交**；已在整个附件目录（966 文件、含无扩展名者）与两棵工作树内递归搜过，均不存在 |

## 2. 八类页面：现有 / 复用 / 需补

| 页面 | 规范节 | 现有入口（类:文件） | 复用（不改业务） | 需补（设计差距） |
|---|---|---|---|---|
| 作战车库 | S01 | `GarageShell` `scripts/core/garage_shell.gd`；呈现由 `GarageFrontend.compose` 组装 `scripts/ui/garage_frontend.gd:31` | `GaragePreparation` · `GarageService` · `MatchConfig` · `VehicleCatalog.packages` 准入结果 | 固定主操作区+禁用原因；车型状态**分列**（可战斗/需研发/仅外观/工程候选未在当前包提供/配置错误/加载中/切换中）；底部只显示**当前可用编成槽**+「更多车辆」入口 |
| 苏德科技树 | S02 | `VehicleResearchTree` `scripts/ui/vehicle_research_tree.gd`，入口 `frontend.tree_button` → `open_research_tree()` `:165` | 现有研发/拥有状态输出 | 五路线并排+路线标题常显；基础型卡 224×96（折叠改型数）；搜索与跳转保留筛选与滚动；**只有真实前置才画连线** |
| 车辆配装与检查 | S03 | `GaragePreparation.setup` `scripts/garage/garage_preparation.gd:24`（`pages[1]`） | `save_settings()` · `build_match()` · 弹架/首发规则 | 弹药卡显真实名称/工程性质/弹族/数量/首发标记；统计未知显示「未提供」而非 0；「应用配装」仅在服务确认后报成功 |
| 战斗 HUD 与炮镜 | S04 | `BattleUI.setup` `scripts/ui/battle_ui.gd:12`；`BattleHUD._build` `scripts/ui/battle_hud.gd:105` | `match_info()` · `roster()` · `BattleIntel`/观察权限层 | 顶中票数/真实剩余时间/据点归属；左下本车与失能；下中**膛内弹/装填/库存/下一弹语义分开**；右下小地图**只读 BattleIntel**；**中心 x25–75%、y20–70% 无实底常驻面板** |
| 战损与即时反馈 | S05 | 同上 HUD 实例 | 真实能力输出（失能原因） | 中央最多一条关键提示、次级入角落队列、重复合并；命中反馈区分未穿/穿透/部件损伤/击毁；**按键名读实时绑定**（不写死 T/F/C） |
| 阵亡/观战/再出击 | S06 | `TeamRange._on_lost` 显示 `waiting_panel` `scripts/battle/team_range.gd:430`；业务入口 `request_respawn()` `:451`；真实控件 `battle.respawn_button` | `director.state.roster.A.respawn_at` · `spectator` · `abandon_vehicle()` | 等待/可请求/阻塞/观战**四态**；保护期·资源不足·无车·出生位堵塞**各自原因**；**只经真实点击或已绑定按键进入业务入口**；新生命刷新且旧残骸不复用 HUD/装填 Tween |
| 结算与下一局 | S07 | `AppFlow.result_overlay` `scripts/core/app_flow.gd:6`；`return_to_garage(result)` `:224`；`_settle_match` `:250` | `pending_reward` · `last_result` · 回放入口权限 | 标题不盖明细；只显真实字段；保存中/已保存/写入失败分开；重复开面板或回放**不得再次发奖** |
| 训练/挑战/设置/弹窗 | S08 | `pages[2]` + `garage._open_challenges()` `garage_shell.gd:37` + `InputSettingsPanel` `scripts/ui/input_settings_panel.gd` + `AppDialog` `scripts/ui/app_dialog.gd` | 当前键位 · 100%/125% 字号 · 高对比 · 减少闪烁 · 稳定镜头 | 课目卡（标题/目标/车型配弹限制/完成/进入）；挑战卡只显真实最佳成绩；设置四分组且**不支持项禁用并说明**；确认弹窗统一且**危险操作不默认聚焦确认** |
| 加载/空态/错误 | S09 | 跨页：`garage.error_label`；`app._transitioning`；`AppDialog` | 现有错误文本与准入原因 | 有真实进度才显示百分比（**禁止假 99%**）；缺模型显名与明确缺失态；错误先短说明、详情可展开；失败后回可操作入口、不留遮罩与鼠标捕获错误 |

## 3. 中文 / 字号 / 视口 现状（实测）

| 项 | 现状 |
|---|---|
| 中文字体 | `CoreUI.FONT = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")`（`scripts/core/core_ui.gd:3`）—— 与设计单要求"复用 `CoreUI.FONT`/现有主题引用、不新增字体依赖"**一致**，无需换字体 |
| 中文来源 | `LocalizationService.text(...)`（例：`menu_quit`、`ui_c7f1c6ac5352` 等词条键）；设计单要求继续走词条系统 |
| 现有字号 | 车库标题 36、区块标题 25、eyebrow 12、正文 14/13、页脚 11（`GarageFrontend.compose`）；HUD 默认 16（`battle_hud.gd:68`）；对决结算 18/23/32；`GarageTheme.text` 默认 14 |
| 主题载体 | `GarageTheme`（`scripts/ui/garage_theme.gd`，44 行）= **WT-UI-002 的扩展目标**；`GarageShell.theme = GarageTheme.theme()`（`garage_frontend.gd:40`） |
| 现有色值（内联） | `GarageTheme.ACCENT/MUTED`；`compose` 内联 `#30382f`（选中）、`#171f24`、`#303a3e`、`#344045`；3D 舞台 `#182126/#9aa9b1/#11191d/#7e7559/#121b20/#29363c/#788988` |
| 视口 | 窗口 1280×720、可调整（`project.godot`）；`DisplaySettings.apply_startup()`（`app_flow.gd:132`，隔离/headless 下跳过） |
| **无 `ui_id` 约定** | `grep ui_id` 于 `scripts/`+`tests/` = **0 命中** ⇒ WT-UI-001「稳定引用或 ui_id 清单」与 WT-UI-003「稳定 ui_id 与焦点」属**新建**；提案见 `UI_BINDING_MAP.json` |

## 4. 基线截图（**真实抓帧，非伪造**）

命令（窗口化运行，真实渲染后 `get_image().save_png`）：

```
Godot_v4.7.2-stable_win64_console.exe --path <repo> --resolution 1280x720 \
  -- --verify-modern-garage --shot-dir logs/WT-UI-FIELDWORK-01/baseline/garage-720p
```

| 结果 | 值 |
|---|---|
| 退出码 | **0** |
| 检查 | **37 项 · 0 失败** · `MODERN_GARAGE_CHECKS_PASS` |
| 抓帧 | `ussr_t_80b_garage.png`(172629 B) · `germ_leopard_2a4_garage.png`(179052 B) · `ussr_t_80b_river.png`(269438 B) · `germ_leopard_2a4_river.png`(272706 B) |
| 日志 | `logs/WT-UI-FIELDWORK-01/baseline/garage-720p.log` |
| 设施出处 | `scripts/diagnostics/modern_garage_verifier.gd`（真实鼠标 `activate()` 且断言可见/未禁用；`capture()` 走 `RenderingServer.frame_post_draw`） |

**由截图读出的基线事实**：
- 车库（S01）：顶栏 品牌+`科技树/作战/车辆配装/训练中心`+`设置/退出`；左栏 `01 / DEPLOYMENT`→`准备出战`→对局规则/行动区域下拉+地图说明→**暖金全宽主按钮「现代河谷 · 内部测试 →」**；主区 车型名 `T-80B`、副标 `苏联 · 现代工程车`、右上 `125.0 mm 主炮 / 38 发携弹上限`、3D 载具 + 底部 `转左 / 查看: 外观 → 装甲 → 内构 / 转右`；底部 `车库 / VEHICLE COLLECTION` + `模型展厅 / 制作与许可` + **7 张车型卡**（选中带金边）；页脚按键提示与构建身份。
- 战斗 HUD（S04）：左上 `据点争夺 · A/B/C`+`3秒后开始交战`；顶中 `△友方 300 ◆敌方 300`；右上 `10:00`；A/B/C 三条 `中立 0%`；左下 `乘员 3/3`+`动力正常`；下中 `可开火 · 0 km/h`+`125mm 工程 HEAT（项目设计初值）· 6 发 | 膛内 1`+`下次: … 1/2 切换 · M 下一弹种`+装填条+按键提示行；右下小地图 `河谷枢纽 · 4v4 ↑北` 与图例 `△自己/友军 ◆目击敌人 ◇? 最后位置（最多6秒）`；底部操作提示行。
- 方向已对：**深灰底 + 暖金主操作 + 中文可读**（与设计方向一致）；差距集中在 §2「需补」列（状态分列、中心留白、语义分开、真实原因文本等）与色值/字级的**统一令牌化**。

## 5. 风险表（本单登记，不擅自处理）

| # | 风险 | 依据 | 处理 |
|---|---|---|---|
| R1 | **四个机器可读设计文件缺席**（07/08/09/10） | 设计单原文点名；附件与两树递归搜索无命中 | 已列 §1；`WT-UI-002` 需要 `07_UI_TOKENS.json` ⇒ 需你补发，或授权我按阅读版逐字转录（派生件、头部标注来源） |
| R2 | **色值冲突**：设计图色条 `#0F1419/#1C2A38/#E63946/#D4AF37/#3A7BD5/#2ECC71` vs 规范表格 `background #10171B … accent #E0B46A …` | 图 vs `UI设计单_阅读版.html` §"2. 颜色令牌" | 拟**以规范表格为准**（正文令牌章节）；需你确认 |
| R3 | 共享文件并发 | 设计单 §"UI 线可与通行/打包并行，但不得覆盖它们的未提交内容；共享 `battle_ui.gd`、`garage_frontend.gd` 由集成负责人安排顺序" | UI 在隔离分支 `work/ui-fieldwork-01`；13 个后继提交已确认属通行/打包线，不合并、不覆盖 |
| R4 | 旧界面重现 | `GarageFrontend.compose()` 隐藏 `GarageControlSource`（`:34`、`:39`）并把既有控件 reparent 进新页 | 后续所有 UI 改动**不得** `show()` 旧容器或恢复旧布局 |
| R5 | 无货币/段位系统 | `grep` 未见金币/等级/战力分服务 | 按 S01 禁区：**不显示**金银币、等级、战力分；人数按真实模式配置，**不把 16 泊位写成已支持 16v16**（当前左栏文案已写"10v10 / 16v16 尚待验证"，保留该诚实措辞） |
| R6 | 文案硬编码数字 | 设计单要求"数量动态读取，不在文案硬编码" | 现有 `short_names` 硬编码 7 个车型简称（`garage_frontend.gd:18/33`）⇒ 记为需替换为元数据读取 |

## 6. NOT_RUN（点名缺失，不用概念图冒充）

| 项 | 原因 | 计划 |
|---|---|---|
| HUD **受损态**基线截图 | 现有验证器不产生受损画面；需专项夹具（可复用 `check_live_fire_respawn.gd` 的真实战斗链） | 在 S05 单（WT-UI-007/008）补 |
| 配装页（`pages[1]`）基线截图 | 现有验证器聚焦现代车车库与河谷，未抓配装页 | WT-UI-001 后续补抓（真实切页后抓帧） |
| 结算/结果基线截图 | 需走完一局到 `return_to_garage(result)` | S07 单（WT-UI-010）补 |
| 1080p 与 125% 字号基线 | 首批交付要求含 720p/1080p×100%/125% | 在 WT-UI-004 完成证据中一并产出 |
| 真人体验 | 本轮 `release_ready=false`，真人不代签 | 保持 PENDING |
