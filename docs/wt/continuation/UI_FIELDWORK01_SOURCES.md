# UI_FIELDWORK01 设计输入来源（补发与裁定记录）

> 本文件只记录**来源与裁定**，不复制设计内容；四份原始 JSON 以**逐字节原件**形式存放于本目录。

## 1. 四份原始设计文件（补发，未修改）

来源：用户 2026-09-17 补发的 `MCTHUNDER_UI_FIELDWORK01_原始JSON补发包`（原始包 `MCTHUNDER_UI美化_设计与执行单_FIELDWORK01.zip`，3466300 B，sha256 `a70553e4…`）。
`REISSUE_MANIFEST.json` 声明四份文件**与原包逐字节一致**且与 `PACKAGE_INDEX.json` 一致；本目录已按原件落盘并逐项复算 sha256 核对（见下表）。

| 文件 | 字节 | sha256（前 16） | 落盘位置 |
|---|---:|---|---|
| `07_UI_TOKENS.json` | 3245 | `9e429a76cb264092` | `docs/wt/continuation/07_UI_TOKENS.json`（并**逐字节复制**为运行时源 `configs/ui/ui_tokens.json`） |
| `08_VIEW_CONTRACTS.json` | 3279 | `26b0984131b5d6e7` | `docs/wt/continuation/08_VIEW_CONTRACTS.json` |
| `09_ACCEPTANCE_CASES.json` | 17574 | `c3f18243da2f0df2` | `docs/wt/continuation/09_ACCEPTANCE_CASES.json` |
| `10_WORK_ORDERS.json` | 35063 | `d41df0774a442fea` | `docs/wt/continuation/10_WORK_ORDERS.json` |
| `REISSUE_MANIFEST.json` | 3593 | `4bc8ead432171711` | `docs/wt/continuation/REISSUE_MANIFEST.json` |

> 我此前按"阅读版"转录过一份 `07_UI_TOKENS.json`（结构为 `{value,use}` 对象、缺 `focus` 令牌）。**原件到手后该转录已被原件替换**，`UiTokens` 读取器与主题同步改按**原件结构**（扁平色值 / `font.sizes_at_ui_scale_1` / `components.*` / `layouts.*` / `motion_ms.*`）。

## 2. 颜色裁定（用户 2026-09-17 正式裁定）

- **以规范正文颜色表与原始 `07_UI_TOKENS.json` 为准**；两者数值一致 ✓
- **`focus` 与 `accent` 使用同一个暖金色 `#E0B46A`**（原件 `colors.focus` 已明确）
- 概念图色条 `#0F1419 / #1C2A38 / #E63946 / #D4AF37 / #3A7BD5 / #2ECC71` **仅属气氛参考**：
  **不取代令牌**，**不把普通"进入战斗"按钮改成红色/危险色**
- 固定关键值：`background #10171B` · `surface #182329` · `surface_raised #223139` · `text_primary #ECEDE6` · `text_secondary #A8B6BA` · `accent #E0B46A` · `on_accent #141A1E` · `focus #E0B46A`

## 3. 使用规则（避免新歧义）

1. **不覆盖已建立的 goal/todo/实际进度**：四份 JSON 里的 `status: design_proposal_not_installed`、`planned`、`NOT_RUN` 是**设计发布初始态**，不要求重置进行中的工作。10 个执行阶段 ↔ 12 张工单的映射保持现状。
2. `08_VIEW_CONTRACTS.json` **不是现有 API 保证**：它是**建议的展示输入与操作意图**（`garage / battle / respawn / result` 四组）。映射到当前真实服务即记入 `UI_BINDING_MAP.json`；**不要求业务 API 改名**，**不创建第二套目录/库存/保存/战斗状态**；缺失且未支持的状态**明确未知或不可用**，不用示例值填正式界面。
3. **设计快照不决定工作区版本**：继续使用 `work/ui-fieldwork-01`，保留 `a005b681` 及其**后继成果**（现代车材料/弹架/装填/河谷/打包）不重做；用户未跟踪文件原样保留。
4. **字体**：继续使用仓库现有 `CoreUI.FONT`（`assets/fonts/NotoSansCJKsc-Regular.otf`）；**不因规范字体称呼而替换、下载或额外分发字体**。
5. **性能** `HOLD_BY_USER` · **真人不代签** · 内部包 `release_ready=false` · 不公开发布。
6. 布局初值在 720p／125% 放不下时，按既有响应式规范调整布局；**不得回缩字体**抵消大字设置。

## 4. 与第一批交付的关系

第一批交付 = **Godot 里可操作的新车库 + 真实主题组件 + 1280×720／1920×1080 各 100%／125% 截图 + 正常切页/配装/出战请求证据**。
组件实验场可用**明确标注**的模拟状态；**正式车库必须读取真实**车型、地图、配装与准入数据。
