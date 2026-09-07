class_name VehicleRuntimeState
extends RefCounted
## 003：车辆运行时状态（每实例独立，禁止放进共享车型 Resource）。
## 速度/炮塔/装填/计数/模块占位状态全部在此；重置只改本实例。

var entity_id: String = ""
var team_id: int = 0
var definition_id: String = ""

# --- movement ---
var forward_speed: float = 0.0

# --- turret ---
var turret_yaw: float = 0.0
var gun_pitch: float = 0.0

# --- weapon ---
var cooldown_left: float = 0.0
var resume_grace: float = 0.0
var shots_fired: int = 0
var last_shot_result: String = ""   # "" / "hit" / "miss" / "blocked:cooldown" / "blocked:grace" / "blocked:barrel_occluded"

# --- 命中/损伤占位（004 装甲/内构用） ---
var hits_taken: int = 0
var module_states: Dictionary = {}   # module_id -> 占位状态
var destroyed: bool = false

func reset() -> void:
	forward_speed = 0.0
	turret_yaw = 0.0
	gun_pitch = 0.0
	cooldown_left = 0.0
	resume_grace = 0.0
	shots_fired = 0
	last_shot_result = ""
	hits_taken = 0
	module_states.clear()
	destroyed = false
