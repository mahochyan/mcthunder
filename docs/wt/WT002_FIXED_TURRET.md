# WT-002：炮塔固定步长第一批

玩家收益：炮塔机构不再因为显示器渲染次数而多推进或少推进；同一物理步开火读取已经更新的真实炮管方向。当前保留有限转速、俯仰限位、部件失能和自由观察锁定。

VehicleActor._apply_command_once 在驾驶、设置瞄准意图之后，调用 TurretRig.advance_mechanism，再处理发射。TurretRig._process 只衰减枪管后坐和闪光。没有添加独立炮塔物理回调，因此没有第二个机构推进入口。装填仍在 VehicleActor._physics_process 入口先推进；世界级所有车辆、弹丸和比赛事件尚未收拢为完整统一调度。

## 证据范围

开发工作树验证，以 e56a8a5 为修改基线。真实窗口命令：

`tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . --position 40,40 --max-fps <30|60|144> -s res://tests/run_turret_tick_checks.gd -- res://logs/wt002/render/<cap>.json`

长帧使用144上限、输出stall.json、追加--stall，在物理命令序列的60/180/300步各注入100ms阻塞。未使用--fixed-fps替代真实渲染节奏。四次退出码均0。

360步逐步比较 yaw/pitch/shots/cooldown；四组最大差值0，发射次数均2，结束记录均为两次impact_world。原始JSON与COMPARISON.json见logs/wt002/render。该夹具验证静态遮挡场景的固定命令，不覆盖玩家鼠标采样时间戳、移动目标或全局网络确定性，也不代表复杂炮战性能。

现有AI战斗34项、驾驶25项通过；弹体144项初次失败，修正测试等待物理步后通过（logs/wt002/projectile-r2.log）。原测试用两个渲染帧不变判定稳定，可能两个渲染帧之间没有物理推进。保留1毫米命中容差，未放宽。损伤57项、菜单开火交接3项通过（logs/wt002/wip-r2/）。实验室仍有退出ObjectDB警告，未声明无泄漏。

## 剩余 WT-002

版本化 VehicleCommand/ShotRecord/MatchEvent/SimulationSnapshot 契约、观察意图的时间戳与物理采样、整局车辆/弹丸/毁伤/比赛事件的明确顺序、正常输入帧率及移动目标对照仍未完成。当前只完成炮塔机构迁移这一实际生产切口，不能把WT-002整包标为完成。
