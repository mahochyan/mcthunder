class_name VehicleCommand
extends RefCounted
## 003：统一控制命令。PlayerController 与（未来）AIController 只生成命令；
## VehicleActor 负责限制输入并调用相同驱动/武器系统。不开通网络接口。

var throttle: float = 0.0        # [-1, 1]，正 = 前进
var steer: float = 0.0           # [-1, 1]，正 = 右转
var aim_world_point: Vector3 = Vector3.ZERO   # 期望世界瞄点（配合 has_aim_point）
var has_aim_point: bool = false  # 003：显式指定瞄点（脚本命令；零命令不改变现有瞄准）
var clear_aim: bool = false      # 003：清除脚本瞄点（本地玩家每帧清除，回到相机意图）
var aim_held: bool = false       # 炮镜请求（本地玩家右键）
var hold_aim := false           # Observation holds mechanical axes, including on authority.
var aim_intent := AimIntent.new()
var range_requested := false
var apply_range_requested := false
var zeroing_steps := 0
var fire_requested: bool = false
## WT-EXPANSION-01 item B step 4 (site 1 of 3): the SECONDARY weapon rides the same command protocol as every other
## weapon, so its fire intent is a command field rather than a direct call into the gunner. This field is INERT until
## the controller sets it and the simulation honours it - those are sites 2 and 3 and they are not written yet.
var secondary_fire_requested: bool = false
var secondary_fire_index: int = 0
var repair_requested := false
var extinguish_requested := false
var replace_crew_requested := false
var cancel_recovery_requested := false
var cycle_shell_requested := false # Authority cycles its actual installed catalog.
var select_shell: int = -1       # 0..7 选择下一次取弹；-1 保持，不改变膛内或搬运中弹种。

func reset() -> void:
	throttle = 0.0
	steer = 0.0
	aim_world_point = Vector3.ZERO
	has_aim_point = false
	clear_aim = false
	aim_held = false
	hold_aim = false
	aim_intent = AimIntent.new()
	range_requested = false
	apply_range_requested = false
	zeroing_steps = 0
	fire_requested = false
	secondary_fire_requested = false
	secondary_fire_index = 0
	repair_requested = false
	extinguish_requested = false
	replace_crew_requested = false
	cancel_recovery_requested = false
	cycle_shell_requested = false
	select_shell = -1
