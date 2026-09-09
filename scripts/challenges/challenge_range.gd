class_name ChallengeRange
extends BallisticsRange
signal restart_requested
signal return_requested(result: Dictionary)
var challenge_id := "flank_hunter"
var difficulty := "normal"
var config: Dictionary = {}
var director: ChallengeDirector
var map_definition: MapDefinition
var nav := DriveNavigator.new()
var service: GarageService
var result_panel: PanelContainer
var result_text: Label
var save_text: Label
var restart_button: Button
var return_button: Button
var battle_ui: ChallengeBattleUI
var challenge_ready := false
var _spawned: Dictionary = {}
var _spawn_generations: Dictionary = {}
var _markers: Array[Node3D] = []
func _ready() -> void:
	config = ChallengeCatalog.create(challenge_id,difficulty)
	if config.is_empty(): push_error("Unknown challenge configuration"); return
	selected_vehicle_id = config.vehicle
	super._ready()
	if not _initialized: return
	service = GarageService.new()
	nav.configure(map_definition.graph)
	actor.tank.global_transform = Transform3D(Basis(Vector3.UP,config.yaw),config.start)
	director = ChallengeDirector.new(); add_child(director)
	if not director.begin(self,config): push_error("Challenge configuration rejected"); return
	director.started.connect(_start_playing)
	director.finished.connect(_finish)
	_configure(actor)
	actor.recovery_recorded.connect(director.accept_repair)
	projectiles.shot_record_ready.connect(director.accept_record)
	projectiles.contact_policy = Callable(self,"contact_policy")
	if not spawn_wave(0): push_error("Challenge initial spawn rejected"); return
	actor.cam_rig.cam.current = true
	replay.auto_replay = false
	hud.replay_toggle_button.visible = false
	for signal_name in ["training_requested","armor_training_requested","damage_training_requested","recovery_training_requested"]:
		for connection in hud.get_signal_connection_list(signal_name): hud.disconnect(signal_name,connection.callable)
	hud.training_requested.connect(leave_match)
	hud._training_btn.text = "退出挑战 / 返回车库"
	for button in [hud.armor_training_button,hud.damage_training_button,hud.recovery_training_button]: button.visible = false
	CoreUI.apply(hud)
	_build_ui()
	_build_markers()
	controller.commands_enabled = false; controller.reset_pending()
	challenge_ready = true
	battle_ui = ChallengeBattleUI.new(); add_child(battle_ui); battle_ui.setup(self)
func _build_world() -> void:
	map_definition = MapRegistry.definition(config.map)
	if config.map == "industrial_edge": IndustrialWorld.build(self,map_definition,false)
	else: VillageWorld.build(self,map_definition,false)
func get_round_id() -> int: return director.attempt_id if director != null else 0
func combat_actors() -> Array:
	var rows: Array = []
	for child in get_children():
		if child is VehicleActor and not child.is_queued_for_deletion(): rows.append(child)
	return rows
func find_actor(id: String, life: int) -> VehicleActor:
	for vehicle in combat_actors():
		if vehicle.entity_id == id and vehicle.life_id == life: return vehicle
	return null
func projectile_exclude_rids(id: String, life: int) -> Array[RID]:
	var vehicle := find_actor(id,life)
	var out: Array[RID] = []
	if vehicle != null: out.append(vehicle.tank.get_rid())
	return out
func spawn_wave(index: int) -> bool:
	if director == null or director.phase not in ["countdown","playing"]: return false
	for row in config.enemies:
		if row.wave != index or _spawned.has(row.id): continue
		if combat_actors().size() >= 8: return false
		var occupied: Array[Vector3] = []
		for other in combat_actors(): occupied.append(other.tank.global_position)
		var poses: Array[Transform3D] = [Transform3D(Basis(Vector3.UP,row.yaw),row.position)]
		for point in row.get("alternatives",[]): poses.append(Transform3D(Basis(Vector3.UP,row.yaw),point))
		var check := SpawnSelector.evaluate(get_world_3d().direct_space_state,poses,defs.get_vehicle(row.vehicle).drive_collision_size,occupied)
		if not check.ok: return false
		var vehicle := VehicleActor.new(); vehicle.name = row.id; add_child(vehicle)
		if not vehicle.setup(defs,row.vehicle,row.id,2,check.transform,4,null).ok: vehicle.free(); return false
		_configure(vehicle)
		vehicle.turret.set_aim_point(vehicle.tank.global_position-vehicle.tank.global_basis.z*100+Vector3.UP*2)
		vehicle.turret.snap_to_aim()
		if row.active:
			var ai := AITankController.new(); vehicle.add_child(ai)
			ai.configure(vehicle,nav,Callable(self,"combat_actors"),difficulty,240+index*17)
			ai.advance_while_engaged = true
			ai.set_patrol(config.zone,row.position)
			vehicle.set_controller(ai)
		vehicle.cam_rig.set_process(false); vehicle.cam_rig.set_physics_process(false)
		vehicle.gunner.aim_preview_enabled = false
		_spawned[row.id] = vehicle.life_id
		_spawn_generations[row.id] = vehicle.state.generation
	return true
func _configure(vehicle: VehicleActor) -> void:
	if not service.install(vehicle,ChallengeCatalog.loadout(config,service,vehicle != actor)): push_error("Challenge loadout rejected")
	vehicle.gunner.training_resupply = false
	vehicle.state.recovery_enabled = true
	vehicle.gunner.projectile_manager = projectiles
	vehicle.gunner.snapshot_provider = Callable(self,"query_snapshots")
	vehicle.gunner.round_provider = Callable(self,"get_round_id")
	vehicle.label3d.font = CoreUI.FONT
	var visuals := RecoveryVisuals.new(); vehicle.add_child(visuals); visuals.setup(vehicle)
	vehicle.set_physics_process(director.phase == "playing")
func contact_policy(shooter: Dictionary, contact: Dictionary) -> Dictionary:
	if director == null or director.phase != "playing" or shooter.get("round_id",-1) != get_round_id(): return {"allow":false,"reason":"challenge_not_playing"}
	var target := find_actor(str(contact.get("entity_id","")),int(contact.get("life_id",-1)))
	if target == null or target.state.destroyed: return {"allow":false,"reason":"target_unavailable"}
	if target.state.team_id == shooter.get("shooter_team_id",-1): return {"allow":false,"reason":"friendly_block"}
	return {"allow":true}
func _apply_projectile_damage(event: Dictionary, available: float) -> Dictionary:
	if director == null or director.phase != "playing" or event.get("round_id",-1) != get_round_id(): return {"ok":false,"reason":"challenge_not_playing"}
	var target := find_actor(str(event.get("entity_id","")),int(event.get("life_id",-1)))
	var shooter := find_actor(str(event.get("shooter_id","")),int(event.get("shooter_life_id",-1)))
	if target == null or shooter == null or target.state.destroyed or target.state.team_id == shooter.state.team_id: return {"ok":false,"reason":"target_unavailable"}
	return target.apply_projectile_damage(event,available)
func _start_playing() -> void:
	controller.reset_pending(); controller.require_fire_release(); controller.commands_enabled = true
	for vehicle in combat_actors(): vehicle.set_physics_process(true)
func _finish(outcome: Dictionary) -> void:
	projectiles.close_round()
	for vehicle in combat_actors():
		vehicle.pause_block(true); vehicle.clear_commands(); vehicle.set_physics_process(false)
		vehicle.turret.set_process(false); vehicle.tank.forward_speed = 0; vehicle.tank.velocity = Vector3.ZERO
		vehicle.freeze_wreck()
	controller.commands_enabled = false; controller.reset_pending()
	var reasons := {"objectives_complete":"挑战完成","time_limit":"时间耗尽","player_destroyed":"玩家车辆被击毁","ammunition_empty":"弹药耗尽","flank_required":"靶车击毁，但未确认侧后穿透","abandoned":"主动退出","identity_changed":"车辆身份变更","spawn_blocked":"后续波次出生点被阻挡"}
	result_text.text = "%s · %s\n%d星 / %d分\n%s"%[config.title,reasons.get(outcome.reason,outcome.reason),outcome.stars,outcome.score,outcome.explanation]
	result_panel.visible = true
	get_tree().paused = false; _paused = false; hud.show_pause(false)
	if DisplayServer.get_name() != "headless": Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
func leave_match() -> void:
	if director.phase != "finished": director.finish_once(false,"abandoned")
	return_requested.emit(director.result.duplicate(true))
func retry() -> void:
	if director.phase != "finished": director.finish_once(false,"abandoned")
	restart_requested.emit()
func _unhandled_input(event: InputEvent) -> void:
	if not challenge_ready: return
	if event.is_action_pressed("pause"):
		if director.phase == "finished": leave_match()
		elif _paused: _resume()
		else: _pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("reset"):
		retry(); get_viewport().set_input_as_handled()
func _pause() -> void:
	if director != null and director.phase == "finished": return
	super._pause()
func _resume() -> void:
	super._resume()
	for vehicle in combat_actors():
		vehicle.clear_commands()
		vehicle.gunner.resume_grace = GameConfig.RESUME_GRACE
func _process(_delta: float) -> void:
	if projectiles != null and projectile_visuals != null: projectile_visuals.sync_projectiles(projectiles.active_states())
	if not challenge_ready: return
	for i in _markers.size():
		_markers[i].visible = (i == director.checkpoint) if i < config.route.size() else director.checkpoint == config.route.size()
func _build_ui() -> void:
	result_panel = PanelContainer.new(); hud.add_child(result_panel)
	result_panel.theme = CoreUI.theme()
	result_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	result_panel.offset_left = -320; result_panel.offset_right = 320
	result_panel.offset_top = -245; result_panel.offset_bottom = 245
	result_panel.visible = false
	var content := VBoxContainer.new(); result_panel.add_child(content)
	content.add_theme_constant_override("separation",12)
	result_text = CoreUI.label(content,"",21); result_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_text = CoreUI.label(content,"",17); save_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	CoreUI.label(content,"V 实弹回放 · R 重试 · 成绩不兑换研发点",15)
	restart_button = CoreUI.button(content,"重试挑战",retry)
	return_button = CoreUI.button(content,"返回车库",leave_match)
func _build_markers() -> void:
	if config.id == "flank_hunter": return
	var points: Array = config.route.duplicate()
	points.append(config.zone)
	for i in points.size():
		var root := Node3D.new(); root.position = points[i]; add_child(root); _markers.append(root)
		var mesh := MeshInstance3D.new(); root.add_child(mesh)
		var torus := TorusMesh.new(); var radius := 8.0 if i < config.route.size() else float(config.radius)
		torus.inner_radius = radius-0.1; torus.outer_radius = radius+0.1; torus.rings = 64; torus.ring_segments = 4
		mesh.mesh = torus; mesh.position.y = 0.08
		var material := StandardMaterial3D.new(); material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; material.albedo_color = Color("edcd75"); mesh.material_override = material
		var label := Label3D.new(); root.add_child(label); label.font = CoreUI.FONT; label.font_size = 48; label.position.y = 4
		label.text = "检查点 %d"%(i+1) if i < config.route.size() else "A · 目标区"
