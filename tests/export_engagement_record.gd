extends SceneTree
# WT-012-R1 deliverable: fire one real production shot in the combat laboratory and
# export its terminal engagement record through the production codec, with a
# lossless round-trip check. This is evidence for "actual-path replay + event JSON".
var out_path := "res://logs/WT-012-r1/engagement_record.json"
func _initialize() -> void: call_deferred("_run")
func _frames(n: int = 3) -> void:
	for i in n: await physics_frame
func _run() -> void:
	root.size = Vector2i(1280,720)
	var args := OS.get_cmdline_user_args()
	var at := args.find("--out")
	if at >= 0 and at+1 < args.size(): out_path = args[at+1]
	var scene := AICombatRange.new()
	root.add_child(scene)
	current_scene = scene
	await _frames(10)
	if not scene.combat_ready:
		print("[FAIL] combat laboratory did not become ready")
		quit(1); return
	var shooter: VehicleActor = scene.source_actor
	var target: VehicleActor = scene.target_actor
	var records: Array = []
	scene.projectiles.projectile_finished.connect(func(record: Dictionary) -> void: records.append(record))
	var aim := target.tank.global_position+Vector3.UP*1.2
	var aligned := false
	for i in 240:
		shooter.turret.set_aim_point(aim)
		await physics_frame
		var want := (aim-shooter.turret.muzzle.global_position).normalized()
		if rad_to_deg(shooter.turret.barrel_direction().angle_to(want)) < 0.5:
			aligned = true
			break
	print("[export] aligned=",aligned," shooter=",shooter.definition.id," target=",target.definition.id," shell=",shooter.gunner.shell.id)
	var fired: bool = shooter.gunner.request_fire()
	print("[export] fire accepted=",fired," blocked=",shooter.gunner.blocked_reason," rounds=",shooter.gunner.rounds_remaining)
	var waited := 0
	while waited < 900 and records.is_empty():
		waited += 1
		await physics_frame
	if records.is_empty():
		print("[FAIL] no terminal record produced (waited %d ticks)"%waited)
		quit(1); return
	var record: Dictionary = records[0]
	var encoded := ShotRecordCodec.encode(record)
	if not encoded.get("ok",false):
		print("[FAIL] production codec rejected the record: ",encoded.get("errors",[]))
		quit(1); return
	var text := str(encoded.get("json",""))
	var decoded := ShotRecordCodec.decode(text)
	var payload := {
		"schema": 1,
		"work_order": "WT-012-R1",
		"generated_by": "tests/export_engagement_record.gd",
		"map": "AICombatRange (combat laboratory)",
		"shooter": {"entity":shooter.entity_id,"life":shooter.life_id,"definition":shooter.definition.id},
		"target": {"entity":target.entity_id,"life":target.life_id,"definition":target.definition.id},
		"shell_id": str(shooter.gunner.shell.id),
		"fire_accepted": fired,
		"aligned_ticks_before_fire": waited,
		"record_bytes": text.length(),
		"decode_ok": decoded.get("ok",false),
		"decode_matches_encode": str(decoded.get("record",{})) == str(encoded.get("record",{})),
		"terminal_reason": str(record.get("reason","")),
		"terminal_target": str(record.get("target_id","")),
		"record_keys": record.keys(),
		"encoded_record": encoded.get("record",{}),
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_path.get_base_dir()))
	var file := FileAccess.open(out_path,FileAccess.WRITE)
	if file == null:
		print("[FAIL] cannot write ",out_path)
		quit(1); return
	file.store_string(JSON.stringify(payload,"  ")+"\n")
	file.close()
	print("[export] wrote ",out_path," (",text.length()," record bytes)")
	print("[export] terminal reason=",payload.terminal_reason," target=",payload.terminal_target," decode_matches=",payload.decode_matches_encode)
	print("ENGAGEMENT_RECORD_EXPORT_DONE")
	quit(0)
