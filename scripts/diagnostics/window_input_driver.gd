extends Node
## Windowed evidence from the normal garage, keys and mouse. No direct fire/cooldown/state writes.
var app: AppFlow
var shot_dir := ""
var checks := 0
var failed := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+label)

func frames(n: int) -> void:
	for i in n: await get_tree().physics_frame
	await get_tree().process_frame

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new(); event.keycode = code; event.physical_keycode = code; event.pressed = pressed
	Input.parse_input_event(event)

func tap(code: Key) -> void:
	key(code,true); await frames(2); key(code,false); await frames(2)

func mouse(button: MouseButton, pressed: bool, point: Vector2 = Vector2(640,360)) -> void:
	var event := InputEventMouseButton.new()
	event.set_meta("automated_demo",true)
	event.position = point; event.global_position = point; event.button_index = button; event.pressed = pressed
	Input.parse_input_event(event)

func click(button: Control) -> void:
	# WT-040-R1: name the offending control, because the packaged run reports four failures of this assertion in
	# the final garage-to-map section and which control it is decides whether the fault is a test timing issue or
	# a real UI defect. The assertion itself is unchanged.
	var control_label := "<null: the caller could not find the control>"
	if is_instance_valid(button):
		control_label = str(button.get_path()) + " visible=" + str(button.is_visible_in_tree()) + " disabled=" + str(button.disabled if "disabled" in button else false)
	# WT-040-R1 (2026-09-17 ruling): a hidden, disabled or unreachable control must STOP the click. The previous
	# version kept going whenever the node merely existed, computed a centre point and sent a mouse event anyway,
	# which could land on whatever is actually there and cascade into unrelated failures.
	var control_ok := is_instance_valid(button) and button.is_visible_in_tree()
	check(control_ok,"normal UI control is visible before click: "+control_label)
	if not control_ok: return
	if "disabled" in button and button.disabled:
		check(false,"normal UI control is enabled before click: "+control_label)
		return
	# Follow the public scroll interaction when the expanded garage puts a control below the fold.
	var ancestor := button.get_parent()
	while ancestor != null and not ancestor is ScrollContainer: ancestor = ancestor.get_parent()
	if ancestor is ScrollContainer:
		for attempt in 35:
			var clip: Rect2 = ancestor.get_global_rect()
			var rect := button.get_global_rect()
			if rect.position.y >= clip.position.y+2 and rect.end.y <= clip.end.y-2: break
			var wheel := MOUSE_BUTTON_WHEEL_DOWN if rect.end.y > clip.end.y-2 else MOUSE_BUTTON_WHEEL_UP
			mouse(wheel,true,clip.get_center()); mouse(wheel,false,clip.get_center()); await frames(3)
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new(); motion.position = point; motion.global_position = point
	Input.parse_input_event(motion); await frames(3)
	mouse(MOUSE_BUTTON_LEFT,true,point); await frames(2); mouse(MOUSE_BUTTON_LEFT,false,point)
	await frames(12)

func find_button(node: Node, title: String) -> Button:
	if node is Button and node.text == title: return node
	for child in node.get_children():
		var found := find_button(child,title)
		if found != null: return found
	return null

func capture(id: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	check(not image.is_empty() and image.save_png(shot_dir.path_join(id+".png")) == OK,"actual window capture "+id+" (review pending)")

