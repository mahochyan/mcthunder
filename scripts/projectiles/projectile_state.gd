class_name ProjectileState
extends RefCounted
## 006：单发炮弹的独立运行数据（不持有车辆 Node；管理器唯一推进方）。
## 发射时冻结初速/重力/路程上限等数值——飞行中不读取后来修改的配置。

var projectile_id := 0          # 管理器生成的单调编号
var round_id := 0               # 发射时刻任务轮次（冻结）
var shooter_id := ""            # 发射者实体标识（冻结）
var shooter_life_id := 0        # 发射者生命周期标识（冻结）
var shooter_team_id := 0        # 发射者队伍（冻结）
var shot_id := 0                # 发射者射击编号（冻结）
var shell_id := ""              # 弹种标识（冻结）
var seed := 0                   # 预留；006 不加入随机散布
var armor_policy := "resolve"
var penetration_curve := PackedVector2Array()
var budget_scale := 1.0
var consumed_mm := 0.0
var ricochets := 0
var contacts: Array[Dictionary] = []
var start_surfaces: Dictionary = {}
var contacted_targets: Dictionary = {}
var interior_targets: Dictionary = {}
var damage_seen: Dictionary = {}
var damage_records: Array[Dictionary] = []

var born_physics_tick := 0      # 出生物理 tick（出生当步不推进）
var position_world := Vector3.ZERO
var previous_position_world := Vector3.ZERO
var velocity_world := Vector3.ZERO
var gravity_world := Vector3.ZERO

var age_s := 0.0                # 已飞行模拟时间
var travelled_m := 0.0          # 已累计路程（分段折线长度近似）
var max_age_s := 0.0            # 最大飞行时间（发射时冻结）
var max_distance_m := 0.0       # 最大累计路程（发射时冻结 = gun_range）
var status := "pending"         # pending / flying / terminal
var terminal_reason := ""       # 终止原因（见管理器 finish_once）

func is_terminal() -> bool:
	return status == "terminal"
