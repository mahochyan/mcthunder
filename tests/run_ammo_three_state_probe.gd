extends "res://tests/run_modern_candidate_checks.gd"
## MCT-COMBAT-DEEPEN-01 · CD001 first action (scope source: 02_FIRST_DELIVERY.md "第一个实际动作").
##
## On the two engineering vehicles, LOCK one live-fire path that actually reaches the known ready rack, then obtain
## FULL / HALF / EMPTY through NORMAL configuration and NORMAL consumption and read, per state: the contact objects,
## the armour budget, the damage rows, the inventory before and after, and the event identity - then name the first
## divergence point and report the delivery's named risk (an empty rack that still takes ammunition damage or a
## consumption budget).
##
## Discipline: a MEASUREMENT. No production file is written, no sub-order or scenario number is invented, no
## expectation is changed, and HALF/EMPTY come from firing plus the real load request the game uses - never from
## assigning a state field. The path is not assumed: it is locked empirically by requiring a damage row whose
## item_id is the ready rack, exactly the evidence the compartment fixture asserts.
const FIXTURE_PREFIX := "test_cd001_"
const RACK_ID := "ammo_ready"
const RELOAD_FRAMES := 560
const RECOVERY_FRAMES := 3600
const ADVANCE_STEPS := 40
const PARTS := ["turret","hull"]
const STANDOFFS := [-5.0,-6.0,-8.0,-10.0,-12.0]
var sequence := 0
var locked := {}

func _state(actor: VehicleActor, tag: String) -> Dictionary:
	var inv: AmmoInventory = actor.gunner.inventory
	return {"tag":tag,"chamber":inv.chamber,"in_transfer":inv.in_transfer,"racks":inv.racks.duplicate(),
		"available":inv.total_available(),"supplied":inv.supplied,"fired":inv.fired,"lost":inv.lost,
		"conserved":inv.conserved(),"generation":actor.state.generation,"life_id":actor.life_id}

func _rack_row(packet: Dictionary) -> Dictionary:
	for row in packet.modules:
		if row.id==RACK_ID: return row
	return {}

## Fresh world, actor and manager per measurement, with the damage handler bound the way the fixture binds it.
func _spawn(world_out: Array) -> VehicleActor:
	var world := Node3D.new(); root.add_child(world)
	var manager := ProjectileManager.new(); manager.presentation_enabled=false; world.add_child(manager); manager.set_physics_process(false)
	world_out.append(world); world_out.append(manager)
	return null

func _actor(world: Node3D, manager: ProjectileManager, defs: VehicleDefs, packet: Dictionary) -> VehicleActor:
	var actor := VehicleActor.new(); world.add_child(actor)
	check(actor.setup(defs,packet.id,"cd001_target",1,Transform3D.IDENTITY,2,null).ok,"CD001 target installs the authored internal layout ("+packet.id+")")
	actor.set_physics_process(false); actor.tank.set_physics_process(false)
	actor.gunner.projectile_manager = manager
	manager.damage_handler = Callable(actor,"apply_projectile_damage")
	return actor

## The same live-fire spec the compartment fixture uses, with the path parameters made explicit.
func _live_fire(actor: VehicleActor, manager: ProjectileManager, world: Node3D, rack: Dictionary, part: String, standoff: float) -> ProjectileState:
	sequence += 1
	var shell: ShellDefinition = actor.gunner.shell_options[0]
	var frame: Transform3D = actor.turret.global_transform if part=="turret" else actor.tank.global_transform
	var position := HistoricalVehicleGeometry.vec(rack.position)
	position.x = standoff
	var spec := {"round_id":1515,"shooter_id":"cd001_probe","shooter_life_id":1,"shot_id":sequence,"shell_id":shell.id,
		"effect_policy":shell.effect_policy,"impact_profile":shell.impact_profile,"caliber_mm":shell.caliber_mm,
		"penetration_curve":shell.penetration_curve,"seed":1515,"position_world":frame*position,
		"velocity_world":frame.basis*Vector3(1650,0,0),"gravity_world":Vector3.ZERO,"max_age_s":0.4,"max_distance_m":200.0}
	var result := manager.try_spawn(spec)
	if not result.ok: return null
	var projectile: ProjectileState = manager.get_projectile_state(result.projectile_id)
	for i in ADVANCE_STEPS:
		if projectile.is_terminal(): break
		manager.advance_projectile(projectile,1.0/120.0,[QuerySnapshotBuilder.build_from_vehicle(actor.tank,actor.damage_layout_override)],world.get_world_3d().direct_space_state)
	return projectile

func _reached_rack(projectile: ProjectileState) -> bool:
	if projectile == null: return false
	for event in projectile.damage_records:
		if str(event.get("item_id",""))==RACK_ID: return true
	return false

## Lock the path empirically on a scratch actor, requiring the ready rack damage row as the evidence of arrival.
func _lock_path(id: String, defs: VehicleDefs, packet: Dictionary, rack: Dictionary) -> Dictionary:
	for part in PARTS:
		for standoff in STANDOFFS:
			var holder: Array = []
			_spawn(holder)
			var world: Node3D = holder[0]
			var manager: ProjectileManager = holder[1]
			var actor := _actor(world,manager,defs,packet)
			await _frames(2)
			var projectile := _live_fire(actor,manager,world,rack,part,standoff)
			var hit := _reached_rack(projectile)
			print("[CD001 %s] path probe part=%s standoff=%.1f contacts=%d rack_row=%s" % [id,part,standoff,projectile.contacts.size() if projectile!=null else -1,str(hit)])
			if hit:
				world.queue_free(); await _frames(2)
				return {"part":part,"standoff":standoff}
			world.queue_free(); await _frames(2)
	return {}

## Normal consumption only: real fire request, real load request, then let the mechanism work through the ordinary
## command consumer.
## Load the chamber FIRST and only then fire. The earlier order fired into an empty chamber, which the gunner
## correctly blocks with chamber_empty, and this loop then mis-counted that as a failed iteration and stopped.
func _ready_chamber(actor: VehicleActor) -> bool:
	var guard := 0
	while guard < RELOAD_FRAMES:
		guard += 1
		if actor.gunner.inventory.chamber > 0: return true
		actor.gunner.request_load()
		actor._apply_command_once(VehicleCommand.new(),1.0/60.0)
	return actor.gunner.inventory.chamber > 0

func _fire_and_reload(actor: VehicleActor) -> bool:
	if not _ready_chamber(actor): return false
	var before_fired: int = actor.gunner.inventory.fired
	var fire := VehicleCommand.new()
	fire.fire_requested = true
	actor._apply_command_once(fire,1.0/60.0)
	# Each ordinary shot spawns a real projectile; the fixture clears them after every shot, so this measurement does
	# the same. Without it the live-projectile cap is reached and firing stops consuming.
	if actor.gunner.projectile_manager != null: actor.gunner.projectile_manager.cancel_all("cd001_consume")
	return actor.gunner.inventory.fired > before_fired

## Measurement, not a fix: pump a long window and see whether the game replenishes the feed by itself.
func _auto_recovery_probe(actor: VehicleActor) -> bool:
	print("[CD001 RECOVERY PROBE] start: available=%d chamber=%d in_transfer=%d feed=%s cooldown=%.2f" % [
		actor.gunner.inventory.total_available(),actor.gunner.inventory.chamber,actor.gunner.inventory.in_transfer,
		actor.gunner.loading_reason,actor.gunner.cooldown_left])
	for i in RECOVERY_FRAMES:
		if actor.gunner.inventory.chamber > 0: break
		if i % 60 == 0: actor.gunner.request_load()
		actor._apply_command_once(VehicleCommand.new(),1.0/60.0)
	var recovered: bool = actor.gunner.inventory.chamber > 0 or actor.gunner.loading_reason != "feed_empty"
	print("[CD001 RECOVERY PROBE] after %d frames: recovered=%s available=%d chamber=%d in_transfer=%d feed=%s racks=%s" % [
		RECOVERY_FRAMES,str(recovered),actor.gunner.inventory.total_available(),actor.gunner.inventory.chamber,
		actor.gunner.inventory.in_transfer,actor.gunner.loading_reason,JSON.stringify(actor.gunner.inventory.racks)])
	return recovered

## The game's own rack-move API, used only because the recovery probe showed no automatic replenishment. This is my
## driving method, recorded as such - not a claim about what production does or should do.
func _drive_replenishment(actor: VehicleActor) -> bool:
	var inv: AmmoInventory = actor.gunner.inventory
	var shell_id: String = actor.gunner.shell_options[0].id
	var empty_rack := ""
	var loaded_rack := ""
	for id in inv.racks:
		if int(inv.racks[id]) <= 0: empty_rack = id
		else: loaded_rack = id
	if empty_rack.is_empty() or loaded_rack.is_empty(): return false
	var reserved := inv.reserve_rack_move(loaded_rack,empty_rack,shell_id)
	print("[CD001 DRIVE] reserve_rack_move(%s -> %s, %s) ok=%s" % [loaded_rack,empty_rack,shell_id,str(reserved.get("ok",false))])
	if not reserved.get("ok",false): return false
	for i in RECOVERY_FRAMES:
		if inv.chamber > 0: break
		actor._apply_command_once(VehicleCommand.new(),1.0/60.0)
	if inv.has_rack_move(): inv.commit_rack_move(int(reserved.token))
	print("[CD001 DRIVE] after driving: available=%d chamber=%d feed=%s racks=%s" % [inv.total_available(),inv.chamber,actor.gunner.loading_reason,JSON.stringify(inv.racks)])
	return inv.chamber > 0

func _consume_until(actor: VehicleActor, stop_when: int) -> int:
	# The guard exists only to stop an infinite loop. It must not be tight enough to end the run while firing is still
	# making progress: the earlier limit of supplied+8 was consumed by the stall iterations themselves and stopped the
	# T-80B two rounds short of empty.
	var guard := 0
	var limit: int = actor.gunner.inventory.supplied * 4 + 40
	while actor.gunner.inventory.total_available() > stop_when and guard < limit:
		guard += 1
		if not _fire_and_reload(actor):
			# Real fields only: the earlier diagnostic named a field that does not exist and aborted the loop itself.
			print("[CD001 STALL] fired=%d available=%d chamber=%d in_transfer=%d cooldown=%.2f grace=%.2f blocked=%s last_shot=%s loading_reason=%s selected=%s counts=%s options=%s" % [
				actor.gunner.inventory.fired,actor.gunner.inventory.total_available(),actor.gunner.inventory.chamber,
				actor.gunner.inventory.in_transfer,actor.gunner.cooldown_left,actor.gunner.resume_grace,
				actor.gunner.blocked_reason,actor.gunner.last_shot_result,actor.gunner.loading_reason,
				actor.gunner.inventory.selected_shell,JSON.stringify(actor.gunner.inventory.shell_counts()),
				JSON.stringify(_option_ids(actor))])
			# A normal player action: if the currently selected shell has run out, select the one that still has rounds.
			if _select_shell_with_rounds(actor) and _ready_chamber(actor): continue
			if _auto_recovery_probe(actor): continue
			if _drive_replenishment(actor): continue
			break
	return actor.gunner.inventory.fired

func _option_ids(actor: VehicleActor) -> Array:
	var ids: Array = []
	for option in actor.gunner.shell_options: ids.append(option.id)
	return ids

func _select_shell_with_rounds(actor: VehicleActor) -> bool:
	var counts: Dictionary = actor.gunner.inventory.shell_counts()
	for index in actor.gunner.shell_options.size():
		var shell_id: String = actor.gunner.shell_options[index].id
		if int(counts.get(shell_id,0)) > 0 and shell_id != actor.gunner.inventory.selected_shell:
			if actor.gunner.select_shell(index):
				print("[CD001 DRIVE] selected %s because the previously selected shell had no rounds left" % shell_id)
				return true
	return false

func _measure(id: String, tag: String, defs: VehicleDefs, packet: Dictionary, rack: Dictionary) -> Dictionary:
	var holder: Array = []
	_spawn(holder)
	var world: Node3D = holder[0]
	var manager: ProjectileManager = holder[1]
	var actor := _actor(world,manager,defs,packet)
	await _frames(2)
	var supplied := actor.gunner.inventory.supplied
	if tag=="half": _consume_until(actor,maxi(0,int(supplied/2)))
	elif tag=="empty": _consume_until(actor,0)
	check(actor.gunner.inventory.conserved(),"CD001 inventory stays conserved in the %s state (%s)" % [tag,id])
	check(actor.gunner.inventory.chamber+actor.gunner.inventory.in_transfer<=1,"CD001 chamber and carried round never double-occupy (%s/%s)" % [id,tag])
	if tag=="empty": check(actor.gunner.inventory.total_available()==0,"CD001 EMPTY is reached by normal consumption, not by a field write (%s)" % id)
	var before := _state(actor,tag+"-before")
	print("[CD001 %s/%s] produced by normal firing: supplied=%d fired=%d available=%d chamber=%d in_transfer=%d" % [id,tag,before.supplied,before.fired,before.available,before.chamber,before.in_transfer])
	var projectile := _live_fire(actor,manager,world,rack,str(locked.get("part","turret")),float(locked.get("standoff",-5.0)))
	var after := _state(actor,tag)
	var contacts := 0
	var budget := {}
	var damage: Array = []
	if projectile != null:
		contacts = projectile.contacts.size()
		if contacts > 0:
			var first: Dictionary = projectile.contacts[0]
			budget = {"part_id":first.get("part_id",""),"before_mm":first.get("before_mm",null),
				"after_mm":first.get("after_mm",null),"result":first.get("result","")}
		for event in projectile.damage_records:
			damage.append({"item_id":event.get("item_id",""),"ammo_event":event.has("ammo_event"),"destroyed":event.get("destroyed",false)})
	var record: Dictionary = {}
	if manager.shot_records.count() > 0: record = manager.shot_records.get_record(manager.shot_records.count()-1)
	# Everything is captured before the world is freed: reading actor.state after queue_free() was my own defect.
	var reached := _reached_rack(projectile)
	var destroyed: bool = actor.state.destroyed
	var record_ok: bool = ShotRecordBuilder.validate(record).ok
	print("[CD001 %s/%s] after=%s" % [id,tag,JSON.stringify(after)])
	print("[CD001 %s/%s] contacts=%d budget=%s" % [id,tag,contacts,JSON.stringify(budget)])
	print("[CD001 %s/%s] damage=%s destroyed=%s rack_reached=%s" % [id,tag,JSON.stringify(damage),str(destroyed),str(reached)])
	print("[CD001 %s/%s] record_rules=%s record_valid=%s" % [id,tag,JSON.stringify(record.get("rules_versions",{})),str(record_ok)])
	world.queue_free(); await _frames(2)
	return {"id":id,"tag":tag,"before":before,"after":after,"contacts":contacts,"budget":budget,
		"damage":damage,"destroyed":destroyed,"reached":reached,"record_ok":record_ok}

func _compare(rows: Array, id: String) -> void:
	if rows.size() < 3: return
	var full: Dictionary = rows[0]; var half: Dictionary = rows[1]; var empty: Dictionary = rows[2]
	print("[CD001 %s] COMPARE available full/half/empty = %d/%d/%d ; lost = %d/%d/%d ; contacts = %d/%d/%d ; rack_reached = %s/%s/%s ; destroyed = %s/%s/%s" % [
		id,full.after.available,half.after.available,empty.after.available,
		full.after.lost,half.after.lost,empty.after.lost,full.contacts,half.contacts,empty.contacts,
		str(full.reached),str(half.reached),str(empty.reached),str(full.destroyed),str(half.destroyed),str(empty.destroyed)])
	# The delivery's named risk only means anything when the state really IS empty; in the earlier runs the "empty"
	# row still held rounds and the line was therefore my own logic error, which is corrected here.
	if empty.before.available > 0:
		print("[CD001 %s] NOT-APPLICABLE: the empty row was not actually empty (available=%d), so the delivery's named risk is NOT tested by this run" % [id,empty.before.available])
	elif empty.after.lost > empty.before.lost:
		print("[CD001 %s] RED CASE: the empty rack still loses %d stored round(s) to the strike" % [id,empty.after.lost-empty.before.lost])
	else:
		print("[CD001 %s] empty rack takes no further stored-round loss from the strike (lost stays %d)" % [id,empty.after.lost])
	if full.after.lost == 0 and empty.after.lost == 0:
		print("[CD001 %s] NOTE: stored-round loss is zero in BOTH full and empty states, so this path does not debit the rack in either state and the empty-versus-full comparison does not by itself clear the delivery's named risk" % id)
	for key in ["chamber","in_transfer","available","lost"]:
		print("[CD001 %s] divergence probe %s: full=%s half=%s empty=%s" % [id,key,str(full.after[key]),str(half.after[key]),str(empty.after[key])])

## The four boundaries the delivery sheet names next: carried round, two events in one tick, a new life, and the
## reservation revision that stands in for the ammunition-side cache token.
func _hit_event(actor: VehicleActor, module_id: String, event_id: String, tick: int) -> Dictionary:
	var event := {"kind":"module","entity_id":actor.entity_id,"life_id":actor.life_id,"target_generation":actor.state.generation,
		"event_id":event_id,"round_id":1515,"shooter_id":"cd001_probe","shooter_life_id":1,"shot_id":1,"projectile_id":1,
		"module_id":module_id,"physics_tick":tick}
	var result := actor.apply_projectile_damage(event,500)
	event.merge(result,true)
	return event

func boundary_checks(id: String, defs: VehicleDefs, packet: Dictionary, rack: Dictionary) -> void:
	# 1) A carried round is one physical location, and a strike on its source must not resurrect or double-count it.
	var holder: Array = []
	var actor := _fresh(defs,packet,holder)
	var world: Node3D = holder[0]
	var manager: ProjectileManager = holder[1]
	await _frames(2)
	actor.gunner.inventory.consume_chamber()
	var shell_id: String = actor.gunner.shell_options[0].id
	var opened: bool = actor.gunner.inventory.begin_transfer_from("ammo_ready",shell_id)
	check(opened and actor.gunner.inventory.in_transfer==1 and actor.gunner.inventory.chamber==0,"CD001 a carried round opens on the real ready rack ("+id+")")
	check(actor.gunner.inventory.conserved() and actor.gunner.inventory.chamber+actor.gunner.inventory.in_transfer<=1,"CD001 a carried round occupies one location, not two ("+id+")")
	var before := _state(actor,"transfer")
	_live_fire(actor,manager,world,rack,str(locked.get("part","turret")),float(locked.get("standoff",-5.0)))
	var after := _state(actor,"transfer")
	print("[CD001 %s/carried] before=%s after=%s destroyed=%s" % [id,JSON.stringify(before),JSON.stringify(after),str(actor.state.destroyed)])
	check(actor.gunner.inventory.conserved(),"CD001 conservation holds through a strike while carrying ("+id+")")
	world.queue_free(); await _frames(2)

	# 2) Two events in one tick: an identical event must not debit twice; a distinct one must keep the ledger conserved.
	var holder2: Array = []
	var actor2 := _fresh(defs,packet,holder2)
	await _frames(2)
	var first := _hit_event(actor2,"ammo_ready","cd001_same_tick_a",4242)
	var lost_after_first: int = actor2.gunner.inventory.lost
	var repeat := _hit_event(actor2,"ammo_ready","cd001_same_tick_a",4242)
	var lost_after_repeat: int = actor2.gunner.inventory.lost
	check(lost_after_repeat==lost_after_first and actor2.gunner.inventory.conserved(),"CD001 an identical same-tick event cannot debit the rack twice ("+id+")")
	var distinct := _hit_event(actor2,"ammo_ready","cd001_same_tick_b",4242)
	print("[CD001 %s/same_tick] lost first=%d repeat=%d distinct=%d destroyed=%s conserved=%s" % [id,lost_after_first,lost_after_repeat,actor2.gunner.inventory.lost,str(actor2.state.destroyed),str(actor2.gunner.inventory.conserved())])
	if not actor2.state.destroyed:
		check(actor2.gunner.inventory.conserved(),"CD001 a distinct same-tick event keeps the ledger conserved ("+id+")")
	else:
		print("[CD001 %s/same_tick] not applicable: the first same-tick strike already destroyed the vehicle, so a second distinct strike cannot land" % id)
	holder2[0].queue_free(); await _frames(2)

	# 3) A new life: the authored loadout returns and the ledger resets, and an old-generation event cannot debit it.
	var holder3: Array = []
	var actor3 := _fresh(defs,packet,holder3)
	await _frames(2)
	var authored: int = actor3.gunner.inventory.supplied
	var stale := _hit_event(actor3,"ammo_ready","cd001_respawn_a",777)
	actor3.reset_vehicle()
	var fresh := _state(actor3,"respawn")
	print("[CD001 %s/respawn] authored=%d fresh=%s" % [id,authored,JSON.stringify(fresh)])
	check(int(fresh.available)==authored and int(fresh.lost)==0 and int(fresh.fired)==0 and bool(fresh.conserved),"CD001 a new life restores the authored loadout and clears the ledger ("+id+")")
	actor3.apply_projectile_damage(stale,500)
	check(actor3.gunner.inventory.lost==0 and actor3.gunner.inventory.conserved(),"CD001 an old-generation event cannot debit the fresh life ("+id+")")
	holder3[0].queue_free(); await _frames(2)

	# 4) The ammunition-side revision: a reservation token is the cache token here, and a stale one must not commit.
	var inv := AmmoInventory.new()
	inv.configure_loadout({"ap":6},["ready","reserve"],{"ready":3,"reserve":3},"ap")
	inv.consume_chamber()
	var r1 := inv.reserve_rack_move("reserve","ready","ap")
	var r2 := inv.reserve_rack_move("reserve","ready","ap")
	check(bool(r1.get("ok",false)) and not bool(r2.get("ok",false)),"CD001 a second reservation is refused while one is outstanding ("+id+")")
	var committed: bool = inv.commit_rack_move(int(r1.token))
	var stale_commit: bool = inv.commit_rack_move(int(r1.token))
	print("[CD001 %s/revision] first=%s second=%s committed=%s stale_commit=%s outstanding=%s conserved=%s racks=%s" % [
		id,str(r1.get("ok",false)),str(r2.get("ok",false)),str(committed),str(stale_commit),str(inv.has_rack_move()),str(inv.conserved()),JSON.stringify(inv.racks)])
	check(committed and not stale_commit and inv.conserved(),"CD001 the current token commits once and a stale token cannot commit again ("+id+")")

func cd001_case(id: String) -> void:
	var packet := _read(PACKAGES+id+".json")
	packet.id = FIXTURE_PREFIX+id
	for source in packet.sources.values(): source.applies_to_identity_ids=[packet.id]
	var sources := fixture_asset(packet,1.0)
	var defs := VehicleDefs.new()
	var registered := VehicleCatalog.new(sources).register(packet,defs)
	check(registered.ok,"CD001 fixture package registers with isolated TEST ONLY art ("+id+")")
	if not registered.ok: print(registered.errors); return
	var rack := _rack_row(packet)
	if rack.is_empty(): check(false,"CD001 packet declares the known ready rack for "+id); return
	locked = await _lock_path(id,defs,packet,rack)
	check(not locked.is_empty(),"CD001 locks a live-fire path that actually reaches the ready rack ("+id+")")
	print("[CD001 %s] LOCKED path = %s" % [id,JSON.stringify(locked)])
	if locked.is_empty(): return
	var rows: Array = []
	for tag in ["full","half","empty"]: rows.append(await _measure(id,tag,defs,packet,rack))
	_compare(rows,id)
	await boundary_checks(id,defs,packet,rack)

func _fresh(defs: VehicleDefs, packet: Dictionary, out: Array) -> VehicleActor:
	_spawn(out)
	return _actor(out[0],out[1],defs,packet)

func _run() -> void:
	owned_directory="res://assets/vehicles/test_cd001_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	check(DirAccess.make_dir_recursive_absolute(owned_directory)==OK,"CD001 creates its own TEST ONLY model directory")
	var ignore := FileAccess.open(owned_directory.path_join(".gdignore"),FileAccess.WRITE); ignore.close()
	print("[CD001] source=02_FIRST_DELIVERY.md first action ; vehicles=" + str(MODERN))
	for id in MODERN: await cd001_case(id)
	for path in artifact_paths: DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(owned_directory.path_join(".gdignore")); DirAccess.remove_absolute(owned_directory)
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD001_THREE_STATE_PROBE_PASS" if failures==0 else "CD001_THREE_STATE_PROBE_FAIL")
	quit(0 if failures==0 else 1)
