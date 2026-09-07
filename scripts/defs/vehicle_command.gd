class_name VehicleCommand
extends RefCounted
## 003：统一控制命令。PlayerController 与（未来）AIController 只生成命令；
## VehicleActor 负责限制输入并调用相同驱动/武器系统。不开通网络接口。

var throttle: float = 0.0        # [-1, 1]，正 = 前进
var steer: float = 0.0           # [-1, 1]，正 = 右转
var aim_world_point: Vector3 = Vector3.ZERO   # 期望世界瞄点（ZERO = 不指定，用默认意图）
var fire_requested: bool = false
var select_shell: int = -1       # 003 首版仅单弹种，-1 = 不切换

func reset() -> void:
	throttle = 0.0
	steer = 0.0
	aim_world_point = Vector3.ZERO
	fire_requested = false
	select_shell = -1
