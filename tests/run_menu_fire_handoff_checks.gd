extends SceneTree
## A UI can finish a press/release pair in one render frame. The release guard
## must discard that old edge before allowing a genuinely new gameplay press.
var checks:=0
var failed:=0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failed+=1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func _initialize() -> void: call_deferred("_run")
func frames(amount: int) -> void:
	for i in amount: await physics_frame
	await process_frame
func fire(pressed: bool) -> void:
	var event:=InputEventAction.new(); event.action="fire"; event.pressed=pressed
	Input.parse_input_event(event)
func _run() -> void:
	var scene:=ChallengeRange.new(); root.add_child(scene); current_scene=scene
	await frames(210)
	check(scene.challenge_ready and scene.actor.gunner.shots_fired==0 and scene.actor.gunner.rounds_remaining==6,"real challenge starts with exactly six rounds and no launch shot")
	scene.controller.require_fire_release()
	fire(true); fire(false)
	await frames(5)
	print("[handoff] shots=",scene.actor.gunner.shots_fired," rounds=",scene.actor.gunner.rounds_remaining," pending=",scene.controller._fire_pending," guard=",scene.controller._need_fire_release," held=",Input.is_action_pressed("fire")," edge=",Input.is_action_just_pressed("fire"))
	check(scene.actor.gunner.shots_fired==0 and scene.actor.gunner.rounds_remaining==6,"same-frame UI press/release is discarded by the real release guard")
	await frames(420)
	fire(true); await frames(3); fire(false); await frames(5)
	print("[fresh] shots=",scene.actor.gunner.shots_fired," rounds=",scene.actor.gunner.rounds_remaining," last=",scene.actor.gunner.last_shot_result)
	check(scene.actor.gunner.shots_fired==1 and scene.actor.gunner.rounds_remaining==5,"the next fresh gameplay press fires exactly one actual round")
	scene.free(); await frames(3)
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failed])
	if failed==0: print("MENU_FIRE_HANDOFF_CHECKS_PASS")
	quit(0 if failed==0 else 1)
