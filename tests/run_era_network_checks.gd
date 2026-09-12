extends "res://tests/run_network_event_recovery_checks.gd"
const ERA_PORT := 19119
const EraFixture=preload("res://tests/fixtures/reactive_profile.gd")
const HeatFixture=preload("res://tests/fixtures/chemical_profile.gd")

class SnapshotLossClient extends NetworkBattleClient:
	var drop_snapshots := false
	var dropped := 0
	func accept_message(message: Dictionary) -> bool:
		if drop_snapshots and message.get("type")=="snapshot": dropped+=1; return false
		return super.accept_message(message)

func charge(client: NetworkBattleClient, entity: String, tile: String) -> int:
	for row in client.latest.get("vehicles",[]):
		if row.entity_id==entity: return int(row.get("reactive_armor",{}).get(tile,-1))
	return -1

func era_shot(world: NetworkBattleWorld, target: VehicleActor) -> ProjectileState:
	fixture_shot+=1
	var result := world.projectiles.try_spawn({"round_id":1,"shooter_id":"A","shooter_life_id":1,"shot_id":fixture_shot,"shell_id":"TEST_ERA_HEAT",
		"position_world":target.tank.global_transform*Vector3(0,2,4),"velocity_world":Vector3(0,0,-600),"gravity_world":Vector3.ZERO,
		"effect_policy":"chemical","impact_profile":HeatFixture.impact(),"chemical_profile":HeatFixture.profile(),"caliber_mm":120,
		"penetration_curve":PackedVector2Array([Vector2(0,100),Vector2(1000,100)]),"max_age_s":2.0,"max_distance_m":1000.0})
	check(result.ok,"actual server projectile manager accepts bounded chemical test shot")
	world.flush_launches() # Test admission occurs outside the normal vehicle phase.
	return world.projectiles.get_projectile_state(result.projectile_id)

func run() -> void:
	var space := SubViewport.new(); space.own_world_3d=true; root.add_child(space)
	var server := NetworkBattleServer.new(); space.add_child(server)
	check(server.start(ERA_PORT)==OK and server.world.ready_ok,"real local ENet ERA authority starts on dedicated port")
	if not server.world.ready_ok: space.free(); quit(1); return
	var target: VehicleActor=server.world.actors[1]
	var layout := ShellTrainingTargets.build(20,4,false)
	for patch in layout.armor_patches: patch.material_kind="rolled"
	layout.armor_patches[4].reactive_profile=EraFixture.profile()
	target.set_damage_layout(layout)
	var tile: String=layout.armor_patches[4].id
	var a := SnapshotLossClient.new(); root.add_child(a); a.connect_local(ERA_PORT)
	check(await until(func() -> bool: return a.status=="connected" and charge(a,"B",tile)==1),"initial real network baseline includes unused ERA charge")
	if a.latest.is_empty():
		print("[DETAIL] ",a.status," snapshot_valid=",NetworkPoseBuffer.valid_snapshot(server.world.snapshot(1))," charges=",target.state.reactive_armor," charge_valid=",ReactiveArmorProfile.valid_state(target.state.reactive_armor))
		print("[DETAIL] snapshot=",server.world.snapshot(1))
		a.free(); space.free(); quit(1); return
	check(a.latest.version==6,"ERA state is carried by explicit protocol v6")
	a.drop_snapshots=true
	var first := era_shot(server.world,target)
	check(await until(func() -> bool: return first.is_terminal()),"server advances real HEAT to terminal armor contact")
	check(first.contacts.size()==1 and first.contacts[0].reactive_triggered and target.state.reactive_armor[tile]==0,"server atomically consumes tile exactly once")
	await ticks(9)
	check(a.dropped>0 and charge(a,"B",tile)==1,"test drops application snapshots and preserves the client's previous view")
	a.drop_snapshots=false
	check(await until(func() -> bool: return charge(a,"B",tile)==0),"next real snapshot recovers current spent state without replaying a hit")
	var b := NetworkBattleClient.new(); root.add_child(b); b.connect_local(ERA_PORT)
	check(await until(func() -> bool: return b.status=="connected" and charge(b,"B",tile)==0),"late joining real second client receives spent ERA baseline")
	var second := era_shot(server.world,target)
	check(await until(func() -> bool: return second.is_terminal()),"server resolves repeated real hit after consumption")
	check(second.contacts[0].reactive_before==0 and not second.contacts[0].reactive_triggered and is_equal_approx(second.contacts[0].effective_mm,20),"second network-world hit receives passive protection only")
	a.close(); check(await until(func() -> bool: return server.owners.size()==1),"server observes transport disconnect")
	a.connect_local(ERA_PORT)
	check(await until(func() -> bool: return a.status=="connected" and charge(a,"B",tile)==0),"reconnected client receives existing spent state rather than fresh charges")
	var stale := a.latest.duplicate(true)
	target.reset_vehicle()
	check(await until(func() -> bool: return charge(a,"B",tile)==1 and charge(b,"B",tile)==1),"real generation reset restores tile state to both clients")
	var before := a.latest.duplicate(true)
	check(not a.accept_message({"type":"snapshot","snapshot":stale,"own_status":a.own_status}) and a.latest==before,"delayed pre-reset snapshot cannot undo new-generation armor state")
	for bad_value in [2,-1,true,null]:
		var bad := a.latest.duplicate(true); bad.sequence+=1; bad.tick+=1
		bad.vehicles[1].reactive_armor[tile]=bad_value
		check(not a.accept_message({"type":"snapshot","snapshot":bad,"own_status":a.own_status}) and a.latest==before,"malformed charge snapshot is rejected atomically")
	server.finish()
	check(await until(func() -> bool: return a.status=="finished" and b.status=="finished"),"both real clients finish with frozen state")
	check(a.final_payload==b.final_payload and charge(a,"B",tile)==1,"final identical authoritative payload includes charge state")
	a.free(); b.free(); space.free(); await process_frame
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("ERA_NETWORK_CHECKS_PASS" if failures==0 else "ERA_NETWORK_CHECKS_FAIL")
	quit(0 if failures==0 else 1)
