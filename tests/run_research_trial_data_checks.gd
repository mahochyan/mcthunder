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
	var speed_values: Dictionary={}
	for id in rows:
		var row: Dictionary=rows[id]
		if not row.get("model") is Dictionary: continue
		modeled+=1
		var trial:=ResearchTrialDrive.new(); trial.row=row
		_check(trial.configure_mobility(),id+": hash-bound mobility config resolves")
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
		trial.free()
	_check(modeled==113,"all 113 available models reached runtime mobility configuration")
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
