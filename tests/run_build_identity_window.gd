extends SceneTree
# WT-001-R2 real-window verification: the running menu must actually show the
# development candidate identity (version + build id + base SHA) and must not
# claim release readiness. Asserts against the live UI tree, then keeps a shot.
var count := 0
var failed := 0
var shots := "res://docs/evidence/WT-001-r2"
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func _collect(node: Node, out: Array) -> void:
	if node is Label: out.append(node)
	for child in node.get_children(): _collect(child, out)
func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("[FAIL] build identity window check requires a real window")
		quit(1); return
	root.size = Vector2i(1280,720)
	var scene: Node = load("res://scenes/app.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var waited := 0
	var found := ""
	var all_text: Array = []
	while waited < 900 and found.is_empty():
		await physics_frame
		waited += 1
		var labels: Array = []
		_collect(current_scene, labels)
		all_text = []
		for label in labels: all_text.append(String(label.text))
		for text in all_text:
			if text.contains(BuildIdentity.BUILD_ID): found = text
	print("[info] frames waited = ",waited)
	if found.is_empty():
		print("[info] no label carried the build id; labels seen (first 15):")
		for text in all_text.slice(0,15): print("    |",text)
	_check(not found.is_empty(),"running menu shows the build id")
	_check(found.contains("1.0.0-rc.3-dev"),"menu line carries the display version")
	_check(found.contains(BuildIdentity.SOURCE_BASE_COMMIT.substr(0,7)),"menu line carries the source base SHA")
	_check(found.contains("开发候选"),"menu line declares a development candidate, not a release")
	_check(not found.contains("发布就绪"),"menu line never claims release readiness")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shots))
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := shots+"/menu_identity.png"
	var saved := not image.is_empty() and image.save_png(ProjectSettings.globalize_path(path)) == OK
	_check(saved,"real-window menu screenshot saved to "+path)
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("BUILD_IDENTITY_WINDOW_PASS" if failed == 0 else "BUILD_IDENTITY_WINDOW_FAIL")
	if is_instance_valid(scene): scene.free()
	quit(1 if failed else 0)
