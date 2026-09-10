class_name RecoveryRange
extends DamageRange
static var SCENARIOS := [LocalizationService.text("ui_852b1fe2ad3a"),LocalizationService.text("ui_b21c9a0595ba"),LocalizationService.text("ui_ea0d7e544caa"),LocalizationService.text("ui_fe6e620fe076"),LocalizationService.text("ui_ef10c689ce16")]
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
	_aim_marker.font = CoreUI.FONT
	_aim_marker.text = LocalizationService.text("ui_01b5d38f8a04")
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
	hud.control_label.text = LocalizationService.text("ui_a461bd95d70a") % actor.entity_id
	hud.hint_label.text = LocalizationService.text("ui_b397ed349143")
	var lines: Array[String] = ["%d / %s" % [scenario+1,SCENARIOS[scenario]],
		LocalizationService.text("ui_7cc68206de8f"), LocalizationService.text("ui_7591d9870777"),LocalizationService.text("ui_82ca13076600"), LocalizationService.text("ui_ab9a2526500b"), LocalizationService.text("ui_ebb0f8ad476b"),"",
		"B: %s" % (LocalizationService.status("DESTROYED") if state.destroyed else (LocalizationService.text("ui_643a5427ec28") if not state.fires.is_empty() else LocalizationService.status("ALIVE"))),
		LocalizationService.text("ui_c22b0ba502d7") % [state.module_states.track_left.integrity,state.module_states.engine.integrity,state.module_states.breech.integrity],
		LocalizationService.text("ui_e606f3427bfb") if state.destroyed else LocalizationService.text("ui_cc37678b29bf") % [state.alive_crew_count(),LocalizationService.status("READY") if state.role_available("gunner") else LocalizationService.status("OUT")],
		LocalizationService.text("ui_5213faf6c642") % [LocalizationService.status("YES") if caps.drive else LocalizationService.status("NO"),LocalizationService.status("YES") if caps.fire else LocalizationService.status("NO")],
		LocalizationService.text("ui_cfae55082a13") % [target_actor.gunner.inventory.racks.get("ammo_rack",0),target_actor.gunner.inventory.chamber,target_actor.gunner.inventory.in_transfer],
		"", LocalizationService.text("ui_3de5496e3b06") % [actor.entity_id,controlled.extinguisher_charges]]
	if not controlled.recovery_action.is_empty():
		var duration := RecoveryRules.REPAIR_SECONDS
		if controlled.recovery_action == "extinguish": duration = RecoveryRules.EXTINGUISH_SECONDS
		if controlled.recovery_action == "replace": duration = RecoveryRules.REPLACEMENT_SECONDS
		lines.append("%s %s" % [controlled.recovery_action.to_upper(),controlled.action_target.replace("_"," ")])
		lines.append("%.1f / %.1f s" % [controlled.action_progress,duration])
	else:
		lines.append(LocalizationService.text("ui_95b5d82dfd8c"))
	if not controlled.recovery_reason.is_empty(): lines.append(controlled.recovery_reason.replace("_"," ").to_upper())
	if state.destroyed:
		lines.append(LocalizationService.text("ui_a3456b96efdf")+str(state.death_record.cause).replace("_"," "))
		lines.append(LocalizationService.text("ui_1a5ac0bd0b6b")+str(state.death_record.source.get("shooter_id","environment")))
		lines.append(LocalizationService.text("ui_bace21e831ad"))
	elif not damage_history.is_empty():
		lines.append(LocalizationService.text("ui_29043208f731")+str(damage_history.back().item_id).replace("_"," "))
	_status.text = "\n".join(lines)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and not _paused:
		var selected := InputBindingService.scenario_index(event,5)
		if selected >= 0:
			select_scenario(selected)
			get_viewport().set_input_as_handled()
			return
	super._unhandled_input(event)

func _reset_range() -> void:
	select_scenario(scenario)

func input_context() -> String: return "recovery"
