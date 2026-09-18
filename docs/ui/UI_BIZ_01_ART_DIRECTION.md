# UI-BIZ-01 · 阶段 1 美术方向（商业网游客户端质感）

本文件是阶段 1 的方向性交付物，配套交付：`configs/ui/ui_tokens_biz.json`（叠加令牌，**不改原件**）与 `assets/ui/biz/ASSET_MANIFEST.md`（素材清单，逐件带来源/授权/日期/SHA256）。

## 0. 目标与硬边界

- **目标**：把界面从"规范正确、诚实可验证"提升到"商业网游客户端的完成度与观感"——层次、材质感、图形化、动效节奏、状态完备。
- **边界（不可越）**：只动 UI 层（样式/布局/资源/动效）；不改业务逻辑、数据结构、接口；不删不藏任何现有入口；不改构建配置、不升级引擎；**不改 `configs/ui/ui_tokens.json` 原件**（它与设计单原件逐字节一致，颜色裁定以它为准）。
- **数据诚实**：原令牌文件的 `forbidden_static_mock_values`（银币余额、战力分、战力等级、联网人数、虚假历史性能、超出支持的对战规模）**一律不显示**；本方向只用真实字段做"大号数值"。

## 1. 色彩

| 角色 | 令牌 | 值 | 用法 |
|---|---|---|---|
| 背景（三层） | `background` / `surface_sunken` / `surface` | `#10171B` / `#131C21`(新) / `#182329` | 页面底 → 凹陷区 → 面板 |
| 抬升面板 | `surface_raised` / `surface_overlay`(新) | `#223139` / `#1B262CD9`(新) | 悬浮卡、抽屉、模态 |
| 描边 | `border_decorative` / `hairline`(新) / `hairline_strong`(新) | `#35464E` / `#2A3A42` / `#3E535D` | 装饰分隔 → 1px 细线 → 强调描边 |
| 文字 | `text_primary` / `text_secondary` / `text_tertiary`(新) / `disabled_text` | `#ECEDE6` / `#A8B6BA` / `#8A9AA1` / `#83969D` | 主/次/三/禁用 |
| **强调（唯一）** | `accent` / `focus` / `on_accent` | `#E0B46A` / `#E0B46A` / `#141A1E` | 主操作、选中、焦点框（裁定：focus = accent） |
| 语义 | `positive` / `warning` / `critical` / `ally` / `enemy` | 原值不变 | 成功 / 警告 / **危险与错误专用** / 友方 / 敌方 |
| 半透明派生 | `accent_soft` `accent_line` `*_soft` | 同色 20%/40% alpha（新） | 高亮底、内发光、状态底纹 |
| 遮罩 | `scrim`(新) | `#0B1013CC` | 模态背景压暗 |

**裁定遵守**：普通"进入战斗"按钮**不用红色**（红仅用于危险/错误/敌方）；不做"满屏金色"式高对比。

## 2. 字体与字阶

- **中文**：`assets/fonts/NotoSansCJKsc-Regular.otf`（OFL，库内既有）——所有中文与混排正文。
- **拉丁/数字/单位**：`assets/fonts/Rajdhani-{Medium,SemiBold,Bold}.ttf`（OFL，本阶段新增，来源与授权见素材清单）——字标、大号数值、单位、英文标签。
- **字阶（新令牌 `type_scale`）**：logotype 40 / display_xl 44 / display_l 34 / display_m 26 / title 22 / subtitle 18 / body 15 / label 13 / caption 11；数值 number_l 30 / number_m 22 / number_s 16。
- **规则**：字标带字距（logotype_letter_spacing 4）；标签全大写 + 字距 1；**中文不参与字距拉伸**（避免 CJK 排版走形）；大号数值只用于**真实字段**。

## 3. 圆角、描边、阴影、发光

- **圆角**：沿用 `components.radius = 4`（设计单限定 2–4）；缩略图与图标底可到 6，仅限图形块。
- **描边**：常规面板 1px `border_decorative`；悬停/选中用 `accent_line`；焦点框 2px `focus` + 外发光（`focus_inner/outer` 新令牌）。
- **阴影/层次（新令牌 `elevation`）**：panel(2/6/0.35) → raised(4/12/0.42) → overlay(8/24/0.5) → modal(12/32/0.58)，颜色 `shadow`，形成**层次化背景**而不是平面堆叠。
- **内发光**：面板内 1px `hairline` + 顶部 `accent_soft` 1px 高光条（模拟仪表玻璃边），仅用于焦点/激活面板。

## 4. 图标风格

- **两套统一为一套策略**：viewBox 24 · 描边 **1.75** · **单色白** · 由 `modulate` 上色（与原 `ICON_MANIFEST.json` 策略一致）。
  - 既有 17 枚 `assets/ui/icons/*.svg`（本仓生成器，**不动**，测试依赖）。
  - 新增 68 枚 `assets/ui/biz/icons/lucide_*.svg`（Lucide，ISC；已把 `currentColor`→`#ffffff`、`stroke-width=2`→`1.75`）。
- **用法**：导航/页签 20–24px；行内 16px；状态徽标 18px；命中区不小于 40×40（原令牌 `icon_hitbox_min`）。
- 未采用的名字（`filter`/`history`/`circle-help` 直连 404）**不替代猜测**，需要时用既有图标或后续补件。

## 5. 动效节奏（新令牌 `motion`）

| 场景 | 时长 | 缓动 |
|---|---|---|
| 悬停/按压反馈 | 100 / 90 ms | `ease_out` |
| 页面切换 | 160 ms | `ease_out` |
| 抽屉/侧栏 | 180 ms | `ease_out` |
| 面板入场 | 180 ms | `ease_out` |
| 卡片抬升 | 120 ms | `ease_out` |
| Toast/提示 | 160 / 200 ms | `ease_out` |
| 强调（出战确认、星级） | — | `back_out` |

**约束**：不改动设计单既有的 `motion_ms` 键；新增键只在叠加文件；所有动效**不阻塞操作**（无长转场），并在"减少闪烁"偏好开启时降级为直接切换。

## 6. "网游质感"改造手法清单（阶段 3 每屏复用）

1. **层次化背景**：页面底纹（径向暗角 + 极低对比网格）+ 分区面板（`surface`）+ 抬升卡（`surface_raised` + elevation-2）。
2. **描边与内发光**：1px 细线 + 顶部高光条 + 选中态 `accent_line` 外发光。
3. **状态高亮**：悬停抬升 1–2px、选中左边 2px 强调条、禁用降饱和 + 说明文字。
4. **图形化数据**：真实字段做成数值块（大号数字 + 单位小字）、进度/容量做条形、弹药做图标格、票数做双色条。
5. **过渡动效**：页签切换、抽屉、卡片、提示按第 5 节节奏；焦点移动可见。
6. **加载/空/错误态**：统一骨架/空态插画位（用图标+文案，不用占位图冒充）、错误态用 `critical` + 可读原因（沿用既有服务原因，不重算）。
7. **不引入**：写实照片背景、伪 3D 镀铬、扫描线、霓虹、军工花纹、资源/等级/战力等系统没有的字段。

## 7. 与概念图的对齐与不可复制项

- **对齐**：字标层级、大号真实数值、卡片缩略图、地图/模式卡片化、面板层次与节奏、HUD 图形化。
- **不可复制（除非改裁定）**：红色主 CTA、银币/金币/等级/战力分、16v16 与跨国编队、写实照片级背景、原画级坦克渲染。

## 8. 阶段 1 验收对应

| 验收项 | 本阶段证据 |
|---|---|
| 设计令牌文件 | `configs/ui/ui_tokens_biz.json`（新增，叠加；原件未改 ✓） |
| 素材清单完整、来源授权明确 | `assets/ui/biz/ASSET_MANIFEST.md`（逐件 URL/授权/日期/SHA256 ✓）+ 许可证随包 `assets/ui/biz/licenses/*` ✓ |
| 不引入无法构建的依赖 | 仅 SVG 与 TTF（引擎原生导入，项目已在用 ✓）；未改构建配置 ✓ |
| 不影响既有功能 | 阶段 1 未改任何 UI 代码；下一步运行既有令牌/图标/导航/HUD 自检并记录 ✓ |
