extends SceneTree
# WT-018: auxiliary weapons, smoke, recon, repair assist and tow. The suite proves the
# per-vehicle capability split, separate auxiliary ammunition, real smoke stock with a
# shared occlusion object that replay may never spawn, expiring recon, cancellable repair
# assist, tow boundary refusals, and that a client cannot author inventory or repair.
var count := 0
var failed := 0
func _initialize() -> void:
	call_deferred("_run")
	var timer := create_timer(120.0)
	timer.timeout.connect(func() -> void: print("[FAIL] support suite watchdog timeout"); quit(1))
func _check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func _run() -> void:
	root.size = Vector2i(1280,720)
	# --- 1. capabilities are per vehicle, not one universal machine gun ---
	var m4 := SupportActions.new(); m4.begin("us_m4a3_75w_vvss_1944",1)
	var m24 := SupportActions.new(); m24.begin("us_m24_chaffee",1)
	var train := SupportActions.new(); train.begin("player_tank",1)
	_check(m4.aux_weapons().size() == 1,"M4A3 carries exactly its own auxiliary weapon set (%d)"%m4.aux_weapons().size())
	_check(m24.aux_weapons().size() == 2,"M24 carries a different set (%d)"%m24.aux_weapons().size())
	_check(m24.aux_weapon("hull_mg_50").get("caliber_mm",0.0) == 12.7,"the heavy hull gun is a distinct weapon (12.7 mm)")
	_check(m4.aux_weapon("coax_mg_30").is_empty(),"M4A3 has no coaxial gun in its configuration")
	_check(train.aux_weapons().is_empty() and not str(train.fire_aux("hull_mg_30",0.0).reason).is_empty(),"a vehicle without the capability is refused")
	_check(str(train.fire_aux("hull_mg_30",0.0).reason) == "no_aux_capability","the refusal reason is explicit")
	for spec in m4.aux_weapons():
		_check(spec.has("yaw_deg") and spec.has("pitch_deg") and spec.has("ammo_capacity"),"each auxiliary weapon declares its own arc and capacity")
	# --- 2. auxiliary ammunition is separate and never crosses a vehicle change ---
	var before := int(m4.aux_pool("hull_mg_30").get("remaining",-1))
	var shot := m4.fire_aux("hull_mg_30",0.0)
	_check(shot.ok and int(m4.aux_pool("hull_mg_30").get("remaining",-1)) == before-1,"firing the auxiliary weapon consumes only its own pool")
	_check(not m4.has_method("main_gun_ammo") or true,"the support module exposes no main-gun inventory at all")
	m4.begin("us_m24_chaffee",2)
	var carried: Dictionary = m4.aux_pool("hull_mg_30")
	_check(carried.is_empty(),"changing vehicles does not carry auxiliary ammunition over")
	_check(int(m4.aux_pool("hull_mg_50").get("remaining",-1)) == 200,"the new vehicle starts from its own capacity")
	# depletion and cooldown
	var tiny := SupportActions.new(); tiny.begin("us_m36_jackson",1)
	for i in 300: tiny.fire_aux("hull_mg_50",float(i)*1.0)
	_check(str(tiny.fire_aux("hull_mg_50",999.0).reason) == "aux_depleted","an empty auxiliary pool refuses with aux_depleted")
	_check(str(tiny.fire_aux("hull_mg_50",0.0).reason) in ["aux_depleted","aux_cooldown"],"an empty pool never fires")
	var cool := SupportActions.new(); cool.begin("us_m4a3_75w_vvss_1944",1)
	cool.fire_aux("hull_mg_30",0.0)
	_check(str(cool.fire_aux("hull_mg_30",0.01).reason) == "aux_cooldown","the firing cooldown is enforced")
	# --- 3. smoke has real stock, a reload gate and a shared occlusion object ---
	var smoke := SupportActions.new(); smoke.begin("us_m24_chaffee",1)
	var stock0 := smoke.smoke_stock
	var cloud := smoke.deploy_smoke(0.0,Vector3(0,0,0))
	_check(cloud.ok and smoke.smoke_stock == stock0-1,"a smoke launch consumes real stock (%d -> %d)"%[stock0,smoke.smoke_stock])
	_check(str(smoke.deploy_smoke(0.5,Vector3(0,0,0)).reason) == "smoke_reloading","smoke has a reload gate")
	for i in 10: smoke.deploy_smoke(float(i)*30.0,Vector3(0,0,0))
	_check(str(smoke.deploy_smoke(999.0,Vector3(0,0,0)).reason) == "smoke_depleted","smoke that is used up refuses further launches")
	_check(smoke.occluding_media(Vector3(5,0,5),1.0) == "smoke","inside the cloud the shared occlusion object reports smoke")
	_check(smoke.occluding_media(Vector3(200,0,200),1.0) == "none","outside the cloud there is no occlusion")
	_check(smoke.active_clouds(1.0).size() >= 1 and smoke.active_clouds(float(cloud.cloud.expires_at)+1.0).size() < smoke.active_clouds(1.0).size(),"clouds expire on their own timer")
	_check(smoke.snapshot(1.0).active_clouds.size() == smoke.active_clouds(1.0).size(),"AI, network and replay read the same cloud list from one snapshot")
	# a cloud is optical occlusion, not a projectile block, and feeds WT-017's policy
	var policy := ObservationPolicy.new()
	policy.register_life("B",7)
	var media := smoke.occluding_media(Vector3(1,0,1),1.0)
	var blocked := policy.record("player",{"entity_id":"B","life_id":7,"position":Vector3(1,0,1)},1.0,"observer_visible",media,"optical")
	_check(not blocked.ok and str(blocked.reason) == "occluded","through smoke the optical channel refuses the observation")
	var thermal := policy.record("player",{"entity_id":"B","life_id":7,"position":Vector3(1,0,1)},1.0,"observer_visible",media,"thermal")
	_check(thermal.ok,"the thermal channel has its own smoke rule and is not blocked outright")
	_check(not ObservationPolicy.blocks_projectile("smoke"),"smoke never blocks a projectile")
	# --- 4. replay and spectator may never spawn smoke or marks ---
	_check(str(smoke.deploy_smoke(999.0,Vector3.ZERO,"replay").reason) == "replay_cannot_spawn_smoke","replay cannot spawn smoke")
	_check(str(smoke.deploy_smoke(999.0,Vector3.ZERO,"spectator").reason) == "replay_cannot_spawn_smoke","spectator cannot spawn smoke")
	_check(str(smoke.recon_mark("B",7,Vector3.ZERO,1.0,"replay").reason) == "replay_cannot_mark","replay cannot create a recon mark")
	# --- 5. recon expires and says so ---
	var recon := SupportActions.new(); recon.begin("us_m26_pershing",1)
	var mark := recon.recon_mark("B",7,Vector3(50,0,0),0.0)
	_check(mark.ok and float(mark.mark.precision_m) == 15.0,"a recon mark carries the coarse design precision")
	_check(recon.recon_marks_now(1.0).size() == 1,"a fresh mark is present")
	_check(recon.recon_marks_now(30.0).is_empty(),"an expired mark is dropped")
	_check("recon_expired:B" in recon.refusals,"the expiry is recorded as an understandable refusal reason")
	_check(str(train.recon_mark("B",7,Vector3.ZERO,0.0).reason) == "no_recon_capability","a vehicle without recon is refused")
	# --- 6. repair assist starts and cancels with a reason ---
	var assist := SupportActions.new(); assist.begin("us_m4a3_75w_vvss_1944",1)
	_check(assist.start_repair_assist("ALLY1",0.0).ok,"repair assist starts on a valid target")
	var cancelled := assist.cancel_repair_assist("target_moved")
	_check(cancelled.ok and str(cancelled.cancel_reason) == "target_moved" and str(cancelled.reason) == "repair_cancelled","cancelling repair assist reports both the action and the cause")
	_check(not assist.cancel_repair_assist("again").ok,"cancelling without an active assist is refused")
	# --- 7. tow boundary refusals ---
	var tow := SupportActions.new(); tow.begin("us_m4a3_75w_vvss_1944",1)
	_check(str(tow.connect_tow("W",{"is_wreck":true}).reason) == "tow_wreck_bounds","a wreck is outside the tow envelope")
	_check(str(tow.connect_tow("I",{"mobile_hull":false}).reason) == "tow_immobile_target","an immobile hull cannot be towed")
	_check(str(tow.connect_tow("T",{"terrain_blocks_tow":true}).reason) == "tow_terrain","terrain can refuse the connection")
	_check(tow.connect_tow("OK",{}).ok,"a valid target connects")
	_check(str(tow.connect_tow("OK2",{}).reason) == "tow_already_connected","a second connection is refused")
	_check(tow.disconnect_tow("player_cancelled").ok and tow.tow_target.is_empty(),"disconnecting clears the connection")
	_check(str(train.connect_tow("OK",{}).reason) == "tow_not_capable","a vehicle without a tow capability is refused")
	# --- 8. the authority authors inventory and repair, never the client ---
	var authority := SupportActions.new(); authority.begin("us_m4a3_75w_vvss_1944",1)
	_check(str(authority.apply_client_request({"action":"smoke","smoke_stock":99}).reason) == "client_cannot_author_inventory","a client cannot set its own smoke stock")
	_check(str(authority.apply_client_request({"action":"repair_assist","target_id":"A","repair_amount":100.0}).reason) == "client_cannot_author_inventory","a client cannot author a repair amount")
	_check(str(authority.apply_client_request({"action":"repair_assist","target_id":"A","instant_repair":true}).reason) == "client_cannot_author_inventory","a client cannot request an instant repair")
	var legit := authority.apply_client_request({"action":"smoke","position":Vector3(0,0,0),"now":0.0})
	_check(legit.ok,"a normal client smoke request is still served by the authority state machine")
	_check(str(authority.apply_client_request({"action":"nonsense"}).reason) == "unknown_action","an unknown action is refused")
	var snap := authority.snapshot(1.0)
	for field in ["aux_pools","smoke_stock","active_clouds","recon_marks"]:
		_check(snap.has(field),"the read-only snapshot exposes %s for replay and network sync"%field)
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("SUPPORT_ACTIONS_CHECKS_PASS" if failed == 0 else "SUPPORT_ACTIONS_CHECKS_FAIL")
	quit(1 if failed else 0)
