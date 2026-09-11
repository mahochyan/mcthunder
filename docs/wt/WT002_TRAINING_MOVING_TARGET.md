# WT-002 训练场共享调度与移动靶帧率验证

基于34ae1c3。Main基础靶场与BallisticsRange公共训练基类现安装同一个VehicleSimulationDriver；DamageRange、AICombatRange、ShellRange和ChallengeRange等继承路径使用该调度。场景直接子车辆进入树时自动关联，动态生成/重置后新车也加入。TeamRange复用基类实例并保留正式比赛名单，不再重复创建调度器。所有现有生产VehicleActor创建点已逐一检查。

玩家在训练场练习移动瞄准时，车辆采用与团队战斗相同的分阶段运动、瞄准和发射顺序。原有逐车数值积分夹具显式调用advance_standalone_tick，继续调用原命令/驾驶/机构/发射方法；游戏的正常物理帧调用不会绕过整组调度。没有改驾驶参数或用测试专用射击算法替代实际炮弹。

## 移动靶验证

tests/run_moving_target_tick_checks.gd实例化真实AICombatRange、保留装甲与毁伤链，使用物理优先级-10输入节点和200记录节点。固定360步：靶车横向正常驾驶，射手通过VehicleCommandCodec提交第90/240步开火，AimSolver依据外观位置/速度生成受控瞄准意图。这是确定输入夹具，不是普通鼠标输入、AI感知或完整自然比赛。

两发真实弹丸分别穿入/穿出B车后撞击后方世界；因此末端reason=impact_world不代表未中车。验证要求两个独立projectile_id都产生B车接触，并且实际接触时靶车速度非零。当前四次接触时速度均约1.6m/s，命中物理步为96、97、246、246；终止步为103、253。实际毁伤没有关闭或被HUD替代。

命令：`tests/run_moving_target_matrix.ps1`。证据 `logs/wt002-moving/20260911-123256`。真实Windows窗口1280×720，物理60Hz，渲染上限30/60/144及60+三次100ms延迟，四次均退出0且无SCRIPT ERROR/ERROR。360行逐步位置/速度、炮塔角度、射击数/装填/弹药/毁伤状态，以及接触点/接触步/终止结果精确一致（JSON数值完全相等，未放宽容差）。这不证明跨平台确定性、所有距离/速度、高速小截面目标或OS事件时间轴，也不等于整局60FPS性能达标。

## 现有回归

同一生产改动：`logs/wt002-training/34ae1c3-training-wip/20260911-122914`中基础靶场216、命令30、AI交战34、团队67通过。AI驾驶40项首轮有一项失败：新增C车的手动积分夹具仍调用被世界接管的_physics_process，因此C没有移动。改为同样的advance_standalone_tick后，`logs/wt002-training/34ae1c3-training-r2/20260911-123307`的AI驾驶40、阶段8、全车8、弹丸144项全部通过。未缩短对向会车仿真或修改断言。移动靶预检最初的类型声明错误保留于logs/wt002-moving-probe.log；修正后预检通过于logs/wt002-moving-probe-r2.log。

挑战140项和配弹185项补测已全部通过、退出0，见 `logs/wt002-training/34ae1c3-training-spawns/20260911-123503`，包括正常/困难主动防守、实际路线占点、有限弹药与村庄补给。本轮相关现有回归共872项通过；首轮AI驾驶失败独立保留，未加入通过数。SOURCE.json位于移动靶证据目录，记录基线提交、工作树及生产/矩阵脚本SHA256，明确为源码验证而非新独立包。

工业512路线矩阵未因夹具入口更名重复运行，不冒称本轮全量重新验证。WT-002仍保留输入消费确认和状态恢复等差距；WT-003距离/性能及WT-009早期本地服务器切片继续按完整方案推进。
