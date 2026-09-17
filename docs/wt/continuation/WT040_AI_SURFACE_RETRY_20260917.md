# 现代 AI 瞄准停滞：原误差下重新观察外部表面

上一轮为实际进展：a005b681 独立包正常现代整局、重启保存、实弹生命周期、车库与完整历史流程通过。本轮继续解决同一现代河谷目标中的 AI 参与度开放项，并准备包含已完成内构 HUD 的后继包。没有更改地图、车辆/弹药/伤害/装填/速度、难度误差、反应时间或验收判据。

## 原自然局中的最早失效

基线生产代码为 c164511e，记录器新增 opt-in `--trace-fire` 逐帧只读采样，按实际 lane_queries 计数识别新预测，避免把最后一次授权误认为持续更新。只读取 A/A2/A3 的状态、可见观察、实际炮口、误差与求解结果，最多 4096 条，不额外做查询或抽随机数。

`logs/WT040-ai-fire/natural-before.log/json`：原种子 44001、苏德两车、原河谷/规则、4v4、16v16 布局，306.7 秒 0∶214 自然结束，原检查 **8 项、1 失败、exit 1**，仍仅五槽位开火。逐帧记录没有截断。

- A3 在 156.100/156.350/156.600 秒获得三次新 world_blocked，之后先被敌弹击毁；不能称作没有完成反应或没有进入授权。
- A2 在 235.483 秒失去开火能力，此前没有提交完整弹道预测；不能将 A 的否决原因套到 A2。
- A 在 292.900/293.167 秒为 other_vehicle_first；293.433 至 294.500 秒连续五次新 predicted_path_misses，误差始终 `(-0.003215,-0.005653)` rad，294.700 秒才失去开火能力。由此确认健康时存在重复否决，但这段自然局自身不能证明无限停滞。

## 短对照与补丁

`tests/run_modern_ai_surface_checks.gd`（早期文件名 `check_modern_ai_aim_stall.gd`）建立明确的静止 170 米交战夹具，实际两车包、地面、机构、普通难度、原弹药和真实弹丸。河谷初始 A 的配置发生在 register_spawn 前，因此种子为 `44001+100+0*101=44101`。

保留所有尝试：`static-before.log/json` 最初误用下一生命种子 44202，7/0，只说明另一误差下可射击；更正为实际首生命种子后的 `static-initial-life-before.log/json` **7 项、1 失败、exit 1**，15 秒内 56 次预测均未能形成射击，误差与自然局相同。单独 `static-zero-error-control.log/json` 只将夹具误差设为零，7/0，确认炮口/机构/原弹药链能工作；零误差没有进入生产配置。

`AITankController` 原本只在换目标或开火后改变误差/首选外部表面；若这个表面加上固定误差始终落空，就无法开火，也无法触发后继选择。第一版修复仅在持续 predicted_path_misses 达到已有 difficulty.reaction 时间后，使用既有 0→4→5→3→0 外部采样序列。下一次正常观察重新选可见表面，保留原误差与 RNG、原扫描/授权频率、机构限位、真实炮口、观察年龄、友军/世界阻挡和弹道否决。

`static-after.log/json` 首次 7/0：同一误差在约 1.767 秒获实际目标接触授权并发射。最终增强检查 `static-after-contact.log/json` **11/0、exit 0**，检查误差不重抽、经历实际否决和表面重选、射击仍需授权、真实弹丸接触指定目标。

中间 `static-after-final.log/json` 11/1 保留：最初从只收终止弹丸的回放列表断言即时命中，20 帧时穿后弹还未结束，因此列表为空；修正为直接记录生产 projectile_contact 信号，保存完整接触事件。未更改游戏弹丸寿命或强制结束弹丸。

相关回归全部真实 exit 0，无 SCRIPT ERROR/ERROR/FAIL：AI 战斗 34、真实 AI 拦截 106、共享拦截数学 149、火控 57，共 **346/0**。日志位于 `logs/WT040-ai-fire/`，文件为 `run_ai_combat_checks.log`、`run_ai_intercept_checks.log`、`run_ballistic_intercept_checks.log`、`run_fire_control_checks.log`。包括反应时间、有限机构、友军/世界遮挡、炮口遮挡、旧观察/身份、受损武器和弹道预算，不能因短复现成功跳过自然整局。

## 自然复跑和后继包

第一版补丁的原种子自然整局 `natural-after.log/json` **8 项、1 失败、exit 1**：317.1 秒 0∶86 结束，仍为 A4 和四个 B 槽位开火；异常静止峰值 5 秒，通行通过。A 在 307.567—312.633 秒连续 20 次新 other_vehicle_first，仍不改变瞄准表面。短复现修复确实影响了战斗，但不能据此关闭原参与度门。

追加明确低掩体夹具 `low-cover-before.log/json`：1.3 米高掩体保留目标可见的上部，原首选射击点则被挡，56 次 world_blocked，**11 项、3 失败、exit 1**。补丁将重选条件扩为 predicted_path_misses/world_blocked/other_vehicle_first 三种已经实测的否决，反应间隔不变，所有遮挡检查仍逐次执行。`low-cover-after.log/json` **11/0**，`friendly-after.log/json` **13/0**：真实友方 T-80B 部分遮挡低处弹道，重新观察后实际弹丸接触豹 2A4，没有友军接触。没有令任何一次否决通过，也未自动挪动车辆或更改掩体碰撞。

最终检查文件默认顺序运行无遮挡/低掩体/友方车体三种场景，共 **35/0**。最终五套回归 `final-run_*.log` **381/0、全部 exit 0**，覆盖上述 35 项与 346 项关联检查。

第三次原规则自然整局 `natural-after-cover.log/json` **8 项、0 失败、真实 exit 0**：317.1 秒 0∶86 自然结束；A4、B3、B4、B2、B、A 共六槽位开火。A 在 307.567—308.367 秒四次 other_vehicle_first 后重新观察，于 308.850 秒获得 predicted_target_contact 并真实发射，312.950 秒才进入维修。双方分别到达 C/A 和 B/A/C，占点与通行门通过，健康且有路无友车阻挡时的静止峰值 5 秒；逐帧记录未截断。终场回放列表内有 12 条完成弹丸、27 接触、39 损伤事件；它仍是有界存储，非无界战斗总账。没有将六槽位要求改成五，没有改变终局条件；该结果只证明这一原种子工程整局，不扩大为所有种子平衡或容量验收。

后继构建工具新增显式 `-CommittedSnapshot`，仅允许配合内部 `-Candidate`；依旧 git archive 当前提交，在全新目录导入和执行必需检查，默认模式仍拒绝未提交的跟踪文件。快照模式记录被排除的工作区文件路径，不 stash、提交或覆盖用户模型制作成果。现代候选必需检查增加本次 AI 表面重选与六车内构 HUD。首轮实际构建被火控输入夹具时序错误拦住，修复和原失败见 [构建接续](WT040_FIRE_CONTROL_FIXTURE_20260917.md)，不计为新包交付。

两项实际拒绝检查通过：`build-reject-formal-snapshot.log` 拒绝将快照用于正式构建；`build-reject-dirty-default.log` 在不传快照开关时继续拒绝脏工作区，均 exit 1，且发生在引擎启动之前。

此时对外可运行包仍为 a005b681，其已验结果保持，但尚不含本次 AI 补丁或新内构 HUD。真人 PENDING、性能 HOLD_BY_USER、10v10/16v16 容量未验、最多 A/B/C 三点，`release_ready=false`、`public_release=false`。
