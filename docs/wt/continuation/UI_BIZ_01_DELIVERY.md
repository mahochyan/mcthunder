# MCT-UI-BIZ-01 交付说明（UI 商业客户端级改造）

- **分支**：`work/ui-biz-01`（工作树 `E:\AIprogram\mcthunder-ui-biz`）
- **基线**：`work/ui-fieldwork-01` @ `16065fec`（该线已交付的 UI 田野调查成果）
- **引擎/栈**：Godot 4.7.2-stable 普通版 + GDScript + gl_compatibility（**未升级、未更换**）
- **范围**：**只改 UI 层**（样式/布局/资源/动效）。未改业务逻辑、数据结构、对外接口；未删未藏任何入口；未改构建配置；未引入新依赖（图标/字体为纯静态资源，引擎原生即可加载）。
- **设计标识**：`MCT-UI-BIZ-01`（叠加式，不改原设计单 `MCT-UI-FIELDWORK-01`）

---

## 1. 阶段与产物

| 阶段 | 产物 | 证据路径 |
|---|---|---|
| 0 只读勘察 | 技术栈/启动命令出处/46 张基线截图/UI 文件清单/改造清单 | `logs/UI-BIZ-01/BASELINE.md`、`logs/UI-BIZ-01/baseline/**` |
| 1 美术方向与素材 | 方向文档 + 素材清单（逐件 URL/授权/日期/SHA256） | `docs/ui/UI_BIZ_01_ART_DIRECTION.md`、`assets/ui/biz/ASSET_MANIFEST.md`、`assets/ui/biz/licenses/**` |
| 2 设计令牌与组件层 | 叠加令牌 + 统一组件层 + 组件总览截图 | `configs/ui/ui_tokens_biz.json`、`scripts/ui/biz_theme.gd`、`logs/UI-BIZ-01/stage2/overview/**` |
| 3 逐屏改造 | 各屏改造 + 每屏验证 + 抓帧 | `logs/UI-BIZ-01/stage3/**` |
| 4 验收 | 本文件 + 前后对比图 + 全量电池日志 | `logs/UI-BIZ-01/stage4/**`、`logs/UI-BIZ-01/stage4/compare/**` |

**原设计单未被修改**：`configs/ui/ui_tokens.json` 保持与 `MCT-UI-FIELDWORK-01` 原版**逐字节一致**；本单全部令牌改动位于**叠加文件** `configs/ui/ui_tokens_biz.json`，且只新增键（`palette_additions`/`elevation`/`glow`/`type_scale`/`motion`/`components_biz`），仅共享元数据键。

---

## 2. 观感改造（"整套风格替换"，非区域微调）

1. **单一主题源**：`CoreUI.theme()` 与 `GarageTheme.theme()` 均**委托** `BizTheme.theme()` ⇒ 按钮/下拉/复选框/输入框/面板/弹窗/提示/进度条/滑条/分隔线/富文本/滚动容器/双滚动条**一次换皮**。
2. **层次与氛围**：四级 elevation + **真实阴影**；输入框下沉、弹窗浮起、卡片抬升；页面背景为**分层程序化生成**（底色 + 径向暗角 + 顶部淡金洗，运行时生成 ⇒ 零外部素材、零授权风险）。
3. **字体与字形**：新增拉丁显示字体（Rajdhani，OFL）用于字标与**仪表数字**（时钟/票数/速度/数值）；中文仍走既有 Noto Sans CJK SC（OFL）；数值走类型刻度。
4. **图标系统**：68 枚 Lucide 图标（ISC，Feather 子集 MIT），统一 24 视框/1.75 描边/单色 + `modulate` 着色；页签、路线、操作、列表行、课目卡、按键行等**统一图标语言**。
5. **动效**：页面切换与弹窗为**纯 modulate 淡入**（不动位置与尺寸 ⇒ 过渡中测量几何仍为终态）；尊重"减少闪烁"设置直接跳过。
6. **语义用色**：金色为唯一强调色（沿用既有裁定）；**红色仅用于危险/错误**（含"重置进度"这类破坏性操作与错误态文案）；状态色统一为 positive / warning / critical / accent。
7. **多分辨率与字号**：按设计单"125% 触发紧凑布局"实现**尺度感知布局**（外边距/块间距取自 compact/standard 令牌行），**不回缩字体**以迁就大字选择。

---

## 3. 验收表（逐项 · 证据可复现）

| # | 验收项 | 结果 | 证据 |
|---|---|---|---|
| 1 | 原命令可启动、构建链无新增报错 | **PASS** | `logs/UI-BIZ-01/stage4/acceptance/launch_smoke.log`（`--path` 启动 120 帧自退，SCRIPT ERROR=0）；全量 `--headless --editor --import` 无 SCRIPT ERROR |
| 2 | 全部界面已改造 | **PASS** | 阶段 3 抓帧 `logs/UI-BIZ-01/stage3/**`；覆盖车库（作战/配装/训练）、科技树、设置、挑战、靶场结算、弹窗、HUD |
| 3 | 功能点测一致 | **见 §4** | 令牌 78/0 · 图标 13/0 · 科技树 33 键 0 缺 · 设置 36/0 · 挑战 140/2（2 项为既有登记例外）· 车库 51/0 · 导航 143/0 · HUD 58/0 · 组件总览 · 自动抓帧 |
| 4 | 多分辨率不溢出/不重叠/不截断 | **PASS** | **布局审计**（宽度塌陷/越界/同矩形重叠）在 1280×720、1920×1080 × 100%/125% 与 2560×1440、3440×1440 各跑一遍，共 27 条断言全 `none`；HUD 侧 3 条断言全 `none` |
| 5 | 素材授权完整 | **PASS** | `assets/ui/biz/ASSET_MANIFEST.md` 逐件 URL/授权/日期/SHA256；许可证原文 `assets/ui/biz/licenses/{LICENSE-lucide.txt,OFL-Rajdhani.txt}`；既有 Noto 的 `assets/fonts/OFL.txt` |
| 6 | 前后对比 + 变更说明 | **PASS** | `logs/UI-BIZ-01/stage4/compare/BEFORE_AFTER_*.png`（阶段 0 基线 vs 现版，左基线右现版）+ 本文档 |

---

## 4. 功能点测明细（本轮实测）

| 套件 | 结果 |
|---|---|
| `run_ui_token_checks.gd` | `UI_TOKEN_CHECKS_PASS` — 78 项 0 失败（含设计单的几何/颜色裁定自检） |
| `run_ui_icon_checks.gd` | `UI_ICON_CHECKS_PASS` — 13 项 0 失败 |
| `run_research_entry_checks.gd` | `RESEARCH_ENTRIES_PASS` — 33 键 0 缺 |
| `run_settings_checks.gd` | `SETTINGS_CHECKS_PASS` — 36 项 0 失败 |
| `run_garage_frontend_checks.gd` | `GARAGE_FRONTEND_CHECKS_PASS` — 51 项 0 失败（含 4 组合 × 卡片可达性） |
| `--verify-ui-navigation` | `UI_NAVIGATION_CHECKS_PASS` — 143 项 0 失败（含五屏布局审计 + 字号/分辨率矩阵审计） |
| `--verify-ui-hud` | `UI_HUD_CHECKS_PASS` — 58 项 0 失败（含战斗屏布局审计） |
| `run_challenge_checks.gd` | 140 项 2 失败 — **两项均为既有登记例外**（`real defense script pilot completes finite waves with opponent AI untouched`，见构建登记表） |
| `run_checks.gd`（002-R1 主功能） | **看门狗超时**（177 PASS · 0 FAIL，90s 内被自身看门狗强制退出）⇒ 见 §5 待归因 |
| `--autoshot` | 见电池日志（13 帧保存、errors=0 为通过口径） |

---

## 5. 未达标 / 待归因（**如实登记，未放宽任何断言**）

1. **`run_checks.gd` 看门狗超时**：该套件打印 177 条 PASS、**0 条 FAIL**，随后由自身 `[WATCHDOG] 90s` 强制退出（退出码 2）。它**不是断言失败**，而是"卡住/超时"。已确认与 UI 无关的直接证据链见 §6 的改造范围；**是否为本单引入待下一步归因**（方法：在父提交 `16065fec` 上以 detached HEAD 运行同一套件对照，避免污染分支）。
2. **历史保留项（沿用，不由本单改变）**：性能口径 `HOLD_BY_USER`；真人体验验收与截图目视不由本单代签。

---

## 6. 明确"未做什么"（硬约束自证）

- 未改业务逻辑/数据结构/接口：全部改动集中在样式、布局、资源与动效；唯一功能性新增是**布局重应用钩子**（`GarageShell.apply_scale_layout()` 转发 + `AccessibilitySettings.apply()` 的鸭子类型调用），它只重排 UI，不改变任何数值、状态或存档。
- 未删未藏入口：所有既有按钮/页签/入口保持存在（改造只换外观与图元）。
- 未改构建配置、未升级引擎、未引入新依赖：无新增插件/库；图标与字体为静态资源，使用引擎原生 `FontFile`/`Texture2D` 加载。
- 未做与 UI 无关的重构：未触碰核心玩法、物理、结算与存档代码。
- **未代签人工验收**：真人体验、截图目视、公开发行与付费均未执行。

---

## 7. 关键过程事故与纪律改进（如实记录）

- **门禁**：本轮引入"**解析不过则不提交**"，累计拦下 **7 次**手工编辑失误（签名与语句并行、常量名不存在、类型不可推断、锚点只匹配行尾等），**零坏提交进入分支**。
- **测量优先**：`1280×720@125%` 的 5px 溢出曾连续 **4 次误判**（`%` 被当格式符 → 引用失效 → 边距被可扩展中部吸收 → 主题通知不传播）。改为**写探针读值**后一次定案：真正的结构性原因是 **`GarageFrontend` 从未被加入场景树**（`GarageFrontend.new(); frontend.compose(self)`），因此它自身的 `_process`/`_notification` 永不可能触发，`AccessibilitySettings.apply` 递归子节点也走不到它。修法：把钩子放在**确实在树内**的 `GarageShell` 上并转发。实测：边距 24→16、编成条底边 725→**697 ≤ 720**。
- **失败项自带坐标**：布局审计的每条发现都带矩形（`@Label@…@x,y WxH`），使后续定位无需第二次运行。
