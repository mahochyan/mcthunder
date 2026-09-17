class_name ResearchTrialDrive
extends PanelContainer
## Isolated model driving. Speed/turn limits come from the exact vehicle reference
## profile (or its admitted combat packet); unresolved acceleration stays an explicit
## project-design fallback and is never presented as historical data.
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
var design_fallbacks: Array=[]

func configure_mobility() -> bool:
	var result:=ResearchReferenceProfiles.mobility_for(row)
	data_ready=bool(result.get("ok",false))
	if not data_ready: mobility_source=str(result.get("error","unknown")); return false
	forward_max_speed=float(result.forward_max_speed); reverse_max_speed=float(result.reverse_max_speed)
	acceleration=float(result.acceleration); hull_turn_speed=float(result.hull_turn_speed)
	mobility_source=str(result.source_kind); design_fallbacks=result.get("design_fallbacks",[])
	return true

static func advance_speed(current: float,throttle: float,delta: float,forward_limit: float,reverse_limit: float,accel: float) -> float:
	var target:=throttle*(forward_limit if throttle>=0.0 else reverse_limit)
	return move_toward(current,target,accel*delta)

static func yaw_delta(steer: float,delta: float,turn_deg_s: float) -> float:
	return steer*deg_to_rad(turn_deg_s)*delta

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); theme=GarageTheme.theme()
	add_theme_stylebox_override("panel",GarageTheme.box(GarageTheme.INK,Color("303a3e"),18))
	var column := VBoxContainer.new(); column.add_theme_constant_override("separation",12); add_child(column)
	var header := HBoxContainer.new(); column.add_child(header)
	var title := GarageTheme.text(header,row.label+"  /  外观试驾",26); title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	CoreUI.button(header,"复位",reset_vehicle)
	CoreUI.button(header,"暂停 / 继续",func() -> void: paused=not paused)
	close_button=CoreUI.button(header,"返回科技树   ×",queue_free)
	GarageTheme.text(column,"W / S 驾驶     A / D 转向     拖动车辆视图环绕     滚轮缩放",15,GarageTheme.MUTED)
	view=ResearchModelView.new(); view.size_flags_vertical=Control.SIZE_EXPAND_FILL; column.add_child(view)
	if not view.show_vehicle(row):
		GarageTheme.text(column,"模型暂不可用，请返回科技树。",18); return
	if not configure_mobility():
		GarageTheme.text(column,"车型数据未通过身份与哈希校验，试驾已锁定："+mobility_source,18); return
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
	var note:="速度与转向使用该车型缓存参考值；射击与战损尚未开放。"
	if not design_fallbacks.is_empty(): note+=" 加速度为独立游戏设计值。"
	GarageTheme.text(column,note,14,GarageTheme.MUTED)
	ModalNavigation.attach(self,queue_free)
	reset_vehicle()

func reset_vehicle() -> void:
	if not is_instance_valid(vehicle): return
	vehicle.transform=Transform3D.IDENTITY; vehicle.position.y=0.05; vehicle.velocity=Vector3.ZERO; speed=0; paused=false

func _physics_process(delta: float) -> void:
	if not is_instance_valid(vehicle): return
	if not paused:
		var throttle := Input.get_axis("move_back","move_forward")
		speed=advance_speed(speed,throttle,delta,forward_max_speed,reverse_max_speed,acceleration)
		vehicle.rotate_y(yaw_delta(Input.get_axis("turn_right","turn_left"),delta,hull_turn_speed))
		var forward := -vehicle.basis.z
		vehicle.velocity.x=forward.x*speed; vehicle.velocity.z=forward.z*speed
		vehicle.velocity.y=0.0 if vehicle.is_on_floor() else vehicle.velocity.y-12.0*delta
		vehicle.move_and_slide()
		if vehicle.position.length()>140: reset_vehicle()
	view.update_camera(vehicle.position+Vector3(0,view.bounds.size.y*0.5,0),vehicle.rotation.y)
	status.text="已暂停" if paused else "%.1f km/h   ·   %s   ·   %s"%[absf(speed)*3.6,row.label,"战斗包" if mobility_source=="combat_packet" else "缓存参考"]

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT: paused=true
