# WT-009 本机权威服务器与两客户端切片

2026-09-12 更新：当前公共事件已升级为网络 v5 的有界日志、连续 ACK/补发和明确基线恢复，出站发布移至物理阶段 400。当前范围与新证据见 [WT009_EVENT_RECOVERY.md](WT009_EVENT_RECOVERY.md)。下文 64 条终止事件及旧终局确认限制保留为早期切片记录。

本批从925e819工作树开发，正式被测文件哈希、引擎哈希、三个进程PID/完整命令均在`logs/wt009/20260911-134038/RESULTS.json`。这是两辆历史车的开放训练场技术切片，不是已有4v4占点模式的联网版本。

## 已接入的生产路径

`NetworkBattleServer`只绑定127.0.0.1，ENet最多两个连接，先验证协议版本，再由服务器分配A/B，客户端不能指定控制其他车辆。消息长度上限4096字节，每tick最多处理32包、每peer最多4包；不支持客户端命中、毁伤、加弹或奖励声明。

`NetworkController.receive`将输入直接送入现有`VehicleActor.submit_command_envelope`，复用身份/生命/状态代次/控制纪元/序号/输入tick校验。客户端上行显式瞄点，服务器通过共享VehicleSimulationDriver执行驾驶、炮塔、装填、发射与ProjectileManager实际弹道。仅油门、转向、瞄点等连续输入可保留至既有12tick期限；开火/维修等边沿只入邮箱一次。断开连接清空输入并解绑控制者，重置/换控制纪元后的旧包不能继续执行。

`NetworkBattleWorld`装配两辆实际历史车型与地面，不装配PlayerController、HUD、Camera3D、CombatFeedback或音效节点。新增presentation_enabled默认true，只在服务器关闭；权威瞄准读取命令，而不依赖本地相机。现阶段仍构造车型视觉网格和CameraRig意图适配节点，尚未完成所有视觉资源的装配拆分。

20Hz下发版本化快照，包含服务器tick、快照序号、车辆身份/姿态/发射计数及已接收输入序号。事件环保留最近64个实际弹丸终止事件，带连续事件序号和弹丸/发射身份。训练场中位置与发射结果对双方公开；不直接发送SimulationSnapshot中的完整内部状态。

终止时关闭弹丸、停止车辆模拟并冻结最终快照，两客户端按原始JSON传输内容计算SHA256确认。没有用重新序列化后的浮点文本判等。此终局确认不等同于逐输入消费确认、长会话事件重传或断线恢复协议。

ENet调用按[Godot ENetMultiplayerPeer](https://docs.godotengine.org/en/stable/classes/class_enetmultiplayerpeer.html)及[MultiplayerPeer](https://docs.godotengine.org/en/stable/classes/class_multiplayerpeer.html)核对；本切片使用可靠传输，尚未评估延迟、抖动与丢包条件下的阻塞。

## 运行与验证

独立入口：`tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://scripts/network/server_main.gd -- 19109`。有限60帧入口检查退出0，日志`logs/wt009-server-entry-final.log`，没有音效资源泄漏警告。此入口不启动本地玩家，不需要游戏主菜单或相机。

三进程自动检查：`tests/run_network_slice.ps1`。它启动独立服务器和两个不模拟战斗的命令客户端，进行8秒实际通信。最终证据134038三端退出0、无SCRIPT ERROR/ERROR，摘要均为`8f1ae95febdf7f9f71a9d251eb990ef0c9aac42dbb2e04f09be1a831da02fef1`。两车实际移动、各发射2发；总4次唯一终止事件，其中2次真实地面命中。两端核对快照序号递增、重复事件内容不变、每个事件只记一次。布尔值伪装协议版本、越权控制、重复序号、自报命中各拒绝2次。

`logs/wt009-headless/925e819-network-headless/20260911-133843`：服务器控制器11、基础216、交战距离15、反馈40，共282项通过。控制器检查覆盖保留油门、单次发射、超时松油门、自然滑行、重置拒绝旧包及解绑丢弃待发边沿；普通路径保持默认呈现。此前命令30和全车阶段8项通过，单独保留原源版本范围。

失败证据保留：133058脚本类型推断失败；133202终局JSON数值重序列化摘要不一致；133330客户端在服务器断开后继续poll产生错误，虽客户端自报PASS但runner正确判失败。最终守卫断开状态后修复。控制器首次解绑断言错误地要求累计发射计数归零，后按Gunner实际累计语义改为“不增加”。服务器呈现剥离前的音频泄漏警告也保留，不覆盖旧日志。

## 未完成

交互式客户端画面/输入、房间与出击流程、团队比赛/重生/票池接入、完整弹药与毁伤下行、敌方情报过滤、输入消费确认、快照恢复、客户端预测/插值、断线重连、事件补发和公网身份体系均未完成。当前只实测localhost两客户端与4发炮弹；不能据此宣称可信4v4/8v8、网络毁伤全链或完整联网游戏通过。下一步接入交互客户端和实际断线再连接用例，同时推进WT-004—008驾驶火控。
