class_name TutorialGuide
extends Node
## Observes actual simulation state; neither awards damage nor advances rule clocks.
signal completed(chapter: int)
signal next_requested(chapter: int)
var chapter := 0
var world: BallisticsRange
var passed := false
var save_error := ""
var next_button: Button
var status_label: Label
var hint_label: Label
var observed_round := -1
var initial_life := -1
var initial_direction := Vector3.FORWARD
var scope_seconds := 0.0
var turned := false
var fire_seen := false
var extinguish_seen := false
var charges_before := 0
var elapsed := 0.0
var goal := Vector3.ZERO
var capture: TeamMatchState
var ring: MeshInstance3D

func _ready() -> void:
	world = get_parent() as BallisticsRange
	process_physics_priority = 400
	var panel := PanelContainer.new()
	world.hud.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -455; panel.offset_right = -16
	panel.offset_top = 125; panel.offset_bottom = 320
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new(); box.mouse_filter = Control.MOUSE_FILTER_IGNORE; panel.add_child(box)
	var title := CoreUI.label(box,LocalizationService.text("tutorial_heading") % [chapter+1,TutorialCatalog.COUNT,TutorialCatalog.title(chapter)],21)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label = CoreUI.label(box,"",17); hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label = CoreUI.label(box,"",16); status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	next_button = CoreUI.button(world.hud.resume_btn.get_parent(),LocalizationService.text("tutorial_next"),func() -> void:
		if passed: next_requested.emit(chapter+1))
	next_button.disabled = true
	_reset_observation()
	if chapter in [0,8]:
		ring = MeshInstance3D.new(); world.add_child(ring)
		var mesh := TorusMesh.new(); mesh.inner_radius = 1.8 if chapter == 0 else TeamMatchState.CAPTURE_RADIUS-0.1; mesh.outer_radius = mesh.inner_radius+0.15; mesh.rings = 48; mesh.ring_segments = 6
		ring.mesh = mesh; ring.position = goal+Vector3.UP*0.08
		var material := StandardMaterial3D.new(); material.albedo_color = Color("edcd75"); material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; ring.material_override = material
		var marker := Label3D.new(); ring.add_child(marker); marker.position.y = 2
		marker.font = CoreUI.FONT; marker.font_size = 42; marker.no_depth_test = true
		marker.text = LocalizationService.text("tutorial_parking_marker" if chapter==0 else "tutorial_capture_marker")
	AccessibilitySettings.apply(panel)
	AccessibilitySettings.apply(next_button)

func _reset_observation() -> void:
	observed_round = world.get_round_id()
	initial_life = world.actor.life_id
	initial_direction = world.actor.turret.barrel_direction()
	passed = false; scope_seconds = 0; turned = false; fire_seen = false; extinguish_seen = false; elapsed = 0
	save_error = ""
	next_button.disabled = true
	goal = Vector3(0,0,-10 if chapter == 0 else -24)
	capture = TeamMatchState.new()
	if chapter == 8: capture.initialize()
	if world is CoreRange: charges_before = world.target_actor.state.extinguisher_charges

func _physics_process(delta: float) -> void:
	if world == null or not is_instance_valid(world.actor): return
	if world.get_round_id() != observed_round: _reset_observation()
	if passed: return
	elapsed += delta
	var success := false
	var core := world as CoreRange
	match chapter:
		0:
			var offset := world.actor.tank.global_position-goal
			success = Vector2(offset.x,offset.z).length() <= 2 and absf(world.actor.tank.forward_speed)<0.5
		1:
			turned = turned or world.actor.turret.barrel_direction().dot(initial_direction)<0.98
			scope_seconds = scope_seconds+delta if world.actor.cam_rig.sight else 0
			success = turned and scope_seconds>=1
		2,3,4,5,7: success = core != null and core.director.status == "passed"
		6:
			if core != null:
				fire_seen = fire_seen or not core.target_actor.state.fires.is_empty()
				extinguish_seen = extinguish_seen or core.target_actor.state.recovery_action == "extinguish"
				success = fire_seen and extinguish_seen and not core.target_actor.state.destroyed and core.target_actor.state.fires.is_empty() and core.target_actor.state.extinguisher_charges<charges_before and core.target_actor.state.recovery_action.is_empty()
		8:
			var offset := world.actor.tank.global_position-goal
			var inside := Vector2(offset.x,offset.z).length()<=TeamMatchState.CAPTURE_RADIUS and not world.actor.state.destroyed
			CapturePoint.step(capture,[1] if inside else [],delta)
			success = capture.capture_owner == 1
		9: success = world is TeamRange and world.actor.life_id != initial_life and not world.actor.state.destroyed and world.actor.controller == world.controller
	if success:
		passed = true; next_button.disabled = false
		completed.emit(chapter)

func _process(_delta: float) -> void:
	if world == null: return
	hint_label.text = TutorialCatalog.hint(chapter)
	status_label.text = LocalizationService.text("tutorial_completed") if passed else (LocalizationService.text("tutorial_stalled") if elapsed>=35 else LocalizationService.text("tutorial_active"))
	if chapter == 8 and not passed: status_label.text = LocalizationService.text("tutorial_capture_progress") % (absf(capture.capture_progress)*100)
	if world is CoreRange:
		world._status.get_parent().get_parent().visible = false
		world.hud.control_label.text = LocalizationService.text("tutorial_heading") % [chapter+1,TutorialCatalog.COUNT,TutorialCatalog.title(chapter)]
		world.hud.result_label.text = LocalizationService.text("tutorial_short_passed" if passed else "tutorial_short_active")
		world.hud.hint_label.text = LocalizationService.text("tutorial_controls")
		if world.director.status == "failed" and not passed: status_label.text = world.director.explanation
		if chapter in [0,1,8]: world._aim_marker.visible = false
		if not world.actor.gunner.blocked_reason.is_empty(): status_label.text += "\n"+LocalizationService.status(world.actor.gunner.blocked_reason)
	if not save_error.is_empty(): status_label.text = save_error+"\n"+LocalizationService.text("tutorial_save_retry")
