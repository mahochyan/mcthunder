class_name NetworkClientView
extends Node3D
var connection := NetworkBattleClient.new()
var actors: Dictionary = {}
var player := PlayerController.new()
var owned: VehicleActor
var own_generation := -1
var own_identity: Dictionary = {}
var status_label: Label
var details_label: Label
var optics_label: Label
var last_event := "尚无命中结果"
var port := 19109
var pending := CommandMailbox.new()
var pending_since := 0
var pose_buffer := NetworkPoseBuffer.new()
func _ready() -> void:
	process_priority=-10 # Move displayed replicas before their cameras update.
	InputBindingService.initialize()
	var ground := StaticBody3D.new(); add_child(ground)
	var shape := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size=Vector3(6000,1,6000)
	shape.shape=box; shape.position.y=-0.5; ground.add_child(shape)
	var mesh := MeshInstance3D.new(); var plane := PlaneMesh.new(); plane.size=Vector2(6000,6000)
	mesh.mesh=plane; var material := StandardMaterial3D.new(); material.albedo_color=Color(0.32,0.38,0.26); mesh.material_override=material; add_child(mesh)
	var light := DirectionalLight3D.new(); light.rotation_degrees=Vector3(-55,-25,0); add_child(light)
	var environment := WorldEnvironment.new(); environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR; environment.environment.background_color=Color(0.58,0.7,0.79)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; environment.environment.ambient_light_color=Color.WHITE; environment.environment.ambient_light_energy=0.7; add_child(environment)
	var defs := VehicleDefs.new(); defs.load_defaults(); VehicleCatalog.new().load_all(defs)
	for i in 2:
		var actor := VehicleActor.new(); add_child(actor)
		var id := "A" if i==0 else "B"
		actor.setup(defs,VehicleCatalog.IDS[i],id,i+1,Transform3D.IDENTITY,1<<(i+1),null)
		actor.label3d.text=id
		actor.set_physics_process(false) # Remote replica never drives, reloads or fires locally.
		actor.tank.set_process(false)
		actors[id]=actor
	add_child(player)
	connection.snapshot_received.connect(apply_snapshot)
	connection.disconnected.connect(connection_lost)
	add_child(connection)
	build_ui()
	connection.connect_local(port)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
func build_ui() -> void:
	var layer := CanvasLayer.new(); add_child(layer)
	var panel := PanelContainer.new(); panel.position=Vector2(16,16); panel.custom_minimum_size=Vector2(600,90); layer.add_child(panel)
	var column := VBoxContainer.new(); panel.add_child(column)
	status_label=Label.new(); status_label.add_theme_font_override("font",CoreUI.FONT); column.add_child(status_label)
	details_label=Label.new(); details_label.add_theme_font_override("font",CoreUI.FONT); column.add_child(details_label)
	optics_label=Label.new(); optics_label.add_theme_font_override("font",CoreUI.FONT); column.add_child(optics_label)
	var cross := Label.new(); cross.text="+"; cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER); layer.add_child(cross)
	var help := Label.new(); help.add_theme_font_override("font",CoreUI.FONT)
	help.text=InputBindingService.driving_hint()+LocalizationService.text("optics_hint")+"\nEsc 释放鼠标/暂停输入 · Enter 继续 · R 重新连接"
	help.position=Vector2(16,120); layer.add_child(help)
func clear_input() -> void:
	pending.clear(); player.commands_enabled=false; player.require_fire_release()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
func connection_lost() -> void:
	clear_input()
	pose_buffer.clear()
	own_identity.clear(); own_generation=-1
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE: clear_input()
		if event.keycode==KEY_ENTER and owned!=null:
			player.commands_enabled=true; player.require_fire_release(); Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		if event.keycode==KEY_R:
			clear_input()
			pose_buffer.clear()
			if owned!=null: owned.set_controller(null); owned.label3d.visible=true
			owned=null; own_generation=-1; own_identity.clear(); connection.connect_local(port)
func apply_snapshot(snapshot: Dictionary) -> void:
	if not pose_buffer.push(snapshot): return
	if connection.status=="finished":
		pose_buffer.render_tick=float(snapshot.tick)
		clear_input()
	if not snapshot.events.is_empty():
		var event: Dictionary=snapshot.events[-1]
		var reason: String={"impact_world":"击中地面或掩体","impact_vehicle":"命中车辆","expired_distance":"炮弹超出射程","expired_time":"炮弹飞行结束","cancelled_match_finished":"训练结束"}.get(str(event.reason),"弹道已结束")
		last_event="%s 第%d发：%s"%[event.shooter_id,event.shot_id,reason]
	for row in snapshot.vehicles:
		if not actors.has(row.entity_id): continue
		var actor: VehicleActor=actors[row.entity_id]
		actor.state.destroyed=row.destroyed
		if row.entity_id==connection.entity_id:
			if owned!=actor:
				if owned!=null: owned.set_controller(null); owned.label3d.visible=true
				owned=actor; own_generation=-1; own_identity.clear(); owned.set_controller(player); owned.label3d.visible=false; player.commands_enabled=true; player.require_fire_release()
			var identity := {"life_id":int(row.life_id),"generation":int(row.generation),"control_epoch":int(row.control_epoch)}
			if own_identity!=identity:
				own_identity=identity
				own_generation=int(row.generation)
				owned.cam_rig.reset_optics(); player.reset_pending(); player.require_fire_release(); pending.clear()
			var stats := connection.own_status
			owned.fire_control.apply_snapshot(stats.fire_control)
			details_label.text="炮弹余 %d 发 · 装填 %.1f 秒 · 速度 %.1f km/h · 已射击 %d 发\n%s · %s"%[stats.get("ammo",0),stats.get("cooldown",0),absf(float(stats.get("speed",0)))*3.6,row.shots,"车辆已失能" if row.destroyed else "车辆可操作",last_event]
func _process(delta: float) -> void:
	if owned!=null: optics_label.text=owned.cam_rig.optics_text()
	for row in pose_buffer.advance(delta):
		if not actors.has(row.entity_id): continue
		var actor: VehicleActor=actors[row.entity_id]
		actor.tank.global_position=Vector3(row.position[0],row.position[1],row.position[2])
		actor.tank.global_rotation=Vector3(row.get("hull_pitch",0),row.yaw,row.get("hull_roll",0))
		VehicleFramePose.apply(actor.tank,row.frame_pose)
		actor.turret.rotation.y=row.turret_yaw; actor.turret.barrel_pivot.rotation.x=row.gun_pitch
func _physics_process(_delta: float) -> void:
	var label: String={"connecting":"正在连接","connected":"已连接","disconnected":"连接已断开，按 R 重试","finished":"训练已结束"}.get(connection.status,connection.status)
	status_label.text="本机联网训练 · %s · 控制车辆 %s"%[label,connection.entity_id]
	if owned==null or connection.status!="connected": return
	var command := player.poll()
	owned.cam_rig.set_sight_requested(command.aim_held)
	owned.cam_rig.refresh_intent()
	# Submit the player's angular optical intention. Only authority queries its
	# own geometry and range; a client world point is not an authoritative fact.
	command.clear_aim=true; command.has_aim_point=false
	if pending.has_staged() and Time.get_ticks_msec()-pending_since>200: pending.clear()
	if not pending.has_staged(): pending_since=Time.get_ticks_msec()
	pending.submit(command) # Preserve short fire edges between 20Hz send opportunities.
	if int(connection.latest.get("tick",-1))!=connection.last_sent_tick:
		connection.submit(pending.consume())
func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(player): clear_input()
