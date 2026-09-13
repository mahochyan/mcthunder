extends SceneTree
# WT-024: the server-authority contract. The state table and protocol versions are read
# from the implementation, a client may send commands and acknowledgements only, one peer
# owns one controllable vehicle across reconnect, observers compare one result digest, and
# the authoritative paths are data rather than display resources.
var count := 0
var failed := 0
func _initialize() -> void:
	call_deferred("_run")
	var timer := create_timer(120.0)
	timer.timeout.connect(func() -> void: print("[FAIL] authority suite watchdog timeout"); quit(1))
func _check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func _run() -> void:
	root.size = Vector2i(1280,720)
	# --- 1. protocol versions are read from the implementation, never invented ---
	var versions := NetworkAuthorityContract.protocol_versions()
	_check(int(versions.network) == VehicleFramePose.NETWORK_VERSION,"the network version matches the implementation (%d)"%int(versions.network))
	_check(int(versions.journal) == NetworkEventJournal.VERSION,"the event journal version matches the implementation (%d)"%int(versions.journal))
	_check(int(versions.command) == VehicleCommandCodec.VERSION,"the command version matches the implementation (%d)"%int(versions.command))
	_check(int(versions.frame_pose) == VehicleFramePose.VERSION,"the frame pose version matches the implementation (%d)"%int(versions.frame_pose))
	_check(int(versions.network) == 6 and int(versions.journal) == 1 and int(versions.command) == 3,"the shipped protocol triple is 6/1/3")
	# --- 2. the authoritative state table ---
	_check(NetworkAuthorityContract.owns("match") and NetworkAuthorityContract.owns("vehicles"),"the server owns the match and the vehicles")
	for area in ["match","objectives","vehicles","ammunition","damage","world","session"]:
		_check(NetworkAuthorityContract.owns(area),"the server owns %s"%area)
	_check(not NetworkAuthorityContract.owns("client_ui"),"a client-side area is not server-owned")
	var fields := NetworkAuthorityContract.authoritative_fields()
	_check(fields.size() >= 20,"the authority table enumerates its fields (%d)"%fields.size())
	var display_tokens := ["scene","mesh","visual","material","texture","tscn"]
	var display_free := true
	for field in fields:
		for token in display_tokens:
			if field.to_lower().contains(token): display_free = false
	_check(display_free,"no authoritative field is a display resource (authority is data, not presentation)")
	# --- 3. a client may send commands and acknowledgements only ---
	_check(NetworkAuthorityContract.validate_client_message({"type":"hello"}).ok,"the handshake is accepted")
	for control in ["baseline_ack","events_ack","events_request","final_ack"]:
		_check(NetworkAuthorityContract.validate_client_message({"type":control}).ok,"%s is an accepted control message"%control)
	var good := {"type":"command","envelope":{"entity_id":"A","command":{"throttle":1.0,"fire_requested":true}}}
	_check(NetworkAuthorityContract.validate_client_message(good).ok,"a well-formed command envelope is accepted")
	_check(not NetworkAuthorityContract.validate_client_message({}).ok,"a message without a type is refused")
	_check(str(NetworkAuthorityContract.validate_client_message({"type":"nonsense"}).reason) == "unsupported_message","an unknown message type is refused")
	for field in ["result","tickets","kills","position","ammo","cooldown","damage","smoke_stock","repair_amount","instant_repair","life_id"]:
		var message := {"type":"command","envelope":{"entity_id":"A",field:1}}
		var verdict := NetworkAuthorityContract.validate_client_message(message)
		_check(not verdict.ok and str(verdict.reason) == "client_cannot_author_state","a client cannot submit %s"%field)
	var state_message := {"type":"state_update","tickets":{"1":0,"2":300},"kills":5}
	_check(not NetworkAuthorityContract.validate_client_message(state_message).ok,"a state update carrying tickets and kills is refused")
	_check(NetworkAuthorityContract.validate_client_message({"type":"command","envelope":{"entity_id":"A","command":{"throttle":0.5}}}).reason == "command_is_the_only_gameplay_input","the accepted reason states that commands are the only gameplay input")
	# --- 4. one peer owns one controllable vehicle across a reconnect ---
	var contract := NetworkAuthorityContract.new()
	_check(contract.assign(1,"A",7,4).ok and contract.assign(2,"B",7,4).ok,"two peers are assigned two different vehicles")
	_check(contract.controllable_vehicles() == 2,"two peers mean two controllable vehicles")
	var stolen := contract.assign(3,"A",7,4)
	_check(not stolen.ok and str(stolen.reason) == "entity_already_owned","a third peer cannot take an already-owned vehicle")
	var resumed := contract.resume(1,"A",8,4)
	_check(resumed.ok and contract.controllable_vehicles() == 2,"a reconnect with a new life resumes the same vehicle and adds no second one")
	_check(int(contract.owners[1].life_id) == 8,"the resumed owner carries the new life id")
	var wrong := contract.resume(2,"A",8,4)
	_check(not wrong.ok and str(wrong.reason) == "entity_mismatch_on_resume","a peer cannot resume someone else's vehicle")
	_check(contract.release(1).ok and contract.controllable_vehicles() == 1,"releasing a peer frees exactly its vehicle")
	_check(contract.assign(1,"A",9,4).ok and contract.controllable_vehicles() == 2,"the freed vehicle can be reassigned")
	_check(contract.release(99).reason == "unknown_peer","releasing an unknown peer is refused")
	# --- 5. two observers compare one authoritative result ---
	var c1 := {"digest":"e2d3b8a6","event_sequence":8}
	var c2 := {"digest":"e2d3b8a6","event_sequence":8}
	var c3 := {"digest":"00000000","event_sequence":8}
	_check(contract.observers_agree(c1,c2),"two observers with the same digest and sequence agree on the result")
	_check(not contract.observers_agree(c1,c3),"different digests mean the observers disagree")
	_check(not contract.observers_agree(c1,{"digest":"","event_sequence":8}),"an empty digest never counts as agreement")
	_check(not contract.observers_agree(c1,{"digest":"e2d3b8a6","event_sequence":9}),"a different event sequence is not the same result")
	# --- 6. display resources are not required by the authoritative path ---
	_check(NetworkAuthorityContract.display_independent(),"the contract declares the authoritative path display independent")
	var research_model := "res://assets/research/models/ussr_t_80b.glb"
	var has_import := ResourceLoader.exists(research_model)
	var file_exists := FileAccess.file_exists(research_model)
	_check(file_exists,"the in-repo research model file is present as bytes")
	_check(not has_import,"it has no importable display resource (no .import companion), so a package may ship without it")
	_check(VehicleCatalog.IDS.size() == 4,"the authoritative vehicle catalog lists the four admitted vehicles")
	_check(FileAccess.file_exists("res://configs/vehicles/model_sources.json"),"the authoritative model-source registry is data on disk")
	_check(ResourceLoader.exists("res://configs/optics/m4a3_design.tres"),"authoritative optics data loads as a resource without any display asset")
	var tree_text := FileAccess.get_file_as_string("res://assets/research/soviet_german_tree.json")
	_check(tree_text.length() > 1000,"the authoritative content tree reads as data (%d bytes)"%tree_text.length())
	var snapshot := contract.snapshot()
	for field in ["authority","protocol","authoritative_state","accepted_client_messages","forbidden_client_fields"]:
		_check(snapshot.has(field),"the contract snapshot exposes %s for the authority state table"%field)
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("NETWORK_AUTHORITY_CHECKS_PASS" if failed == 0 else "NETWORK_AUTHORITY_CHECKS_FAIL")
	quit(1 if failed else 0)
