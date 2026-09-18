class_name ResearchTrialDrive
extends PanelContainer
## Isolated model driving. Speed/turn limits come from the exact vehicle reference
## profile (or its admitted combat packet). The active gameplay ruleset is arcade;
## cache arcade power multipliers scale an explicit project base acceleration.
var row: Dictionary
var view: ResearchModelView
var vehicle: CharacterBody3D
var status: Label
var paused := false
var speed := 0.0
var close_button: Button
var data_ready := false
var forward_max_speed := 0.0
var reverse_max_speed := 0.0
var acceleration := 0.0
var hull_turn_speed := 0.0
var mobility_source := ""
var gameplay_mode := ""
var arcade_power_multiplier := 1.0
var design_fallbacks: Array=[]
var turret_pivot: Node3D
var gun_pivot: Node3D
var turret_yaw_deg:=0.0
var gun_pitch_deg:=0.0
var turret_yaw_speed:=0.0
var gun_pitch_speed:=0.0
var turret_yaw_min:=-180.0
var turret_yaw_max:=180.0
var gun_pitch_min:=-8.0
var gun_pitch_max:=20.0
var weapon_controls_available:=false
var weapon_control_status:="none"

func configure_mobility() -> bool:
	var result:=ResearchReferenceProfiles.mobility_for(row)
	data_ready=bool(result.get("ok",false))
	if not data_ready: mobility_source=str(result.get("error","unknown")); return false
	forward_max_speed=float(result.forward_max_speed); reverse_max_speed=float(result.reverse_max_speed)
	acceleration=float(result.acceleration); hull_turn_speed=float(result.hull_turn_speed)
	mobility_source=str(result.source_kind); design_fallbacks=result.get("design_fallbacks",[])
	gameplay_mode=str(result.get("gameplay_mode","")); arcade_power_multiplier=float(result.get("arcade_power_multiplier",1.0))
	return true

static func advance_speed(current: float,throttle: float,delta: float,forward_limit: float,reverse_limit: float,accel: float) -> float:
	var target:=throttle*(forward_limit if throttle>=0.0 else reverse_limit)
	return move_toward(current,target,accel*delta)

static func yaw_delta(steer: float,delta: float,turn_deg_s: float) -> float:
	return steer*deg_to_rad(turn_deg_s)*delta

static func advance_axis(current: float,input: float,speed_deg_s: float,delta: float,minimum: float,maximum: float) -> float:
	return clampf(current+input*speed_deg_s*delta,minimum,maximum)

func configure_model_interface() -> bool:
	var interface:=ResearchModelInterfaces.interface_for(row)
	if not interface.get("ok",false): mobility_source=str(interface.get("error","model_interface_unknown")); return false
	weapon_control_status=str(interface.get("weapon_control","none"))
	weapon_controls_available=weapon_control_status=="yaw_pitch"
	if not weapon_controls_available:
		return true
	var motion:=ResearchReferenceProfiles.weapon_motion_for(row)
	if not motion.get("ok",false): mobility_source=str(motion.get("error","weapon_motion_unknown")); return false
	var nodes: Dictionary=interface.nodes
	turret_pivot=view.model.find_child(str(nodes.turret_pivot),true,false) as Node3D
	gun_pivot=view.model.find_child(str(nodes.gun_pivot),true,false) as Node3D
	if not is_instance_valid(turret_pivot) or not is_instance_valid(gun_pivot): mobility_source="model_interface_nodes_missing"; return false
	turret_yaw_speed=float(motion.yaw_speed); gun_pitch_speed=float(motion.pitch_speed)
	turret_yaw_min=float(motion.yaw_min); turret_yaw_max=float(motion.yaw_max)
	gun_pitch_min=float(motion.pitch_min); gun_pitch_max=float(motion.pitch_max)
	for fallback in motion.get("design_fallbacks",[]):
		if fallback not in design_fallbacks: design_fallbacks.append(fallback)
	return true

func _apply_weapon_pose() -> void:
	if weapon_controls_available and is_instance_valid(turret_pivot): turret_pivot.rotation.y=deg_to_rad(turret_yaw_deg)
	if weapon_controls_available and is_instance_valid(gun_pivot): gun_pivot.rotation.x=deg_to_rad(gun_pitch_deg)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); theme=GarageTheme.theme()
	add_theme_stylebox_override("panel",GarageTheme.box(GarageTheme.INK,Color("303a3e"),18))
	var column := VBoxContainer.new(); column.add_theme_constant_override("separation",12); add_child(column)
	var header := HBoxContainer.new(); column.add_child(header)
	var title := GarageTheme.text(header,row.label+"  /  外观试驾",26); title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	CoreUI.button(header,"复位",reset_vehicle)
	CoreUI.button(header,"暂停 / 继续",func() -> void: paused=not paused)
	close_button=CoreUI.button(header,"返回科技树   ×",queue_free)
	var controls_help:=GarageTheme.text(column,"W / S 驾驶     A / D 转向     拖动车辆视图环绕",15,GarageTheme.MUTED)
	view=ResearchModelView.new(); view.size_flags_vertical=Control.SIZE_EXPAND_FILL; column.add_child(view)
	if not view.show_vehicle(row):
		GarageTheme.text(column,"模型暂不可用，请返回科技树。",18); return
	if not configure_mobility():
		GarageTheme.text(column,"车型数据未通过身份与哈希校验，试驾已锁定："+mobility_source,18); return
	if not configure_model_interface():
		GarageTheme.text(column,"模型接口未通过节点与哈希校验，试驾已锁定："+mobility_source,18); return
	if weapon_controls_available:
		controls_help.text="W / S 驾驶     A / D 转向     方向键控制炮塔 / 火炮     拖动车辆视图环绕"
	vehicle=CharacterBody3D.new(); vehicle.collision_layer=2; vehicle.collision_mask=1; view.viewport.add_child(vehicle)
	view.model.reparent(vehicle)
	var shape := CollisionShape3D.new(); var box := BoxShape3D.new()
	box.size=Vector3(maxf(view.bounds.size.x,0.5),maxf(view.bounds.size.y*0.6,0.4),maxf(view.bounds.size.z*0.65,1.0))
	shape.shape=box; shape.position=Vector3(0,box.size.y*0.5,0); vehicle.add_child(shape)
	var floor_body := StaticBody3D.new(); floor_body.collision_layer=1; view.viewport.add_child(floor_body)
	var floor_shape := CollisionShape3D.new(); var floor_box := BoxShape3D.new(); floor_box.size=Vector3(500,0.2,500)
	floor_shape.shape=floor_box; floor_shape.position.y=-0.1; floor_body.add_child(floor_shape)
	for x in [-6.0,6.0]:
		for z in range(-80,81,8): CoreVehicleVisual.box(view.stage,Vector3(x,0.01,z),Vector3(0.09,0.015,4),Color("a49d7e"))
	status=GarageTheme.text(column,"",16,GarageTheme.ACCENT)
	var note:="街机规则：速度与转向使用该车型缓存参考值，动力倍率 ×%.2f；射击与战损尚未开放。"%arcade_power_multiplier
	if weapon_control_status=="none": note+=" 该车型模型没有可控武器。"
	elif weapon_control_status=="unavailable_nonstandard": note+=" 非标准武器机构尚未声明控制适配，不会套用坦克炮塔参数。"
	if not design_fallbacks.is_empty(): note+=" 未解析字段使用明确登记的试驾设计值。"
	GarageTheme.text(column,note,14,GarageTheme.MUTED)
	ModalNavigation.attach(self,queue_free)
	reset_vehicle()

func reset_vehicle() -> void:
	if not is_instance_valid(vehicle): return
	vehicle.transform=Transform3D.IDENTITY; vehicle.position.y=0.05; vehicle.velocity=Vector3.ZERO; speed=0; paused=false
	turret_yaw_deg=clampf(0.0,turret_yaw_min,turret_yaw_max); gun_pitch_deg=clampf(0.0,gun_pitch_min,gun_pitch_max); _apply_weapon_pose()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(vehicle): return
	if not paused:
		var throttle := Input.get_axis("move_back","move_forward")
		speed=advance_speed(speed,throttle,delta,forward_max_speed,reverse_max_speed,acceleration)
		vehicle.rotate_y(yaw_delta(Input.get_axis("turn_right","turn_left"),delta,hull_turn_speed))
		if weapon_controls_available:
			turret_yaw_deg=advance_axis(turret_yaw_deg,Input.get_axis("ui_left","ui_right"),turret_yaw_speed,delta,turret_yaw_min,turret_yaw_max)
			gun_pitch_deg=advance_axis(gun_pitch_deg,Input.get_axis("ui_down","ui_up"),gun_pitch_speed,delta,gun_pitch_min,gun_pitch_max)
			_apply_weapon_pose()
		var forward := -vehicle.basis.z
		vehicle.velocity.x=forward.x*speed; vehicle.velocity.z=forward.z*speed
		vehicle.velocity.y=0.0 if vehicle.is_on_floor() else vehicle.velocity.y-12.0*delta
		vehicle.move_and_slide()
		if vehicle.position.length()>140: reset_vehicle()
	view.update_camera(vehicle.position+Vector3(0,view.bounds.size.y*0.5,0),vehicle.rotation.y)
	if paused: status.text="已暂停"
	elif weapon_controls_available: status.text="%.1f km/h   ·   炮塔 %.1f° / 火炮 %.1f°   ·   %s"%[absf(speed)*3.6,turret_yaw_deg,gun_pitch_deg,row.label]
	else: status.text="%.1f km/h   ·   %s   ·   %s"%[absf(speed)*3.6,"无武器控制" if weapon_control_status=="none" else "武器接口待适配",row.label]

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT: paused=true
