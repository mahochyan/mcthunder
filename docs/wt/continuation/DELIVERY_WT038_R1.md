# WT-038-R1 正式交付门报告（第 2 轮候选）

- 依据：`03_全部42项目标工作单.md` WT-038（完整陆战产品候选与正式交付门）；前置：WT-035-R1 **完整回归门**
- 候选身份：源码 **`b9eeb245fb0b12f4720e636e0c322f68dee36e2d`**（分支 `work/continuation-20260913`），显示版本 `1.0.0-rc.3-dev`，build id `continuation-20260913`
- 产物目录：`E:\AIprogram\mcthunder-candidates\WT038R1\b9eeb245fb0b12f4720e636e0c322f68dee36e2d\`

## 1. 产物与哈希（本机实测）

| 产物 | 大小 | SHA-256 |
|---|---|---|
| `PixelArmor.exe` | 109,137,920 B | `F0189283C16A6436151682AC8B078C298CDE893F27812E52747549462B25965A` |
| `PixelArmor.pck` | **65,796,900 B** | `90040DA44A0151BD157B9DA414268E7E10865397719E9ECE20B65FC9A86565A6` |
| 机器可读清单 | — | `docs/wt/continuation/CANDIDATE_MANIFEST_WT038_R1.json` |

**导出方式（未改构建/发布流程）**：既有预设 `Windows Team Slice` + 本机已安装模板
```
Godot_v4.7.2-stable_win64_console.exe --headless --path <worktree> \
  --export-release "Windows Team Slice" <候选目录>\PixelArmor.exe
```

**与上一候选（WT-023-R1 @ `499a6a1f`）的对照**：exe 哈希**相同**（引擎模板是静态的，符合预期）；**pck 由 65,608,880 → 65,796,900 B（+188,020 B）**，反映其后 30 余个提交的新增内容已进入包内。

## 2. 独立启动与隔离验证（本机实测）

| 项 | 命令 | 结果 |
|---|---|---|
| 无头启动 | `PixelArmor.exe --headless --quit-after 120` | **EXIT=0** |
| 真实窗口启动 | `PixelArmor.exe --resolution 1280x720 --quit-after 600` | **EXIT=0** |
| 隔离档案引擎日志 | `APPDATA=<候选目录>\userdata` → `logs/godot.log`（175 B） | **无 ERROR / SCRIPT ERROR / WARNING** |
| **存档隔离** | 同上，运行前后统计真实档案 | **832 → 832 文件未变**（未污染用户进度） |

## 3. 交付门前置：WT-035-R1 完整回归门

**140 个可跑套件**：**117 PASS / 0 本分支引入的回归**；4 个既有红（`chassis_response`、`historical_road`、`team_checks`、`map_checks`）**全部在未改动的 `a1bac406` 上复现同样失败**；核心 `run_checks` 由基线 **212/5** 改善为 **216–217/0–1**（如实标为抖动而非全绿）；5 个窗口套件在 headless 自守卫；11 个慢套件记 `DEFERRED`（**不计入通过**）。详见 `REGRESSION_GATE_ROUND2_FULL.md`。

## 4. 发布限制声明（**不隐瞒**）

| 项 | 状态 |
|---|---|
| 现代两车（T-80B / 豹 2A4） | **`candidate_only`、未获战斗准入**；装填机构与装备矩阵为**实验级**（`game_rule`） |
| M1A1 / ZTZ-99A | **延期**：缺内容树参考条目与 packet `model_binding`；M1A1 另需重导出（角色映射 4/6） |
| 资产注册表 `model_sources.json` | **仍为空**（113 个研究模型未注册；`VehicleReadiness` 按文件存在性解析，故不影响可用性） |
| 正式联网 | **部分**：回环权威 + 身份/命令校验/幂等收据/时间模型/房间状态机**已实现并验证**；公网双端、房间发现/中继/专管托管/账号**未授权、未实现** |
| 性能 | **`HOLD_BY_USER`**（全程**零** FPS/p95/p99 采样，未做优化） |
| 真人验收 | **`NOT_RUN`**（体验门 `PENDING`，见 §5） |
| 10v10 / 16v16 容量对局 | `NOT_RUN`（仅泊位/路线/占点定义与可达性验证） |
| 空海扩展（EXT-01—04） | 未实现 |

## 5. 真人验收表（保持未填，代理不代签）

| 项目 | 用户填写 |
|---|---|
| 驾驶手感 | ☐ 通过 ☐ 不通过 ☐ 未测 |
| 开火与命中理解 | ☐ 通过 ☐ 不通过 ☐ 未测 |
| 受损与恢复 | ☐ 通过 ☐ 不通过 ☐ 未测 |
| AI 表现（推进/守点/让行/补给） | ☐ 通过 ☐ 不通过 ☐ 未测 |
| 现代装备观感（若试） | ☐ 通过 ☐ 不通过 ☐ 未测 |
| 再玩意愿 | ☐ 高 ☐ 中 ☐ 低 |
| 问题记录 | （自由填写） |

**`human_accepted = false`；`release_ready = false`** —— 本包是**开发候选**，非完整陆战正式发行。

## 6. 需授权事项（命中红线，未动手）

**独立服务器/客户端导出配置**：`export_presets.cfg` 现仅有 `Village Resource Check` / `Windows Team Slice` / `Windows Release` 三个通用预设，**没有 server/client 专用预设**。新增预设属**修改构建/发布流程**（用户红线）→ **本单未改**，在此请求授权后再做。

## 7. 运行入口（可复现）

1. 进入候选目录（见顶部路径）
2. 双击 `PixelArmor.exe`（或 `PixelArmor.exe --resolution 1280x720`）
3. 首次运行于 `%APPDATA%\Godot\app_userdata\PixelArmor` 建档；**隔离验证**请先 `set APPDATA=<空目录>`
4. 车库 → 选车/配弹/编成 → 训练或 4v4；河谷枢纽入口在训练中心

## 8. 回滚

- 删除候选目录即可（仓库外，无副作用）；
- 代码层：`git revert <提交>`（本分支 32 个提交均为**追加式**，默认惰性）；
- 整体：切回 `a1bac406`；原工作区**从未被修改**（porcelain 恒为 379）。
