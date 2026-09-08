class_name ShellRange
extends BallisticsRange
## Player-accessible finite-ammo comparison using actual Gunner, query, damage and replay.
var target_actor: VehicleActor
var case_index := 0
var xray := true
var round_id := 1
var target_visual: Node3D
var status_label: Label
var markers: Array[Dictionary] = []
var surfaces: Array[MeshInstance3D] = []
var last_record: Dictionary = {}

func _ready() -> void:
	super._ready()
	if not _initialized: return
	actor.set_damage_layout(DamageTrainingLayout.build())
	var options := test_options()
	if not actor.gunner.configure_shell_loadout(options,{options[0].id:10,options[1].id:10},options[0].id):
		push_error("shell laboratory loadout failed"); return
	target_actor = VehicleActor.new(); add_child(target_actor)
	if not target_actor.setup(defs,"player_tank","shell_target",2,Transform3D(Basis.IDENTITY,Vector3(0,0,-30)),4,null).ok: return
	for node in target_actor.tank.find_children("*","GeometryInstance3D",true,false): node.visible = false
	target_actor.label3d.visible = false
	var panel := PanelContainer.new(); hud.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -350; panel.offset_right = -16; panel.offset_top = 88
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label = Label.new(); status_label.custom_minimum_size.x = 310
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(status_label)
	projectiles.shot_record_ready.connect(func(record: Dictionary) -> void: last_record = record.duplicate(true))
	replay.overlay_changed.connect(func(open: bool) -> void: panel.visible = not open)
	hud.impact_label.visible = false
	select_case(0)

static func test_options() -> Array[ShellDefinition]:
	var out: Array[ShellDefinition] = []
	for index in 2:
		var shell := ShellDefinition.new()
		shell.id = "test_ap120" if index==0 else "test_aphe96"
		shell.display_name = "AP 120" if index==0 else "APHE 96"
		shell.muzzle_velocity_mps = 600; shell.armor_policy = "resolve"
		shell.effect_policy = "kinetic" if index==0 else "internal_burst"
		shell.penetration_curve = PackedVector2Array([Vector2(0,120 if index==0 else 96)])
		shell.penetration_mm = shell.penetration_curve[0].y
		shell.verification = "estimated"; shell.source_refs = ["TEST ONLY 021 comparison: APHE=AP*0.8 is not historical"]
		out.append(shell)
	return out

func _build_world() -> void:
	_add_wall(Vector3(0,-0.3,-25),Vector3(90,0.6,110))
	_add_wall(Vector3(0,4,-50),Vector3(50,8,0.5))
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50,-25,0); sun.light_energy=1.3; add_child(sun)
	var environment := WorldEnvironment.new(); environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("#8caebe")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_energy = 0.8; add_child(environment)

func get_round_id() -> int: return round_id

func select_case(index: int) -> void:
	if not is_instance_valid(target_actor) or index not in [0,1]: return
	projectiles.cancel_all("cancelled_target_change"); projectile_visuals.clear_all(); round_id += 1
	controller.require_fire_release(); last_record.clear(); case_index = index
	var layout := ShellTrainingTargets.build(20 if index==0 else 100)
	target_actor.set_damage_layout(layout)
	if is_instance_valid(target_visual): target_visual.queue_free()
	target_visual = Node3D.new(); target_actor.tank.add_child(target_visual)
	markers.clear(); surfaces.clear()
	for patch in layout.armor_patches:
		var mesh := MeshInstance3D.new(); mesh.mesh = ArmorPatchMesh.build_surface(patch.vertices_local_m,patch.triangles,patch.outward_normal_local)
		var material := StandardMaterial3D.new(); material.cull_mode=BaseMaterial3D.CULL_DISABLED
		material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; material.albedo_color=Color(0.63,0.56,0.37,0.22)
		mesh.material_override=material; target_visual.add_child(mesh); surfaces.append(mesh)
		var wire := MeshInstance3D.new(); wire.mesh=ArmorPatchMesh.build_wire(patch.vertices_local_m,patch.triangles,patch.outward_normal_local)
		var line_material := StandardMaterial3D.new(); line_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; line_material.albedo_color=Color("#322e28")
		wire.material_override=line_material; target_visual.add_child(wire)
	for module in layout.modules:
		var mesh := MeshInstance3D.new(); var box := BoxMesh.new(); box.size=module.size_m; mesh.mesh=box
		mesh.transform=module.local_box_transform; var material := StandardMaterial3D.new()
		material.albedo_color=Color("#4a957a"); mesh.material_override=material; target_visual.add_child(mesh)
		markers.append({"mesh":mesh,"id":module.id})
	var label := Label3D.new(); label.text="THIN 20 mm" if index==0 else "THICK 100 mm"
	label.position=Vector3(0,4.0,0); label.font_size=48; target_visual.add_child(label)

func _process(delta: float) -> void:
	super._process(delta)
	if status_label==null or not is_instance_valid(target_actor): return
	hud.control_label.text="AP / APHE LAB · TEST ONLY"
	hud.hint_label.text="1 AP / 2 APHE: select NEXT load\n3 thin / 4 thick target · X see inside\nLMB fire · RMB sight · R full restart · Esc menu"
	var gun := actor.gunner
	var stock := gun.inventory.shell_counts()
	var lines: Array[String] = ["AP 120 vs APHE 96", "Game design values only", "", "Loaded: "+gun.shell_label(gun.inventory.chamber_shell),
		"Carrying: "+gun.shell_label(gun.inventory.transfer_shell),"Next: "+gun.shell_label(gun.inventory.selected_shell),
		"AP %d / APHE %d"%[stock.get("test_ap120",0),stock.get("test_aphe96",0)],"", "TARGET: "+("20 mm" if case_index==0 else "100 mm")]
	for marker in markers:
		var integrity := float(target_actor.state.module_states[marker.id].integrity)
		marker.mesh.material_override.albedo_color=Color("#4a957a") if integrity>99 else Color("#e76643")
		marker.mesh.visible=xray
		lines.append("%s: %.0f%%"%[str(marker.id).replace("component_","module "),integrity])
	for surface in surfaces: surface.material_override.albedo_color=Color(0.63,0.56,0.37,0.22 if xray else 1.0)
	if not last_record.is_empty():
		lines.append("\nLast: "+str(last_record.terminal.reason).replace("_"," "))
		lines.append("Fragments %d / recorded hits %d"%[last_record.get("fragments",[]).size(),last_record.damage.size()])
	lines.append("\nAP continues along its path.\nAPHE: inside 0.8m, at most 12 rays.\nEarly exit cancels inside burst.\nV replay: actual recorded paths.")
	status_label.text="\n".join(lines)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and not _paused:
		if event.keycode in [KEY_3,KEY_4]: select_case(0 if event.keycode==KEY_3 else 1); get_viewport().set_input_as_handled(); return
		if event.keycode==KEY_X: xray=not xray; return
	if event.is_action_pressed("toggle_target"): return
	super._unhandled_input(event)

func _reset_range() -> void:
	actor.reset_vehicle(); select_case(case_index)
