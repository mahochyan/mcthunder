# WT-023-R1 交付报告：河谷现代陆战独立可玩候选

- 依据：`02_首轮10张执行单.md` §10
- 候选身份：**源码 `499a6a1faf5fa15e3c598d985bfcc19640f7a632`**，分支 `work/continuation-20260913`，版本显示 `1.0.0-rc.3-dev`，build id `continuation-20260913`（`BuildIdentity`）
- 产物目录（仓库外，干净目录）：`E:\AIprogram\mcthunder-candidates\WT023R1\499a6a1faf5fa15e3c598d985bfcc19640f7a632\`

## 1. 交付物

| 产物 | 大小 | SHA-256（前 16） | 说明 |
|---|---|---|---|
| `PixelArmor.exe` | 109,137,920 B | `F0189283C16A6436…` | 真实导出（Windows 模板 `windows_release_x86_64.exe`，非旧 RC2 名称） |
| `PixelArmor.pck` | 65,608,880 B | `5DE6E5C116099F06…` | 内容包，与 exe 同目录使用 |
| 机器可读清单 | — | — | `docs/wt/continuation/CANDIDATE_MANIFEST_WT023_R1.json`（SOURCE/BUILD/CONTENT/RULES + 逐文件哈希） |
| 运行证据 | — | — | `logs/WT-023-r1/`（headless/window 输出 + 隔离档案引擎日志） |

**导出命令**（使用既有预设，未改动构建/发布流程）：
```
Godot_v4.7.2-stable_win64_console.exe --headless --path <worktree> \
  --export-release "Windows Team Slice" <候选目录>\PixelArmor.exe
```

## 2. 验证（本单实测）

| 项 | 命令 | 结果 |
|---|---|---|
| 独立启动（无头） | `PixelArmor.exe --headless --quit-after 120` | **EXIT=0** |
| 独立启动（真实窗口 1280×720） | `PixelArmor.exe --resolution 1280x720 --quit-after 600` | **EXIT=0** |
| 引擎日志错误扫描 | 隔离档案 `logs/godot.log`（175 B） | **无 ERROR / SCRIPT ERROR / WARNING** |
| **存档隔离** | 以 `APPDATA=<候选目录>\userdata` 运行 | 隔离档案被创建；**真实档案目录文件数 781 → 781 未变**（未污染用户进度） |
| 引擎身份 | `--version` / 哈希 | `4.7.2.stable.official.ed1daf0bf`，`C8F0A6BC…4643`（与 `BASELINE.json` 一致） |

## 3. 包含 / 不包含（明确展示）

**包含**
- 四辆已准入历史车（M4A3/M24/M26/M36）的完整战斗链：装甲/后效/模块/乘员/弹药账本/装填/维修/回放
- 两张正式地图（丘陵村落、工业边缘）的 4v4 团队战 + 训练/实验室入口
- 河谷枢纽大图：三点占点、道路导航、部署/补给、地形与桥梁（勘察/驾驶/占点演练）
- 车库：选车、检视（外观/装甲/内构）、配弹与编成、研发与个人最佳、模型展厅
- 中文 UI、按键重绑、无障碍设置、挑战任务

**不包含**
- **现代两车（T-80B / 豹 2A4）不可出战**：仍 `candidate_only`，`combat_definition` 为空（见 `PILOT_CANDIDATE_REPORT.md` 的 7 条缺口）
- **正式联网**（WT-024—026/037）未实现；仅有早期本机权威切片
- **性能专项 HOLD_BY_USER**：本包未做任何 FPS/p95/p99 采样与优化
- 10v10/16v16 容量的**对局验收**未做（仅泊位/路线/占点定义与可达性验证）
- 空海扩展（EXT-01—04）未实现

## 4. 已知问题（如实）

| # | 问题 | 影响 |
|---|---|---|
| 1 | **河谷枢纽尚未作为 8 槽正式战斗地图**：该场景提供三点占点/驾驶/勘察演练，4v4 正式战斗在丘陵村落/工业边缘进行 | 本单的端到端"进河谷→对战→再出击→结算"未做成交互脚本验收（`NOT_RUN`） |
| 2 | 河谷图独立进入时默认 `player_tank`（200 m 射线预算），经车库进入才带历史车（2500 m） | 直接启动河谷时远距交战不成立（见 `ENGAGEMENT_CONFIG.md` §3） |
| 3 | 河谷上的测距→装定→远距命中在 headless 不可自动化（需真实输入保持炮镜） | 该链由窗口套件与实验室套件承担；本包未跑窗口炮镜 |
| 4 | `run_balance_match_checks`、`run_app_match_cycle` 在本机 headless 超时/挂起 | 未纳入本候选的通过依据（`NOT_RUN`） |
| 5 | 本机 `package_candidate.ps1` 需要工作树内引擎（本工作树 `tools/godot` 仅有 `.gdignore`） | 该脚本未用于本候选；改用真实导出（产物更完整） |
| 6 | 回放/内构仍为步末静态几何近似；有限体积与时变内构连续求交未实现 | 沿用 `WT013_DELAYED_FUZE.md` 的边界声明 |

## 5. 真人验收表（保持未填，代理不代签）

| 项目 | 用户填写 | 说明 |
|---|---|---|
| 驾驶手感 | ☐ 通过 ☐ 不通过 ☐ 未测 | 4v4/训练中的加速、转向、制动、越障 |
| 开火与命中理解 | ☐ 通过 ☐ 不通过 ☐ 未测 | 是否能理解"打哪里、为什么没穿" |
| 受损与恢复 | ☐ 通过 ☐ 不通过 ☐ 未测 | 断带/失能/起火后的操作与维修/换位 |
| AI 表现 | ☐ 通过 ☐ 不通过 ☐ 未测 | 是否会推进、守点、让行、补给 |
| 再玩意愿 | ☐ 高 ☐ 中 ☐ 低 | — |
| 问题记录 | （自由填写） | — |

**human_accepted = false；release_ready = false**（本包是**开发候选**，不是完整陆战正式发行）

## 6. 运行入口（可复现）

1. 进入候选目录：`E:\AIprogram\mcthunder-candidates\WT023R1\499a6a1faf5fa15e3c598d985bfcc19640f7a632\`
2. 双击 `PixelArmor.exe`（或命令行 `PixelArmor.exe --resolution 1280x720`）
3. 首次运行会在 `%APPDATA%\Godot\app_userdata\PixelArmor` 建立档案；**如需隔离验证**，先设 `set APPDATA=<空目录>` 再启动
4. 车库 → 选车/配弹/编成 → 训练或 4v4；河谷枢纽入口在训练中心

## 7. 回退

- 删除候选目录即可（仓库外，无副作用）；`main` 工作区与本分支源码不受影响。
- 若需回到旧包：RC1/RC2 仍在 `E:\AIprogram\mcthunder-archive\retired\PixelArmor交付\`（历史身份，不代表当前能力）。

## 8. 下一步

按 `NEXT_ACTION.md`：本轮 10 张执行单全部完成 → 进入**阶段 4 统一交付汇总**（含未完成项、证据索引、已知风险与回滚）。
