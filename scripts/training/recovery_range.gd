class_name RecoveryRange
extends DamageRange
const SCENARIOS := ["TRACK / REPAIR","ENGINE / EXTINGUISH","GUNNER / REPLACE","LOADED RACK","EMPTY RACK"]
var scenario := 0
var wrecks: WreckRegistry
var death_history: Array[Dictionary] = []
var _aim_marker: Label3D
var _recovery_ready := false

func _ready() -> void:
	super._ready()
	if not is_instance_valid(target_actor): return
	for vehicle in [source_actor,target_actor]:
		vehicle.set_damage_layout(DamageTrainingLayout.build(true))
		vehicle.vehicle_destroyed.connect(_on_destroyed.bind(vehicle))
		var visuals := RecoveryVisuals.new()
		vehicle.add_child(visuals)
		visuals.setup(vehicle)
	wrecks = WreckRegistry.new()
	add_child(wrecks)
	# This fixed two-actor lesson preserves both vehicles until an explicit new scenario.
	# Other scenes may protect only their currently controlled actor. Population here is always two.
	wrecks.protected_provider = func(vehicle: VehicleActor) -> bool: return vehicle in [source_actor,target_actor]
	hud.recovery_training_button.visible = false
	_aim_marker = Label3D.new()
	_aim_marker.text = "SHOOT HERE"
	_aim_marker.font_size = 32
	_aim_marker.modulate = Color("#ffe27a")
	_aim_marker.no_depth_test = true
	add_child(_aim_marker)
	_recovery_ready = true
	select_scenario(0)

func select_scenario(index: int) -> void:
	if not _recovery_ready or index < 0 or index >= SCENARIOS.size() or _paused: return
	if actor != source_actor: switch_control()
	scenario = index
	super._reset_range()
	wrecks.clear_tracking()
	death_history.clear()
	# Explicit new-scenario initial loadout. This is not a hit or recovery operation.
	target_actor.gunner.rounds_remaining = 0 if scenario == 4 else target_actor.gunner.weapon.initial_rounds
	controller.require_fire_release()

func target_point() -> Vector3:
	var local: Vector3
	match scenario:
		0: local = Vector3(-1.25,0.4,1.9)
		1: local = Vector3(0,0.95,1.0)
		2: local = Vector3(-0.46,1.7,-0.2)
		_: local = Vector3(0.72,0.95,0.35)
	return target_actor.tank.global_transform*local

func _on_destroyed(record: Dictionary, vehicle: VehicleActor) -> void:
	death_history.append(record.duplicate(true))
	wrecks.register(vehicle)

func _process(delta: float) -> void:
	super._process(delta)
	if not _recovery_ready: return
	var state := target_actor.state
	var controlled := actor.state
	var caps := target_actor.capabilities()
	_aim_marker.visible = actor == source_actor and damage_history.is_empty()
	_aim_marker.position = target_point()+Vector3(0,0.5,0)
	hud.control_label.text = "RECOVERY RANGE · CONTROL %s" % actor.entity_id
	hud.hint_label.text = "W/S drive  A/D turn  Mouse aim  LMB fire\nTab control A/B  T repair  F extinguish  C replace crew\nG cancel  1-5 new scenario  X X-ray  R restart  Esc menu"
	var lines: Array[String] = ["%d / %s" % [scenario+1,SCENARIOS[scenario]],
		"DESIGNED TEST VALUES · AP120", "Shoot B, then Tab to operate B.","1 Track  2 Fire  3 Crew", "4 Loaded rack  5 Empty rack", "Selecting a case starts a new round.","",
		"B: %s" % ("DESTROYED" if state.destroyed else ("ON FIRE" if not state.fires.is_empty() else "ALIVE")),
		"Track %.0f%%  Engine %.0f%%  Breech %.0f%%" % [state.module_states.track_left.integrity,state.module_states.engine.integrity,state.module_states.breech.integrity],
		"Crew: vehicle lost" if state.destroyed else "Crew %d/5 · Gunner %s" % [state.alive_crew_count(),"READY" if state.role_available("gunner") else "OUT"],
		"Drive %s · Fire %s" % ["YES" if caps.drive else "NO","YES" if caps.fire else "NO"],
		"B rack: %d · chamber: %d · loading: %d" % [target_actor.gunner.inventory.racks.get("ammo_rack",0),target_actor.gunner.inventory.chamber,target_actor.gunner.inventory.in_transfer],
		"", "CONTROL %s · extinguishers %d/2" % [actor.entity_id,controlled.extinguisher_charges]]
	if not controlled.recovery_action.is_empty():
		var duration := RecoveryRules.REPAIR_SECONDS
		if controlled.recovery_action == "extinguish": duration = RecoveryRules.EXTINGUISH_SECONDS
		if controlled.recovery_action == "replace": duration = RecoveryRules.REPLACEMENT_SECONDS
		lines.append("%s %s" % [controlled.recovery_action.to_upper(),controlled.action_target.replace("_"," ")])
		lines.append("%.1f / %.1f s" % [controlled.action_progress,duration])
	else:
		lines.append("T repair · F extinguish · C replace")
	if not controlled.recovery_reason.is_empty(): lines.append(controlled.recovery_reason.replace("_"," ").to_upper())
	if state.destroyed:
		lines.append("\nCause: "+str(state.death_record.cause).replace("_"," "))
		lines.append("Source: "+str(state.death_record.source.get("shooter_id","environment")))
		lines.append("Wreck remains cover. R starts over.")
	elif not damage_history.is_empty():
		lines.append("\nLast hit: "+str(damage_history.back().item_id).replace("_"," "))
	_status.text = "\n".join(lines)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and not _paused:
		if event.keycode >= KEY_1 and event.keycode <= KEY_5:
			select_scenario(event.keycode-KEY_1)
			get_viewport().set_input_as_handled()
			return
	super._unhandled_input(event)

func _reset_range() -> void:
	select_scenario(scenario)
