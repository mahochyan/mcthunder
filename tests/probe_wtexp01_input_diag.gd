extends SceneTree
## WT-EXPANSION-01 item B step 4 diagnostic: the input-path acceptance leg failed with the command carrying
## secondary=false, so the broken link has to be MEASURED rather than guessed. This probe answers three questions in
## order: does the raw key event for physical_keycode 72 (H) map to the fire_secondary action at all, does the Input
## singleton report a just_pressed edge in the same frame the event is parsed, and does that edge survive a frame
## boundary (which is how the controller's own _process would see it in a running game).
func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var press := InputEventKey.new(); press.physical_keycode = KEY_H; press.pressed = true
	print("[diag] InputMap knows fire_secondary: %s" % str(InputMap.has_action("fire_secondary")))
	print("[diag] event_is_action(press, fire_secondary): %s" % str(InputMap.event_is_action(press,"fire_secondary")))
	var bound: Array = InputMap.action_get_events("fire_secondary")
	for e in bound:
		print("[diag] bound event: %s physical=%d keycode=%d" % [str(e),int(e.physical_keycode) if e is InputEventKey else -1,int(e.keycode) if e is InputEventKey else -1])
	print("[diag] frames before parse: %d" % Engine.get_process_frames())
	Input.parse_input_event(press)
	print("[diag] same frame after parse: just_pressed=%s pressed=%s frames=%d" % [str(Input.is_action_just_pressed("fire_secondary")),str(Input.is_action_pressed("fire_secondary")),Engine.get_process_frames()])
	await process_frame
	print("[diag] after one process_frame: just_pressed=%s pressed=%s frames=%d" % [str(Input.is_action_just_pressed("fire_secondary")),str(Input.is_action_pressed("fire_secondary")),Engine.get_process_frames()])
	var release := InputEventKey.new(); release.physical_keycode = KEY_H; release.pressed = false
	Input.parse_input_event(release)
	print("[diag] after release: just_pressed=%s pressed=%s" % [str(Input.is_action_just_pressed("fire_secondary")),str(Input.is_action_pressed("fire_secondary"))])
	# The alternative route: the action API itself, which is what a test can use when no OS device exists.
	Input.action_press("fire_secondary")
	print("[diag] action_press: just_pressed=%s pressed=%s frames=%d" % [str(Input.is_action_just_pressed("fire_secondary")),str(Input.is_action_pressed("fire_secondary")),Engine.get_process_frames()])
	# LINK 1: does the controller's own _process capture the edge into its pending bit?
	var controller := PlayerController.new(); root.add_child(controller)
	controller._process(0.0)
	print("[diag] link1 controller pending after _process while pressed: %s" % str(controller._secondary_fire_pending))
	Input.action_release("fire_secondary")
	# LINK 2: does poll() publish that pending bit onto the command?
	var cmd: VehicleCommand = controller.poll()
	print("[diag] link2 polled command secondary_fire_requested=%s index=%d" % [str(cmd.secondary_fire_requested),cmd.secondary_fire_index])
	# LINK 3: does the codec body carry the field through encode -> decode?
	var rt := VehicleCommand.new(); rt.secondary_fire_requested = true; rt.secondary_fire_index = 1
	var body: Dictionary = VehicleCommandCodec.encode_body(rt)
	print("[diag] link3 body size=%d has_flag=%s index=%s" % [body.size(),str(body.get("secondary_fire_requested")),str(body.get("secondary_fire_index"))])
	var decoded: Dictionary = VehicleCommandCodec.decode({"version":VehicleCommandCodec.VERSION,"entity_id":"A","life_id":1,"generation":0,"control_epoch":0,"sequence":1,"input_tick":0,"command":body})
	print("[diag] link3 decode ok=%s reason=%s flag=%s index=%s" % [str(decoded.get("ok")),str(decoded.get("reason","")),str(decoded.get("command",null)!=null and decoded.command.secondary_fire_requested),str(decoded.get("command",null)!=null and decoded.command.secondary_fire_index)])
	quit(0)
