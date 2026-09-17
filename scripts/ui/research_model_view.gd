class_name ResearchModelView
extends SubViewportContainer
## Raw GLB snapshots load in exports as well as in the editor; no external paths at runtime.
var viewport: SubViewport
var model: Node3D
var camera: Camera3D
var bounds := AABB()
var model_id := ""
var yaw := 0.62
var pitch := 0.28
var distance := 12.0
var stage: Node3D

func _ready() -> void:
	stretch=true; custom_minimum_size=Vector2(200,190)
	viewport=SubViewport.new(); viewport.own_world_3d=true; viewport.msaa_3d=Viewport.MSAA_2X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; add_child(viewport)
	var environment := WorldEnvironment.new(); environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR; environment.environment.background_color=Color("1b252b")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("dce5e5"); environment.environment.ambient_light_energy=0.38
	viewport.add_child(environment)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees=Vector3(-45,-35,0); sun.light_energy=0.7; sun.shadow_enabled=true; viewport.add_child(sun)
	var rim := DirectionalLight3D.new(); rim.rotation_degrees=Vector3(-30,145,0); rim.light_color=Color("bad8e5"); rim.light_energy=0.25; viewport.add_child(rim)
	stage=Node3D.new(); viewport.add_child(stage)
	CoreVehicleVisual.box(stage,Vector3(0,-0.1,0),Vector3(500,0.2,500),Color("222c30"))
	camera=Camera3D.new(); camera.current=true; camera.fov=42; viewport.add_child(camera)
	gui_input.connect(_orbit)
	resized.connect(func() -> void:
		if is_instance_valid(model) and is_instance_valid(camera): fit_camera(); update_camera())

static func measure(node: Node3D, relative: Transform3D=Transform3D.IDENTITY) -> AABB:
	var transform := relative*node.transform
	var out := AABB()
	if node is MeshInstance3D and node.mesh!=null: out=transform*node.get_aabb()
	for child in node.get_children():
		if child is Node3D:
			var part := measure(child,transform)
			if part.size.length_squared()>0: out=part if out.size.length_squared()==0 else out.merge(part)
	return out

func show_vehicle(row: Dictionary) -> bool:
	if is_instance_valid(model): model.free()
	model=null; model_id=""
	if not row.get("model") is Dictionary: return false
	# A combat-linked row previews the exact runtime model used by its packet. Static
	# rows continue to show the reviewed research snapshot. Both paths remain hash-bound.
	var model_record: Dictionary=row.model
	if row.get("combat_package") is Dictionary and row.combat_package.get("runtime_model") is Dictionary:
		model_record=row.combat_package.runtime_model
	var path := str(model_record.get("path",""))
	var expected_sha := str(model_record.get("sha256",""))
	if path.is_empty() or expected_sha.is_empty() or not FileAccess.file_exists(path): return false
	if FileAccess.get_sha256(path)!=expected_sha: return false
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty(): return false
	var document := GLTFDocument.new(); var state := GLTFState.new()
	if document.append_from_buffer(bytes,"",state)!=OK: return false
	model=document.generate_scene(state)
	if model==null: return false
	viewport.add_child(model); bounds=measure(model)
	if not bounds.position.is_finite() or not bounds.size.is_finite() or bounds.size.length_squared()<=0:
		model.free(); model=null; return false
	model.position.y-=bounds.position.y
	model_id=row.id; yaw=0.62; pitch=0.28
	distance=maxf(bounds.size.length(),5.0); update_camera(); fit_camera(); update_camera()
	return true

func fit_camera() -> void:
	var aspect := maxf(size.x/maxf(size.y,1.0),0.5)
	var tangent := tan(deg_to_rad(camera.fov)*0.5)
	var required := 1.0
	for index in 8:
		var offset := bounds.get_endpoint(index)-bounds.get_center()
		var local := camera.basis.inverse()*offset
		required=maxf(required,local.z+maxf(absf(local.y)/tangent,absf(local.x)/(tangent*aspect)))
	distance=required*1.2

func update_camera(center_override: Variant=null, heading: float=0.0) -> void:
	if not is_instance_valid(camera): return
	var center := Vector3(bounds.get_center().x,bounds.size.y*0.48,bounds.get_center().z)
	if center_override is Vector3: center=center_override
	var angle := yaw+heading
	camera.position=center+Vector3(sin(angle)*cos(pitch),sin(pitch),cos(angle)*cos(pitch))*distance
	camera.look_at(center)

func _orbit(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_LEFT:
		yaw-=event.relative.x*0.008; pitch=clampf(pitch+event.relative.y*0.005,0.05,1.1); update_camera(); accept_event()
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		distance=clampf(distance*(0.9 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.1),bounds.size.length()*0.8,bounds.size.length()*3.0)
		update_camera(); accept_event()
