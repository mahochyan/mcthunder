extends SceneTree
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("[PASS] " if ok else "[FAIL] ", message)

func run() -> void:
	var garage := GarageShell.new()
	root.add_child(garage)
	await process_frame
	var button: Button
	for child in garage.find_children("*", "Button", true, false):
		if child.text == "模型展厅 / Models": button = child
	check(button != null, "garage exposes model showroom")
	if button == null: quit(1); return
	button.pressed.emit()
	await process_frame
	var showroom := garage.get_node("ModelShowroom") as ModelShowroom
	check(showroom != null, "normal garage button opens showroom")
	for index in ModelShowroom.MODELS.size():
		showroom.choice.select(index)
		showroom.choice.item_selected.emit(index)
		await process_frame
		check(is_instance_valid(showroom.model), "model %d loads" % index)
		var meshes := showroom.model.find_children("*", "MeshInstance3D", true, false)
		check(not meshes.is_empty(), "model %d has visible geometry" % index)
		check(showroom.radius > 1 and showroom.radius < 20, "model %d finite vehicle scale" % index)
		check(showroom.pivot.get_child_count() == 1, "switch frees previous model")
		if DisplayServer.get_name() != "headless":
			showroom.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			await process_frame
			await RenderingServer.frame_post_draw
			var path := "res://docs/evidence/workspace-model-%d.png" % index
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/evidence"))
			check(root.get_texture().get_image().save_png(path) == OK, "real viewport screenshot saved")
	showroom.queue_free()
	await process_frame
	check(garage.get_node_or_null("ModelShowroom") == null, "close returns to garage")
	garage.queue_free()
	await process_frame
	print("=== 结果: %d 项检查, %d 失败 ===" % [checks, failures])
	if failures == 0: print("MODEL_SHOWROOM_CHECKS_PASS")
	quit(0 if failures == 0 else 1)
