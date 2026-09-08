class_name ArmorRange
extends BallisticsRange
## Player-accessible armor laboratory; uses the existing driving/aiming/fire chain.
var case_index := 0
var case_life := 0
var target_snapshot: Dictionary = {}
var target_visual: Node3D
var contact_history: Array[Dictionary] = []
var last_contact: Dictionary = {}
var _details: Label
var _case_label: Label
var _result_label: Label
var _armor_panel: PanelContainer
var _last_contact_shot := 0

func _ready() -> void:
	super._ready()
	if not _initialized:
		return
	# Duplicate shared shell before changing training rules.
	actor.gunner.shell = actor.gunner.shell.duplicate(true)
	actor.gunner.shell.id = "training_ap70"
	actor.gunner.shell.armor_policy = "resolve"
	actor.gunner.shell.penetration_curve = PackedVector2Array([Vector2(0,70), Vector2(200,70)])
	projectiles.projectile_contact.connect(_on_armor_contact)
	hud.armor_training_button.visible = false
	_build_armor_panel()
	hud.impact_label.visible = false
	select_case(0)
	# Enter centered on the targets using the ordinary camera and finite turret tracking.
	actor.cam_rig.aim_yaw = 0.0
	actor.cam_rig.aim_pitch = 0.0

func _build_world() -> void:
	_add_wall(Vector3(0,-0.3,-50), Vector3(90,0.6,140))
	_add_wall(Vector3(0,4,-40), Vector3(24,8,0.5))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50,-25,0)
	sun.light_energy = 1.3
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#8caebe")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#b0bdc5")
	env.environment.ambient_light_energy = 0.8
	add_child(env)

func _build_armor_panel() -> void:
	_armor_panel = PanelContainer.new()
	hud.add_child(_armor_panel)
	_armor_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_armor_panel.offset_left = -376
	_armor_panel.offset_right = -16
	_armor_panel.offset_top = 84
	_armor_panel.offset_bottom = 460
	_armor_panel.custom_minimum_size = Vector2(346, 310)
	_armor_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	_armor_panel.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	margin.add_child(vb)
	_case_label = Label.new()
	_case_label.add_theme_font_size_override("font_size",22)
	vb.add_child(_case_label)
	var help := Label.new()
	help.text = "ARMOR TRAINING · DESIGNED VALUES\nAP 70 mm · finite speed · gravity\n1 Thin   2 Thick   3 Slope\n4 Two plates   5 Ricochet   6 Unknown\nAim + fire to compare. R restarts."
	vb.add_child(help)
	_result_label = Label.new()
	_result_label.add_theme_font_size_override("font_size",22)
	_result_label.add_theme_color_override("font_color",Color("#f3cb72"))
	vb.add_child(_result_label)
	_details = Label.new()
	_details.custom_minimum_size.x = 320
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.add_theme_font_size_override("font_size",16)
	vb.add_child(_details)

func select_case(index: int) -> void:
	if not _initialized or index < 0 or index >= ArmorTrainingTargets.CASES.size():
		return
	projectiles.cancel_all("cancelled_reset")
	projectile_visuals.clear_all()
	controller.require_fire_release()
	case_index = index
	case_life += 1
	target_snapshot = ArmorTrainingTargets.training_case(index, case_life)
	if is_instance_valid(target_visual):
		target_visual.queue_free()
	target_visual = Node3D.new()
	add_child(target_visual)
	var layout: VehicleLayoutDefinition = target_snapshot.layout
	for patch in layout.armor_patches:
		var mi := MeshInstance3D.new()
		mi.mesh = ArmorPatchMesh.build_surface(patch.vertices_local_m, patch.triangles, patch.outward_normal_local)
		var mat := StandardMaterial3D.new()
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_color = Color("#ce9857") if patch.has_thickness else Color("#8f85a2")
		mi.material_override = mat
		target_visual.add_child(mi)
		# Visible silhouette only, no LAYER_WORLD body that would block penetration.
		var wire := MeshInstance3D.new()
		wire.mesh = ArmorPatchMesh.build_wire(patch.vertices_local_m, patch.triangles, patch.outward_normal_local)
		var line_mat := StandardMaterial3D.new()
		line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		line_mat.albedo_color = Color("#25323b")
		wire.material_override = line_mat
		target_visual.add_child(wire)
	last_contact.clear()
	contact_history.clear()
	_last_contact_shot = 0
	_case_label.text = "%d / %s" % [index + 1, ArmorTrainingTargets.CASES[index].title]
	_result_label.text = "READY"
	_details.text = "Fire at the plate.\nResults come from the actual impact."

func query_snapshots() -> Array:
	var out := super.query_snapshots()
	if not target_snapshot.is_empty():
		out.append(target_snapshot)
	return out

func _on_armor_contact(record: Dictionary) -> void:
	if int(record.get("target_life_id",0)) != case_life:
		return
	if int(record.shot_id) != _last_contact_shot:
		contact_history.clear()
		_last_contact_shot = int(record.shot_id)
	last_contact = record.duplicate(true)
	contact_history.append(record.duplicate(true))
	_result_label.text = str(record.result).replace("_"," ").to_upper()
	var thickness := "%.1f mm" % float(record.thickness_mm) if record.get("has_thickness",false) else "UNKNOWN"
	_details.text = "Shot #%d · contact %d · %s\nArmor: %s · angle %.1f°\nLine-of-sight thickness: %.1f mm\nPenetration: %.1f → %.1f mm\nTravel: %.2f m · flight %.3f s" % [
		record.shot_id, record.contact_index, record.surface_id, thickness, record.get("angle_deg",0),
		record.get("effective_mm",0), record.get("before_mm",0), record.get("after_mm",0),
		record.travelled_m, record.flight_time_s]
	if contact_history.size() > 1:
		_details.text += "\n"
		for r in contact_history:
			_details.text += "\n%s: %s" % [r.surface_id, str(r.result).to_upper()]

func _process(delta: float) -> void:
	super._process(delta)
	if _initialized:
		hud.control_label.text = "ARMOR RANGE · 1–6 targets · Esc menu"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and not _paused:
		if event.keycode >= KEY_1 and event.keycode <= KEY_6:
			select_case(int(event.keycode - KEY_1))
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("toggle_target"):
		return
	super._unhandled_input(event)

func _reset_range() -> void:
	super._reset_range()
	select_case(case_index)
