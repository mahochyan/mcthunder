extends "res://tests/run_modern_candidate_checks.gd"
## MCT-COMBAT-DEEPEN-01 · CD001 first action (scope source: 02_FIRST_DELIVERY.md "第一个实际动作").
##
## On the two engineering vehicles, walk ONE live-fire path through the known ready rack, lock the real muzzle, target
## pose, shell, rules and armour configuration, obtain FULL / HALF / EMPTY through NORMAL configuration and NORMAL
## consumption, and read the contact objects, the armour budget, the damage, the inventory and the event identity -
## then name the first divergence point. If an empty rack still takes ammunition damage or a consumption budget that
## is the explicit red case the delivery asks for; if the empty path is already correct the measured result stands.
##
## Discipline: this file is a MEASUREMENT. It writes no production code, invents no sub-order or scenario number,
## changes no expectation and asserts only invariants that already exist in the code (`conserved()`). HALF and EMPTY
## are produced by firing through the normal command path the game uses - never by assigning a state field, which is
## what the existing compartment fixture does for its empty case.
const FIXTURE_PREFIX := "test_cd001_"
const RACK_ID := "ammo_ready"
const RELOAD_FRAMES := 520
var sequence := 0

func _state(actor: VehicleActor, tag: String) -> Dictionary:
	var inv: AmmoInventory = actor.gunner.inventory
	return {"tag":tag,"chamber":inv.chamber,"in_transfer":inv.in_transfer,"racks":inv.racks.duplicate(),
		"available":inv.total_available(),"supplied":inv.supplied,"fired":inv.fired,"lost":inv.lost,
		"conserved":inv.conserved(),"shells":inv.shell_counts(),"generation":actor.state.generation,"life_id":actor.life_id}

func _rack_row(packet: Dictionary) -> Dictionary:
	for row in packet.modules:
		if row.id==RACK_ID: return row
	return {}

## The same live-fire path the compartment fixture uses: real manager, real shell, real armour and layout snapshot.
func _live_fire(actor: VehicleActor, manager: ProjectileManager, world: Node3D, rack: Dictionary) -> ProjectileState:
	sequence += 1
	var shell: ShellDefinition = actor.gunner.shell_options[0]
	var frame: Transform3D = actor.turret.global_transform if str(rack.get("part",""))=="turret" else actor.tank.global_transform
	var position := HistoricalVehicleGeometry.vec(rack.position)
	position.x = -5
	var spec := {"round_id":1515,"shooter_id":"cd001_probe","shooter_life_id":actor.life_id,"shot_id":sequence,"shell_id":shell.id,
		"effect_policy":shell.effect_policy,"impact_profile":shell.impact_profile,"caliber_mm":shell.caliber_mm,
		"penetration_curve":shell.penetration_curve,"seed":1515,"position_world":frame*position,
		"velocity_world":frame.basis*Vector3(1650,0,0),"gravity_world":Vector3.ZERO,"max_age_s":0.1,"max_distance_m":100.0}
	var result := manager.try_spawn(spec)
	check(result.ok,"CD001 live-fire path is accepted by the real manager ("+actor.definition.id+")")
	if not result.ok: return null
	var projectile: ProjectileState = manager.get_projectile_state(result.projectile_id)
	for i in 24:
		if projectile.is_terminal(): break
		manager.advance_projectile(projectile,1.0/120.0,[QuerySnapshotBuilder.build_from_vehicle(actor.tank,actor.damage_layout_override)],world.get_world_3d().direct_space_state)
	check(projectile.is_terminal() and not projectile.contacts.is_empty(),"CD001 live-fire reaches the target through the production query")
	return projectile

## Normal consumption only: fire through the command consumer, then let the real mechanism load the next round.
func _fire_and_reload(actor: VehicleActor) -> bool:
	var before_fired: int = actor.gunner.inventory.fired
	var fire := VehicleCommand.new()
	fire.fire_requested = true
	actor._apply_command_once(fire,1.0/60.0)
	for i in RELOAD_FRAMES: actor._apply_command_once(VehicleCommand.new(),1.0/60.0)
	return actor.gunner.inventory.fired > before_fired

func _measure(actor: VehicleActor, manager: ProjectileManager, world: Node3D, rack: Dictionary, tag: String, id: String) -> Dictionary:
	var before := _state(actor,tag+"-before")
	var projectile := _live_fire(actor,manager,world,rack)
	var after := _state(actor,tag)
	var contacts := 0
	var budget := {}
	var damage: Array = []
	if projectile != null:
		contacts = projectile.contacts.size()
		if contacts > 0:
			var first: Dictionary = projectile.contacts[0]
			budget = {"part_id":first.get("part_id",""),"before_mm":first.get("before_mm",null),
				"after_mm":first.get("after_mm",null),"result":first.get("result",""),"patch_id":first.get("patch_id","")}
		for event in projectile.damage_records:
			damage.append({"item_id":event.get("item_id",""),"ammo_event":event.has("ammo_event"),"destroyed":event.get("destroyed",false)})
	var record: Dictionary = {}
	if manager.shot_records.count() > 0: record = manager.shot_records.get_record(manager.shot_records.count()-1)
	var identity := {"round_id":record.get("round_id",null),"shot_id":record.get("shot_id",null),
		"shooter_id":record.get("shooter_id",null),"shell_id":record.get("shell_id",null),
		"life_id":record.get("target_life_id",null),"generation":record.get("target_generation",null),
		"rules_versions":record.get("rules_versions",{})}
	print("[CD001 %s/%s] before=%s" % [id,tag,JSON.stringify(before)])
	print("[CD001 %s/%s] after =%s" % [id,tag,JSON.stringify(after)])
	print("[CD001 %s/%s] contacts=%d budget=%s" % [id,tag,contacts,JSON.stringify(budget)])
	print("[CD001 %s/%s] damage=%s destroyed=%s" % [id,tag,JSON.stringify(damage),str(actor.state.destroyed)])
	print("[CD001 %s/%s] identity=%s record_valid=%s" % [id,tag,JSON.stringify(identity),str(ShotRecordBuilder.validate(record).ok)])
	return {"id":id,"tag":tag,"before":before,"after":after,"contacts":contacts,"budget":budget,
		"damage":damage,"identity":identity,"destroyed":actor.state.destroyed,"record":record}

func three_state_case(id: String, packet: Dictionary, defs: VehicleDefs, world: Node3D, manager: ProjectileManager) -> Array:
	var rack := _rack_row(packet)
	if rack.is_empty(): check(false,"CD001 packet declares the known ready rack for "+id); return []
	var rows: Array = []
	var supplied := 0
	for tag in ["full","half","empty"]:
		var actor := VehicleActor.new(); world.add_child(actor)
		check(actor.setup(defs,packet.id,"cd001_target",1,Transform3D.IDENTITY,2,null).ok,"CD001 target installs the authored internal layout ("+id+")")
		actor.set_physics_process(false); actor.tank.set_physics_process(false)
		actor.gunner.projectile_manager = manager
		await _frames(2)
		supplied = actor.gunner.inventory.supplied
		# FULL is the authored default loadout. HALF and EMPTY come from normal firing only.
		if tag=="half":
			var half := maxi(1,int(supplied/2))
			var fired := 0
			while fired < half and actor.gunner.inventory.total_available() > 0:
				if _fire_and_reload(actor): fired += 1
			print("[CD001 %s/%s] produced by normal firing: supplied=%d fired=%d available=%d" % [id,tag,supplied,actor.gunner.inventory.fired,actor.gunner.inventory.total_available()])
		elif tag=="empty":
			var guard := 0
			while actor.gunner.inventory.total_available() > 0 and guard < supplied + 8:
				guard += 1
				if not _fire_and_reload(actor): break
			print("[CD001 %s/%s] produced by normal firing: supplied=%d fired=%d available=%d chamber=%d in_transfer=%d" % [id,tag,supplied,actor.gunner.inventory.fired,actor.gunner.inventory.total_available(),actor.gunner.inventory.chamber,actor.gunner.inventory.in_transfer])
			check(actor.gunner.inventory.total_available()==0,"CD001 EMPTY is reached by normal consumption, not by writing a field ("+id+")")
		check(actor.gunner.inventory.conserved(),"CD001 inventory stays conserved in the %s state (%s)" % [tag,id])
		check(actor.gunner.inventory.chamber+actor.gunner.inventory.in_transfer<=1,"CD001 chamber and carried round never double-occupy (%s/%s)" % [id,tag])
		rows.append(await _measure(actor,manager,world,rack,tag,id))
		actor.queue_free(); await _frames(2)
	return rows

func _compare(rows: Array, id: String) -> void:
	if rows.size() < 3: return
	var full: Dictionary = rows[0]
	var half: Dictionary = rows[1]
	var empty: Dictionary = rows[2]
	print("[CD001 %s] COMPARE available full/half/empty = %d/%d/%d ; lost = %d/%d/%d ; contacts = %d/%d/%d ; destroyed = %s/%s/%s" % [
		id,full.after.available,half.after.available,empty.after.available,
		full.after.lost,half.after.lost,empty.after.lost,
		full.contacts,half.contacts,empty.contacts,
		str(full.destroyed),str(half.destroyed),str(empty.destroyed)])
	# The delivery's named risk: an EMPTY rack must not still take ammunition damage or a consumption budget.
	var empty_lost: int = empty.after.lost
	var empty_before_lost: int = empty.before.lost
	if empty_lost > empty_before_lost:
		print("[CD001 %s] RED CASE: the empty rack still loses %d stored round(s) to the strike (before=%d after=%d)" % [id,empty_lost-empty_before_lost,empty_before_lost,empty_lost])
	else:
		print("[CD001 %s] empty rack takes no further ammunition loss from the strike (lost stays %d) - no red case to fix here" % [id,empty_lost])
	# Report the first divergence point between the three rows rather than asserting a new expectation.
	for key in ["chamber","in_transfer","available","lost"]:
		var values := [full.after[key],half.after[key],empty.after[key]]
		print("[CD001 %s] first divergence probe %s: %s" % [id,key,JSON.stringify(values)])

func cd001_case(id: String) -> void:
	var packet := _read(PACKAGES+id+".json")
	packet.id = FIXTURE_PREFIX+id
	for source in packet.sources.values(): source.applies_to_identity_ids=[packet.id]
	var sources := fixture_asset(packet,1.0)
	var defs := VehicleDefs.new()
	var registered := VehicleCatalog.new(sources).register(packet,defs)
	check(registered.ok,"CD001 fixture package registers with isolated TEST ONLY art ("+id+")")
	if not registered.ok: print(registered.errors); return
	var world := Node3D.new(); root.add_child(world)
	var manager := ProjectileManager.new(); manager.presentation_enabled=false; world.add_child(manager); manager.set_physics_process(false)
	var rows := await three_state_case(id,packet,defs,world,manager)
	_compare(rows,id)
	world.queue_free(); await _frames(3)

func _run() -> void:
	owned_directory="res://assets/vehicles/test_cd001_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	check(DirAccess.make_dir_recursive_absolute(owned_directory)==OK,"CD001 creates its own TEST ONLY model directory")
	var ignore := FileAccess.open(owned_directory.path_join(".gdignore"),FileAccess.WRITE); ignore.close()
	print("[CD001] source=02_FIRST_DELIVERY.md first action ; branch=" + str(ProjectSettings.get_setting("application/config/name","")))
	for id in MODERN: await cd001_case(id)
	for path in artifact_paths: DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(owned_directory.path_join(".gdignore")); DirAccess.remove_absolute(owned_directory)
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD001_THREE_STATE_PROBE_PASS" if failures==0 else "CD001_THREE_STATE_PROBE_FAIL")
	quit(0 if failures==0 else 1)
