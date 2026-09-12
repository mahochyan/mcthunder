class_name SimulationSnapshot
extends Node
## Internal authoritative state, not an observer-filtered network message.
const VERSION := 2
var battle: TeamRange
var _latest: Dictionary = {}
var sequence := 0
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_physics_priority = SimulationPhases.SNAPSHOT
func read() -> Dictionary: return _latest.duplicate(true)
func _physics_process(_delta: float) -> void:
	if not is_instance_valid(battle) or not battle.team_ready: return
	if _latest.get("phase","")=="finished" and _latest.get("match_id",-1)==battle.director.state.match_id: return
	var vehicles: Array = []
	for actor in battle.combat_actors():
		vehicles.append({"entity_id":actor.entity_id,"life_id":actor.life_id,"generation":actor.state.generation,
			"control_epoch":actor.control_epoch,"position":actor.tank.global_position,"basis":actor.tank.global_basis,
			"velocity":actor.tank.velocity,"turret_yaw":actor.turret.rotation.y,"gun_pitch":actor.turret.barrel_pivot.rotation.x,
			"frame_pose":VehicleFramePose.capture(actor.tank),
			"suspension":actor.tank.suspension.snapshot(),
			"shots_fired":actor.gunner.shots_fired,"cooldown":actor.gunner.cooldown_left,
			"ammunition":actor.gunner.inventory.shell_counts().duplicate(true),"destroyed":actor.state.destroyed,
			"capabilities":actor.capabilities().duplicate(true)})
	vehicles.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.entity_id<b.entity_id)
	var state := battle.director.state
	sequence += 1
	_latest = {"version":VERSION,"sequence":sequence,"physics_tick":Engine.get_physics_frames(),"match_id":state.match_id,
		"event_sequence":state.event_sequence,
		"phase":state.phase,"elapsed":state.elapsed,"tickets":state.tickets.duplicate(),"capture_owner":state.capture_owner,
		"capture_progress":state.capture_progress,"contested":state.contested,"result":state.result.duplicate(true),"vehicles":vehicles}
