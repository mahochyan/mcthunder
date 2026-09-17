extends SceneTree
## Mouse focus self-test (user report "the game keeps limiting my mouse, even in the background").
##
## The pointer decision is a pure function of the match state and the window focus, so it is asserted here without
## opening a window: a running match with focus captures, a running match in the background releases, and any state
## without focus keeps the pointer usable. Before the fix every frame re-captured unconditionally, which is exactly
## the reported behaviour.
var count := 0
var failed := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	count += 1
	print(("[PASS] " if ok else "[FAIL] "), label)
	if not ok: failed += 1

func _run() -> void:
	var router := InputFocusRouter.new()
	router.mode = "playing"
	router.window_focus(true)
	check(router.desired_mode()==Input.MOUSE_MODE_CAPTURED, "a running match with the window focused captures the pointer")
	# The reported bug: the window goes to the background while the match is still playing.
	router.window_focus(false)
	check(router.desired_mode()==Input.MOUSE_MODE_VISIBLE, "a running match in the background releases the pointer")
	check(router.desired_mode()!=Input.MOUSE_MODE_CAPTURED, "the background state never asks for a capture")
	# Coming back restores the capture only because the match is still running.
	router.window_focus(true)
	check(router.desired_mode()==Input.MOUSE_MODE_CAPTURED, "returning focus restores the capture while the match runs")
	# Paused / waiting / dead states keep the pointer usable regardless of focus.
	for paused_mode in ["paused","waiting","over",""]:
		router.mode = paused_mode
		router.window_focus(true)
		check(router.desired_mode()==Input.MOUSE_MODE_VISIBLE, "the %s state keeps the pointer usable" % (paused_mode if not paused_mode.is_empty() else "no-match"))
	# The shared capture helper must refuse while the window is in the background.
	router.mode = "playing"
	router.window_focus(false)
	check(router.desired_mode()==Input.MOUSE_MODE_VISIBLE, "the shared capture path follows the same rule")
	print("=== mouse focus: %d checks, %d failed ===" % [count,failed])
	print("MOUSE_FOCUS_CHECKS_PASS" if failed==0 else "MOUSE_FOCUS_CHECKS_FAIL")
	quit(0 if failed==0 else 1)
