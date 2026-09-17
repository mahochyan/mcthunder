extends SceneTree
## Proves every modeled research vehicle consumes its own hash-bound mobility values.
var checks:=0
var failed:=0

func _check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failed+=1
	print(("[PASS] " if ok else "[FAIL] ")+label)

func _read(path: String) -> Dictionary:
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var tree:=_read("res://assets/research/soviet_german_tree.json")
	var profiles:=ResearchReferenceProfiles.catalog()
	var rows: Dictionary={}
	for row in tree.get("vehicles",[]):
		if row is Dictionary: rows[str(row.get("id",""))]=row
	var indexed: Dictionary={}
	for profile in profiles.get("profiles",[]):
		if profile is Dictionary: indexed[str(profile.get("id",""))]=profile
	var exact_set:=rows.size()==212 and indexed.size()==212
	for id in rows: exact_set=exact_set and indexed.has(id)
	_check(exact_set,"all 212 exact tree identities have one runtime-readable reference profile")
	var modeled:=0
	var packet_sources:=0
	var reference_sources:=0
	var tracked_interfaces:=0
	var wheeled_interfaces:=0
	var speed_values: Dictionary={}
	for id in rows:
		var row: Dictionary=rows[id]
		if not row.get("model") is Dictionary: continue
		modeled+=1
		var trial:=ResearchTrialDrive.new(); trial.row=row
		_check(trial.configure_mobility(),id+": hash-bound mobility config resolves")
		var interface:=ResearchModelInterfaces.interface_for(row)
		_check(bool(interface.get("ok",false)),id+": selected model resolves an exact hash-bound rig interface")
		if interface.get("ok",false):
			if interface.get("locomotion")=="tracked": tracked_interfaces+=1
			elif interface.get("locomotion")=="wheeled": wheeled_interfaces+=1
		var motion:=ResearchReferenceProfiles.weapon_motion_for(row)
		_check(bool(motion.get("ok",false)),id+": weapon motion resolves from the same vehicle data")
		if not trial.data_ready: continue
		if trial.mobility_source=="combat_packet": packet_sources+=1
		elif trial.mobility_source=="warthunder_reference": reference_sources+=1
		speed_values[snappedf(trial.forward_max_speed,0.001)]=true
		var first_step:=ResearchTrialDrive.advance_speed(0.0,1.0,0.25,trial.forward_max_speed,trial.reverse_max_speed,trial.acceleration)
		_check(is_equal_approx(first_step,minf(trial.forward_max_speed,trial.acceleration*0.25)),id+": authored acceleration changes the actual trial speed step")
		var capped:=ResearchTrialDrive.advance_speed(0.0,1.0,1000.0,trial.forward_max_speed,trial.reverse_max_speed,trial.acceleration)
		_check(is_equal_approx(capped,trial.forward_max_speed),id+": authored forward speed caps the actual trial movement")
		var reverse:=ResearchTrialDrive.advance_speed(0.0,-1.0,1000.0,trial.forward_max_speed,trial.reverse_max_speed,trial.acceleration)
		_check(is_equal_approx(reverse,-trial.reverse_max_speed),id+": authored reverse speed caps the actual trial movement")
		var yaw:=ResearchTrialDrive.yaw_delta(1.0,0.5,trial.hull_turn_speed)
		_check(is_equal_approx(yaw,deg_to_rad(trial.hull_turn_speed)*0.5),id+": authored hull turn rate changes the actual trial rotation")
		if motion.get("ok",false):
			var yaw_step:=ResearchTrialDrive.advance_axis(0.0,1.0,float(motion.yaw_speed),0.25,float(motion.yaw_min),float(motion.yaw_max))
			var pitch_step:=ResearchTrialDrive.advance_axis(0.0,1.0,float(motion.pitch_speed),0.25,float(motion.pitch_min),float(motion.pitch_max))
			_check(is_equal_approx(yaw_step,minf(float(motion.yaw_speed)*0.25,float(motion.yaw_max))),id+": authored turret rate changes the actual trial yaw step")
			_check(is_equal_approx(pitch_step,minf(float(motion.pitch_speed)*0.25,float(motion.pitch_max))),id+": authored elevation rate changes the actual trial pitch step")
			if interface.get("ok",false):
				var document:=GLTFDocument.new(); var state:=GLTFState.new()
				var bytes:=FileAccess.get_file_as_bytes(str(interface.model.path))
				var model:=document.generate_scene(state) if not bytes.is_empty() and document.append_from_buffer(bytes,"",state)==OK else null
				_check(model!=null,id+": selected model instantiates for the data-driven rig")
				if model!=null:
					trial.turret_pivot=model.find_child(str(interface.nodes.turret_pivot),true,false) as Node3D
					trial.gun_pivot=model.find_child(str(interface.nodes.gun_pivot),true,false) as Node3D
					trial.turret_yaw_deg=yaw_step; trial.gun_pitch_deg=pitch_step; trial._apply_weapon_pose()
					_check(is_instance_valid(trial.turret_pivot) and is_equal_approx(trial.turret_pivot.rotation.y,deg_to_rad(yaw_step)),id+": reference yaw reaches the real TurretPivot")
					_check(is_instance_valid(trial.gun_pivot) and is_equal_approx(trial.gun_pivot.rotation.x,deg_to_rad(pitch_step)),id+": reference elevation reaches the real GunPivot")
					model.free()
		trial.free()
	_check(modeled==113,"all 113 available models reached runtime mobility configuration")
	_check(tracked_interfaces==103 and wheeled_interfaces==10,"all model locomotion interfaces are exact: 103 tracked and 10 wheeled")
	_check(packet_sources==2 and reference_sources==111,"two combat packets override their trial values; 111 static models use exact cache profiles")
	# The lossy cache currently contains three distinct forward-speed values across
	# the modeled set (109 rows share 75 km/h). Preserve that source truth; never
	# invent extra variation merely to make the fleet look more diverse.
	_check(speed_values.size()==3,"research trial preserves all three speed values actually present in the cache")
	var static_tamper: Dictionary=rows.ussr_t_34_1941.duplicate(true)
	static_tamper.source_sha256="tampered"
	_check(not ResearchReferenceProfiles.mobility_for(static_tamper).ok,"tampered cache identity/hash cannot affect a trial")
	var combat_tamper: Dictionary=rows.ussr_t_80b.duplicate(true)
	combat_tamper.combat_package.sha256="tampered"
	_check(not ResearchReferenceProfiles.mobility_for(combat_tamper).ok,"tampered combat packet cannot affect a trial")
	print("=== result: %d checks, %d failed ==="%[checks,failed])
	print("RESEARCH_TRIAL_DATA_CHECKS_PASS" if failed==0 else "RESEARCH_TRIAL_DATA_CHECKS_FAIL")
	quit(0 if failed==0 else 1)
