class_name DamageRange
extends BallisticsRange
## Real two-vehicle damage laboratory. X-ray is a read-only training aid.
var source_actor: VehicleActor
var target_actor: VehicleActor
var damage_history: Array[Dictionary] = []
var xray := true
var _markers: Array[Dictionary] = []
var _status: Label
var _damage_round := 1

func _ready() -> void:
	super._ready()
	if not _initialized:
		return
	source_actor = actor
	target_actor = VehicleActor.new()
	target_actor.name = "ActorB"
	add_child(target_actor)
	var result := target_actor.setup(defs,"player_tank","B",2,
		Transform3D(Basis.IDENTITY,Vector3(0,0,-30)),4,null)
	if not result.ok:
		push_error("damage training target failed")
		return
	for vehicle in [source_actor,target_actor]:
		vehicle.set_damage_layout(DamageTrainingLayout.build())
		vehicle.gunner.shell = vehicle.gunner.shell.duplicate(true)
		vehicle.gunner.shell.id = "training_ap120"
		vehicle.gunner.shell.armor_policy = "resolve"
		vehicle.gunner.shell.penetration_curve = PackedVector2Array([Vector2(0,120),Vector2(200,120)])
		vehicle.gunner.projectile_manager = projectiles
		vehicle.gunner.snapshot_provider = Callable(self,"query_snapshots")
		vehicle.gunner.round_provider = Callable(self,"get_round_id")
		_build_markers(vehicle)
	hud.damage_training_button.visible = false
	hud.impact_label.visible = false
	_build_panel()

func _build_world() -> void:
	_add_wall(Vector3(0,-0.3,-25),Vector3(90,0.6,110))
	_add_wall(Vector3(0,4,-50),Vector3(50,8,0.5))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50,-25,0)
	sun.light_energy = 1.3
	add_child(sun)
	var we := WorldEnvironment.new()
	we.environment = Environment.new()
	we.environment.background_mode = Environment.BG_COLOR
	we.environment.background_color = Color("#8caebe")
	we.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.environment.ambient_light_color = Color("#b0bdc5")
	we.environment.ambient_light_energy = 0.8
	add_child(we)

func _build_panel() -> void:
	var panel := PanelContainer.new()
	hud.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -356
	panel.offset_right = -16
	panel.offset_top = 70
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,12)
	panel.add_child(margin)
	_status = Label.new()
	_status.custom_minimum_size.x = 316
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size",16)
	margin.add_child(_status)

func _build_markers(vehicle: VehicleActor) -> void:
	var layout := vehicle.damage_layout_override
	for kind in ["module","crew"]:
		var items: Array = layout.modules if kind == "module" else layout.crew_stations
		for item in items:
			var mesh := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = item.size_m
			mesh.mesh = box
			mesh.transform = item.local_box_transform
			mesh.layers = vehicle.tank.visual_layer
			var mat := StandardMaterial3D.new()
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.no_depth_test = true
			mesh.material_override = mat
			DamageTrainingLayout.part_node(vehicle,item.part_id).add_child(mesh)
			_markers.append({"actor":vehicle,"kind":kind,"id":item.id,"mesh":mesh,"mat":mat})

func get_round_id() -> int:
	return _damage_round

func projectile_exclude_rids(shooter_id: String, shooter_life_id: int) -> Array[RID]:
	for vehicle in [source_actor,target_actor]:
		if is_instance_valid(vehicle) and vehicle.entity_id == shooter_id and vehicle.life_id == shooter_life_id:
			return [vehicle.tank.get_rid()]
	return []

func switch_control() -> void:
	if _paused or not is_instance_valid(target_actor):
		return
	actor.set_controller(null)
	controller.reset_pending()
	controller.require_fire_release()
	actor = target_actor if actor == source_actor else source_actor
	actor.set_controller(controller)
	actor.gunner.resume_grace = GameConfig.RESUME_GRACE
	for vehicle in [source_actor,target_actor]:
		vehicle.label3d.text = vehicle.entity_id + (" (PLAYER)" if vehicle == actor else " (TARGET)")

func _on_projectile_damage(record: Dictionary) -> void:
	super._on_projectile_damage(record)
	damage_history.append(record.duplicate(true))
	if damage_history.size() > 32:
		damage_history.pop_front()

func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(target_actor) or _status == null:
		return
	hud.control_label.text = "DAMAGE RANGE · CONTROL %s · Tab switch" % actor.entity_id
	hud.hint_label.text = "W/S drive  A/D turn  Mouse aim  LMB fire\nTab switch A/B  X training X-ray\nR restart both vehicles  Esc menu"
	for marker in _markers:
		var vehicle: VehicleActor = marker.actor
		var healthy := true
		if marker.kind == "module":
			healthy = vehicle.state.module_states[marker.id].integrity > 0
		else:
			healthy = vehicle.state.role_available(vehicle.state.station_roles[marker.id])
		marker.mesh.visible = xray and vehicle != actor
		marker.mat.albedo_color = Color(0.2,0.9,0.65,0.42) if healthy else Color(1,0.15,0.12,0.7)
	var observed := target_actor
	var state := observed.state
	var caps := observed.capabilities()
	var lines: Array[String] = ["TARGET B · %s" % ("DISABLED" if state.destroyed else "OPERATIONAL"),
		"DESIGNED TEST VALUES · AP 120 mm", "X-RAY %s · Tab: operate damaged B" % ("ON" if xray else "OFF"), ""]
	for id in state.module_states:
		lines.append("%s: %.0f%%" % [str(id).replace("_"," "),state.module_states[id].integrity])
	lines.append("\nCREW: %d / 5" % state.alive_crew_count())
	for id in state.crew_states:
		lines.append("%s: %s" % [str(id).replace("_"," "),"READY" if state.crew_states[id].alive else "OUT"])
	lines.append("\nDrive %s · Fire %s · Reload %.0f%%" % ["YES" if caps.drive else "NO","YES" if caps.fire else "NO",caps.reload_rate*100])
	if not damage_history.is_empty():
		var r: Dictionary = damage_history.back()
		lines.append("\nLast: %s / %s" % [r.target_id,r.item_id])
		lines.append(str(r.reason).replace("_"," ").to_upper())
	_status.text = "\n".join(lines)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and not _paused:
		if event.keycode == KEY_TAB:
			switch_control()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_X:
			xray = not xray
			return
	if event.is_action_pressed("toggle_target"):
		return
	super._unhandled_input(event)

func _reset_range() -> void:
	if not is_instance_valid(target_actor):
		return
	projectiles.cancel_all("cancelled_reset")
	_damage_round += 1
	for vehicle in [source_actor,target_actor]:
		vehicle.reset_vehicle()
	damage_history.clear()
	_last_impact.clear()
	_terminated_pids.clear()
	projectile_visuals.clear_all()
