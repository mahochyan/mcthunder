# 现代河谷通行修复：接地、弯道与陡坡碰撞

基线：`work/continuation-20260913 @ fc177eb3`。执行依据为 [当前续办裁定](WT-040-R1_CONTINUATION_DECISION_20260917.md)。原 main 未修改。大图仍仅有 A/B/C 三个占领点；10v10、16v16 容量未签收。

## 实测与修改

1. **接地参考点错误。** 两辆现代车以损伤盒底面作为履带接地高度；T-80B 为车体坐标 Y=0.4 m，但绑定模型履带底面约为 -0.018 m，豹 2A4 约为 -0.032 m。损伤盒与实际接触面不是同一几何。`BoundVehicleModel` 现在从已通过身份、哈希及结构校验的运行装置网格取最低接触高度，保留原采样 X/Z、损伤体积与碰撞体。缺少有效几何时拒绝安装。历史车辆不经过此分支。
2. **直角弯提前换点导致冲出道路。** 原 through-waypoints 模式以 8 m/s 巡航并提前最多 6 m 换点，再松油转向。实测单车从 (-370,712) 弯道滑到约 (-389,709) 后无法转动。现在仅对超过现有 18° 转向阈值的折点使用已有减速、停靠、转向逻辑，巡航上限未提高。直线和缓弯仍连续通过。
3. **陡坡碰撞后的速度没有消除。** 原玩家从出生位直行约 38 m 遇到超过 28° 爬坡限值的坡面；碰撞拒绝位移，车辆却在离地分支反复恢复约 13 m/s 的旧前进速度。连续倒车 12 s 后仍为正 10.56 m/s。现在发生非可行走坡面的实际阻挡且离地时，仅保留碰撞求解器允许的前向速度。相同位置、车辆与输入下，倒车约 2 s 后已为 -2.78 m/s，12 s 后退回至出生点前约 5.8 m。没有提高爬坡上限、开放空中驱动或关闭碰撞。

## 短对照证据

目录：`logs/WT040-progress/`。固定引擎 `4.7.2.stable.official.ed1daf0bf`；headless、fixed-fps 60；河谷 seed=44001，4v4 运行在已登记的 16v16 布局。每次使用独立 APPDATA。

- `roster-before.json` / `contact-after.json`：相同 60 s 车队实验。修改前 A、A2、B4 在出口失去支撑并停住；修改后八车均驶过后部出口，60 s 采样均具有双侧完整支撑（个别车辆仍在正常转向）。
- `single-before.json` / `single-after.json`：同车无队友实验。修改前 t=38–60 s 原地停住，修改后 t=60 s 已行至约 (-469,680)，速度 8 m/s。
- `player-recovery.json` / `player-recovery-fixed.json`：同出生位直行 12 s，再倒车 12 s。修复前后记录见上文。早期记录的玩家 `submitted_throttle` 未减去倒车键，需读取正确的 `consumed_throttle=-1`；诊断脚本现已修正此字段。
- `flat.json`：扩大到 1000 m 的平地控制面，两车玩家输入正常加速、AI 抵达目标。最早 `before.json` 的 200 m 控制面不足，t≥8 s 的平地越界数据不作车辆故障证据。
- 早期路径 ID 数组未深拷贝，释放场景后为空；速度、位置、命令和事件独立保存有效。诊断脚本现已复制此数组。

复现示例：

```powershell
$env:APPDATA = 'E:/AIprogram/mcthunder-cont/logs/WT040-progress/new-run-userdata'
& tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . -s res://tests/diagnose_modern_river_progress.gd --log-file E:/AIprogram/mcthunder-cont/logs/WT040-progress/new-run.log -- --modern-progress-check --case roster --seconds 60 --out res://logs/WT040-progress/new-run.json
```

`--case single`、`flat`、`player_recovery` 分别执行对应短对照。该脚本完成采样的退出码不代表通行验收；带断言的回归为 `run_modern_support_checks.gd`。

## 回归

最终生产补丁对应 `final-regression.json`、`final-ai-regression.json` 及同名前缀日志：现代接地/弯道/陡坡恢复 19、驾驶 26、离地驾驶 13、落地接触 13、落地响应 23、斜坡转向 3、部分支撑 7、AI 驾驶 40、AI 战术 39、团队交通 34、模型包 59、现代运行 44，均为 0 失败。此前河谷任务映射 4/4。

现代专项同时确认：25 cm 路缘上两侧履带能支撑并转向；1 m 落差仍拒绝悬空侧牵引和转向；实际车辆能完成直角路径并保持车体道路余量；35° 坡仍无法强行爬升、真实倒车命令可以退离。部分旧套件退出时报告 ObjectDB 残留警告，未将警告省略为“完全无警告”。最初专项测试有两处局部类型推断错误，`support.log` 保留该失败；修正后结果以最终日志为准。

## 未完成与下一步

`modern-match.json` 是接地与弯道修复后、陡坡速度修复前的自然整局，源码文件哈希在 `modern-match-source.json`。比赛于 419 s 正常结束，两队到达占领区；8 项检查中 **2 项失败**：仅 4 个槽位开火，最长静止 125 s。事件量为 9 发射、12 接触、13 毁伤事件。旧记录器的 `deaths_total` 只数终场残骸，不能将其 0 解读为全局无人阵亡；再出击统计继续标记 WITHDRAWN。

此局表明物理修复没有解决所有路线/让行问题。后续重点是路点 0 的重复重规划、目标已有队友停靠、道路上的持续阻挡；保留原判据，不增加豁免。记录器新增独立输出路径、实际车型 ID，并明确区分旧故障描述与本次测量。

当前历史候选包为 `69a83a9ed923569f2bc3895544d7c910e049f8c9`，其七个文件与 BUILD_MANIFEST 哈希均已核对（`current-package-identity.json`）。包内完整玩家流程复验为 **45 项、9 失败、退出 1**，证据在 `logs/034/69a83a9ed923569f2bc3895544d7c910e049f8c9/20260917-105515/`。M36 四发入口通过；挑战驾驶/射击失败，实际截图 `03_flank_aim.png` 显示暂停菜单，不将此轮当作有效驾驶。早期存在其他无窗口引擎进程，不能仅凭暂停现象认定因果；后续窗口验证独占引擎。包内还确认现代 GLB 缺失。

构建根因：干净源码 `git archive` 清单遗漏 `addons`，使已注册的原始 GLB 导出插件无法加载；原构建导入/导出日志明确报告缺少 `addons/bound_model_export/plugin.cfg`。修复将目录纳入归档并检查插件三文件；新增 `-Candidate -ModernRiver` 必需两车、弹种、布局、绑定原始哈希与河谷三点运行检查。实际独立导出验证仍待完成，不能将源码修复视作包已交付。

原提交工业复跑已完成：同一 `69a83a9e` 构建干净源码、固定引擎、原脚本/种子/启动方式及 1500 s 超时，UTC 03:00:37 至 03:08:52，用时 **494.85 s**，无超时，实际子进程退出 **1**，**16 项、1 失败**（一方不足三个实际槽位到达中央接近区）。仅说明本次未复现异常耗时，不能据此判断此前原因。证据 `industrial-exclusive/RESULTS.json`、`stdout.log`、`progress.jsonl`、`process-family.json`。原外层统计把控制台包装器的同一引擎子进程误记为并发；独立进程族监控的 `unrelated_engines` 全为空。外层脚本末尾有 `textplaceholder` 拼写错误，发生于子进程终止并保存结果之后；结论采用真实子进程结果，不重复该唯一复跑。

前端补丁接入明确的现代河谷内部入口；现代车型使用独立工程模式，不增加历史研发解锁或奖励。保存兼容原四车存档并严格验证可选现代配弹；出战及重开保留所选车型与携弹。车库预览使用实际绑定模型与同一身份/哈希校验。源码专项 `modern-garage-r2.log` 为 27 项、0 失败且无脚本/资源错误；首轮暴露的旧历史预览路径错误保留于 `modern-garage.log`，该轮虽断言全绿，仍不计通过。此专项只验证入口/配弹/保存/重开，**不是完整自然对局或实弹死亡证明**。

现代独立包、同一玩家生命实弹死亡/再出击、最终现代整局仍未完成。

总体状态仍为“现代河谷集成交付进行中”。真人 PENDING，性能 HOLD_BY_USER，release_ready=false，public_release=false。
