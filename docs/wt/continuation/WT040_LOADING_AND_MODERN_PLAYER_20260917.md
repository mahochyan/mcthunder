# T-80B 装填接线与正常现代玩家流程

## 已交付包的历史流程复验

`82f548389b57f906ab1db4eeaa8c37819231886f` 实际独立包完整历史玩家流程 **96/0、实际 exit 0**，无超时、无缺图；包括 M36 入口、挑战及保存、两张历史地图自然结算与下一局。记录：`logs/034/82f548389b57f906ab1db4eeaa8c37819231886f/20260917-124852/RESULTS.json`。该包的 EXE/PCK 身份沿用前一份交付记录。旧 `4747d84d` 的 96/1 仍保留为旧包失败，不改写。

## T-80B 已测根因及修复

生产包漏掉了已有 authoring 包的 `loading_profile` 和 `autoloader` 模块，三乘员车因此落入人工装填默认分支，健康状态 `reload_rate=0.625`，并显示“装填手失能”。旧 runtime 检查把多出的装填时间解释成自动装填周期，该解释已更正。

恢复来源为已存在的 `authoring/reference_data/modern_bound/ussr_t_80b.json`，属于明确游戏设计值。迁移工具 `authoring/reference_data/restore_t80_loading.py` 核对原包、作者包、交付 GLB 哈希及实际挂点；恢复自动装填机构和 28 待发 / 10 备用布局，总容量仍 38。7.1 秒名义射击装填、弹药性能、外装甲和驾驶参数未改。新 provenance 为 `configs/vehicles/evidence/t80_loading_restoration_20260917.json`，不把它标为历史真实性证据。迁移已应用，重复应用会拒绝。

生产 Actor 基线 `loading-baseline-r2.log` **7 项 2 失败**；修复后 `loading-restored.log` **23/0、exit 0**：健康自动装填率恢复为 1，真实发射后的自然周期约 7.133 秒；机构损坏阻断装填与完成绕过，正常维修后续装且库存守恒，重置保留三乘员。损伤为显式模块事件夹具，不声称本项为实弹击毁机构。豹 2A4 人工装填及失去装填手后的减速仍有效。此检查已加入现代候选包必需构建门。

相关源码回归：实际 runtime **44/0**、毁伤 **29/0**、装甲坐标 **17/0**、AppFlow **127/0**。证据均在 `logs/WT040-progress/loading-run_*`，未重开性能专项。

## 源码正常输入整局

新增原生窗口验证入口 `--verify-modern-match` 与独立包执行脚本 `tests/run_modern_player_flow.ps1`。通过真实卡片、键盘配弹、部署按钮、W/S/A/D、鼠标观察和开火，以及结果按钮操作；使用现有道路图规划输入、仅对当前可见敌人瞄准。不写车辆位姿、健康、冷却、库存或比赛规则。

源码实际窗口 `modern-player-source-console.log` **28/0、exit 0**。正常配弹 12 主弹 / 6 副弹，行驶约 1,831 米，4 次玩家发射、10 条弹道接触、7 条损伤记录；结果统计 4 命中、4 穿透、1 击毁、玩家未阵亡。307.517 秒自然票池终局 0:52，实际点击下一局仍是 T-80B / 18 发，再经暂停菜单正常回车库。单独新进程 `modern-player-resume-source-console.log` **3/0、exit 0**，恢复车型与 18 发配弹。

原始事件和截图：`logs/WT040-progress/modern-player-source-userdata/Godot/app_userdata/PixelArmor/tests/modern_match_shots/`。`04_result.png`、`05_next_match.png` 已目视：A/B/C 三点、实际结算、下一局配弹和健康无失能提示可见。所有截图为工程自动输入，不代签真人。

**此段为修复后源码结果，不能回填为 82f54838 包内结果。** 新包的完整现代流程及单独生命周期夹具待构建复验。本自然局没有玩家阵亡；不能把其他车辆阵亡合成玩家生命周期证据。

## 保留项

实际比赛仍为 4v4，最多 A/B/C 三点；10v10/16v16 容量未验证。当前编成逻辑把友方 AI 也配置为对方工程车型，此局是玩家 T-80B 加友方豹 2A4，不能标成苏德分队完成。T-80B 12 个车体区材料仍 unknown；原始未知记录不得由附件材料推断填充。豹 2A4 作者弹架布局尚未同步。真人 PENDING，性能 HOLD_BY_USER，所有包 `release_ready=false`、`public_release=false`。

## 修复后独立包与重启短复现

实际源码 `7b8d18376e761f3e900afb44e51bd58bca0ff0b3` 已构建到 `backups/builds/031/7b8d18376e761f3e900afb44e51bd58bca0ff0b3/20260917-131542-984/`。10 套构建门 **332/0**，实际 exit 0，无豁免；独立启动、必需现代内容和窗口均通过。两现代车型、河谷与自动装填修复均在该包。

第一轮包内正常输入整局 **28/0**，独立重启业务断言 **3/0**，但重启 stderr 有 3 条 `shader_gles3.cpp:802 initialize err != OK`，所以 runner 整体 **FAIL**。完整原记录 `logs/WT040-modern-player/7b8d18376e761f3e900afb44e51bd58bca0ff0b3/20260917-131934-361/` 保留，不改绿。EXE/PCK 与存档哈希均未变，截图完整。

同包、同存档、原长路径，独立短复现 `loading-package-restart-long.json` 再次为 3 条相同错误、exit 0、存档未变。将整个该测试 userdata（包括原 shader cache）原样复制到 `logs/WT040-short-restart` 后，`loading-package-restart-short.json` 为 0 错误、3/0、exit 0、存档未变。长路径中 3 个缓存目录长度为 255/255/257 字符。初步定位到 Windows 缓存目录路径相关的重开失败，不归因为 GPU 性能或存档损坏。[Godot 对应提交的初始化源码](https://raw.githubusercontent.com/godotengine/godot/ed1daf0bf/drivers/gles3/shader_gles3.cpp)在进入/创建缓存目录时有该错误条件；网页行号与二进制不同，不据此声称精确到引擎某行的根因。

验证脚本现将运行 userdata 放到短的 `logs/WT040-runtime/<timestamp>`，保留 SHA 目录下的报告，报告登记实际路径及 runner 哈希。缓存仍启用、错误仍导致失败；实际游戏默认 userdata 与二进制未修改。缩短路径后的完整流程正在复验，短重启不能替代完整复验。

配置只读差异表 `logs/WT040-progress/modern-authored-policy-parity.json` 供后续补缺：作者与运行包使用相同 GLB，但不应盲目覆盖全套 armor。T-80B 有 12 个 unknown hull 区及 5 个已知 cast 与作者 rolled/composite 的不同项；后者不能当缺失项自动替换。豹 2A4 尚缺明确人工装填 profile 与作者 15/27 弹架，当前为 10/16/16。`ArmorResolver` 对未知材料返回未解析结果，故整车受弹完整性仍是实际保留项。
