extends SceneTree
## Exact-set gate for data row -> reviewed model -> runtime model -> combat packet.
var count := 0
var failed := 0

func _check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)

func _read(path: String) -> Dictionary:
	var value: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}

func _near(a: float,b: float,tolerance: float=0.0001) -> bool:
	return absf(a-b)<=tolerance

func _initialize() -> void:
	call_deferred("_run")
	var timer := create_timer(120.0)
	timer.timeout.connect(func() -> void: print("[FAIL] research alignment watchdog timeout"); quit(1))

func _run() -> void:
	var tree := _read("res://assets/research/soviet_german_tree.json")
	var intent := _read("res://authoring/reference_data/research_combat_bindings.json")
	_check(tree.get("schema_version")==2,"research tree schema is supported")
	_check(intent.get("schema_version")==1,"combat binding schema is supported")
	var rows: Dictionary={}
	for value in tree.get("vehicles",[]):
		if value is Dictionary and value.get("id") is String:
			_check(not rows.has(value.id),"base identity occurs once: "+str(value.id))
			rows[value.id]=value
	_check(rows.size()==212,"all 212 base identities are present exactly once")
	var expected: Array[String]=[]
	for value in intent.get("bindings",[]):
		if value is Dictionary: expected.append(str(value.get("vehicle_id","")))
	expected.sort()
	var actual: Array[String]=[]
	for id in rows:
		var row: Dictionary=rows[id]
		if row.get("combat_package") is Dictionary: actual.append(str(id))
	actual.sort()
	_check(expected==actual,"binding manifest and generated combat rows are the same exact set")
	var engineering: Array[String]=[]
	engineering.assign(VehicleCatalog.ENGINEERING_IDS)
	engineering.sort()
	_check(expected==engineering,"binding manifest and runtime engineering catalogue are the same exact set")
	_check(int(tree.get("alignment",{}).get("combat_bindings",-1))==expected.size(),"alignment summary count matches exact set")
	_check(tree.get("alignment",{}).get("bound_ids",[])==expected,"alignment summary names exactly the bound ids")
	_check(str(tree.get("alignment",{}).get("set_policy",""))=="exact_id_no_alias_no_missing_no_extra","no-alias/no-missing/no-extra policy is recorded")
	var defs:=VehicleDefs.new()
	var catalog:=VehicleCatalog.new()
	var admitted: Dictionary=catalog.load_engineering(defs)
	_check(bool(admitted.get("ok",false)),"all bound packets pass the production content pipeline: "+str(admitted.get("errors",[])))
	for id in expected:
		var row: Dictionary=rows.get(id,{})
		var link: Dictionary=row.get("combat_package",{})
		var preview: Dictionary=row.get("model",{})
		var runtime: Dictionary=link.get("runtime_model",{})
		var package_path := str(link.get("path",""))
		_check(str(link.get("vehicle_id",""))==id,"combat link keeps exact identity: "+id)
		_check(str(row.get("admission_status",""))=="combat_engineering","tree row records engineering combat admission: "+id)
		_check(bool(preview.get("combat_admitted",false)),"reviewed model records its linked combat admission: "+id)
		_check(FileAccess.file_exists(str(preview.get("path",""))) and FileAccess.get_sha256(str(preview.get("path","")))==str(preview.get("sha256","")),"reviewed model bytes match: "+id)
		_check(FileAccess.file_exists(str(runtime.get("path",""))) and FileAccess.get_sha256(str(runtime.get("path","")))==str(runtime.get("sha256","")),"runtime model bytes match: "+id)
		_check(FileAccess.file_exists(package_path) and FileAccess.get_sha256(package_path)==str(link.get("sha256","")),"combat packet bytes match: "+id)
		var packet := _read(package_path)
		_check(str(packet.get("id",""))==id and str(packet.get("source_binding",{}).get("source_vehicle_id",""))==id,"packet and source data use exact identity: "+id)
		var tuning: Dictionary=packet.get("arcade_tuning",{})
		_check(packet.get("gameplay_mode")=="arcade" and _near(float(packet.get("runtime",{}).get("acceleration",0.0)),float(tuning.get("base_acceleration_mps2",0.0))*float(tuning.get("arcade_power_multiplier_applied",0.0))),"combat runtime applies the declared arcade tuning: "+id)
		var wrong_mode:=packet.duplicate(true); wrong_mode.gameplay_mode="realistic"
		_check(not VehicleContentPipeline.validate_package(wrong_mode,catalog.model_sources).ok,"realistic/full-real packet is rejected from arcade combat: "+id)
		_check(str(packet.get("model_binding",{}).get("vehicle_id",""))==id and str(packet.get("model_binding",{}).get("model",{}).get("source_vehicle_id",""))==id,"packet and runtime model use exact identity: "+id)
		_check(str(packet.get("model_binding",{}).get("model",{}).get("path",""))==str(runtime.get("path","")),"tree and packet select the same runtime model: "+id)
		var resolved: Dictionary=defs.resolve_vehicle(id)
		_check(bool(resolved.get("ok",false)),"bound data resolves through the runtime registry: "+id)
		if resolved.get("ok",false):
			var vehicle: VehicleDefinition=resolved.vehicle
			var weapon: WeaponDefinition=resolved.weapon
			var shell: ShellDefinition=resolved.shell
			var authored: Dictionary=packet.get("runtime",{})
			_check(_near(vehicle.forward_max_speed,float(authored.get("forward_max_speed",0.0))) and _near(vehicle.reverse_max_speed,float(authored.get("reverse_max_speed",0.0))) and _near(vehicle.forward_accel,float(authored.get("acceleration",0.0))),"authored mobility values reach the runtime definition: "+id)
			_check(_near(vehicle.hull_turn_speed,float(authored.get("hull_turn_speed",0.0))) and _near(vehicle.barrel_pitch_min,float(authored.get("pitch_min",0.0))) and _near(vehicle.barrel_pitch_max,float(authored.get("pitch_max",0.0))),"authored steering and gun limits reach the runtime definition: "+id)
			var reference_profile:=ResearchReferenceProfiles.profile(id)
			var source_traverse: Dictionary=reference_profile.get("primary_weapon",{}).get("traverse_deg_s",{})
			var source_rates: Dictionary=source_traverse.get("value",{})
			_check(source_traverse.get("resolution_state") in ["explicit_reference_candidate","explicit_reference_duplicate_consistent"] and _near(vehicle.turret_yaw_speed,float(source_rates.get("yaw",0.0))) and _near(vehicle.turret_pitch_speed,float(source_rates.get("pitch",0.0))),"cache traverse rates reach the production vehicle definition without defaults: "+id)
			_check(_near(weapon.reload_time,float(authored.get("reload_time",0.0))) and weapon.initial_rounds==int(authored.get("rounds",0)),"authored reload and ammunition values reach the runtime weapon: "+id)
			var default_shell: Dictionary={}
			var catalog_block: Dictionary=packet.get("shell_catalog",{})
			for shell_row in catalog_block.get("shells",[]):
				if shell_row is Dictionary and str(shell_row.get("id",""))==str(catalog_block.get("default","")): default_shell=shell_row
			_check(not default_shell.is_empty() and _near(shell.muzzle_velocity_mps,float(default_shell.get("muzzle_velocity_mps",0.0))) and shell.effect_policy==str(default_shell.get("effect_policy","")),"authored default round controls runtime ballistics and effect policy: "+id)
			var powertrain:=DrivePowertrain.new()
			var accelerated:=powertrain.step(0.0,1.0,0.0,true,0.25,vehicle)
			_check(_near(accelerated,float(authored.get("acceleration",0.0))*0.25),"runtime powertrain consumes the authored acceleration: "+id)
			var steering:=TrackDrive.new()
			steering.step(0.0,1.0,0.25,vehicle)
			var expected_yaw:=deg_to_rad(float(authored.get("hull_turn_speed",0.0))) if vehicle.drive_profile.neutral_turn else 0.0
			_check(_near(steering.yaw_rate,expected_yaw),"runtime track drive consumes the authored hull turn rate: "+id)
			var mechanism:=TurretMechanismState.new()
			var pose:=Vector2.ZERO
			var peak_velocity:=Vector2.ZERO
			for step_index in 240:
				pose=mechanism.step(pose,Vector2(PI*0.45,PI*0.45),Basis.IDENTITY,vehicle.fire_control_profile,Vector2(deg_to_rad(vehicle.turret_pitch_speed),deg_to_rad(vehicle.turret_yaw_speed)),0.0,{},1.0/60.0)
				peak_velocity.x=maxf(peak_velocity.x,absf(mechanism.velocity.x)); peak_velocity.y=maxf(peak_velocity.y,absf(mechanism.velocity.y))
			_check(pose.x>0.0 and pose.y>0.0 and peak_velocity.x>0.0 and peak_velocity.y>0.0 and peak_velocity.x<=deg_to_rad(vehicle.turret_pitch_speed)+0.00001 and peak_velocity.y<=deg_to_rad(vehicle.turret_yaw_speed)+0.00001,"production turret actuator consumes the cache-backed pitch/yaw limits: "+id)
	for id in rows:
		if id in expected: continue
		var row: Dictionary=rows[id]
		_check(row.get("combat_package")==null,"unbound row has no extra combat package: "+str(id))
		if row.get("model") is Dictionary:
			_check(not bool(row.model.get("combat_admitted",false)),"static model is not mislabeled as combat admitted: "+str(id))
	print("=== result: %d checks, %d failed ==="%[count,failed])
	print("RESEARCH_ALIGNMENT_CHECKS_PASS" if failed==0 else "RESEARCH_ALIGNMENT_CHECKS_FAIL")
	quit(1 if failed else 0)
