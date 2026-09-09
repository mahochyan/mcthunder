extends SceneTree
## Initial positions and same-tick shell launches are explicit fixtures.
## Normal-shot cases use real historical VehicleActor/Gunner/ProjectileManager and commands.
var count := 0
var failed := 0
var defs := VehicleDefs.new()
var world: Node3D
var shooter: VehicleActor
var target: VehicleActor
var manager: ProjectileManager
var records: Array[Dictionary] = []

func _initialize() -> void: call_deferred("_run")
func check(value: bool, label: String) -> void:
	count += 1
	if not value: failed += 1
	print(("[PASS] " if value else "[FAIL] ")+label)
func frames(n: int = 2) -> void:
	for i in n: await physics_frame
	await process_frame
func snapshots() -> Array:
	var out: Array = []
	for actor in [shooter,target]:
		if is_instance_valid(actor): out.append(QuerySnapshotBuilder.build_from_vehicle(actor.tank,actor.damage_layout_override))
	return out
func damage(event: Dictionary, budget: float) -> Dictionary:
	if is_instance_valid(target) and event.get("entity_id","")==target.entity_id: return target.apply_projectile_damage(event,budget)
	return {"ok":false,"reason":"no_target"}
func _run() -> void:
	root.size = Vector2i(1280,720)
	defs.load_defaults(); check(VehicleCatalog.new().load_all(defs).ok,"four historical vehicles admitted")
	for style in ["brick","wood"]: await ordinary_shots(style)
	await same_tick()
	await maps()
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	if failed==0: print("STRUCTURE_CHECKS_PASS")
	quit(0 if failed==0 else 1)
func fixture(style: String) -> DestructibleSection:
	world = Node3D.new(); root.add_child(world); current_scene = world
	TerrainFixtures.box(world,Vector3(0,-0.5,0),Vector3(100,1,100))
	var section := DestructibleSection.new(); world.add_child(section); section.position.z = -15
	section.setup("fixture_"+style,"center",style,Vector3(8,3.8,6) if style=="wood" else Vector3(5.2,2.8,0.7))
	shooter = VehicleActor.new(); world.add_child(shooter)
	check(shooter.setup(defs,VehicleCatalog.IDS[0],"A",1,Transform3D(Basis.IDENTITY,Vector3(0,0.03,0)),2,null).ok,style+": real M4 shooter initialized")
	target = VehicleActor.new(); world.add_child(target)
	check(target.setup(defs,VehicleCatalog.IDS[0],"B",2,Transform3D(Basis(Vector3.UP,PI/2),Vector3(0,0.03,-26)),4,null).ok,style+": historical target behind cover")
	manager = ProjectileManager.new(); world.add_child(manager); manager.snapshot_provider = snapshots; manager.damage_handler = damage
	manager.projectile_finished.connect(func(record: Dictionary) -> void: records.append(record.duplicate(true)))
	shooter.gunner.projectile_manager = manager; shooter.gunner.snapshot_provider = snapshots
	shooter.gunner.round_provider = func() -> int: return 25
	records.clear()
	return section
func fire() -> Dictionary:
	var before := shooter.gunner.shots_fired
	var record_count := records.size()
	for tick in 900:
		var cmd := VehicleCommand.new(); cmd.has_aim_point=true; cmd.aim_world_point=Vector3(0,1.5,-26)
		cmd.fire_requested = tick>=180 and shooter.gunner.shots_fired==before
		shooter.submit_command(cmd); await frames(1)
		if records.size()>record_count: break
	check(shooter.gunner.shots_fired==before+1 and records.size()==record_count+1,"one normal command shot consumes one round and produces one real terminal record")
	return records.back() if records.size()>record_count else {}
func ordinary_shots(style: String) -> void:
	var section := fixture(style); await frames(5)
	var health := target.state.damage_snapshot()
	var space := world.get_world_3d().direct_space_state
	var line := WorldQueryAdapter.query_world_stop(space,Vector3(0,1.5,0),Vector3.FORWARD,25)
	check(line.hit and line.contact.collider==section,style+": intact section really blocks shell/LOS")
	var pose := shooter.tank.global_transform; pose.origin = Vector3(0,0.03,-8)
	check(shooter.tank.test_move(pose,Vector3(0,0,-16)),style+": real vehicle collision cannot cross intact section")
	check(section.apply_shell_impact({}).is_empty() and section.hits==0,"preview/empty hit is not building damage")
	var first := await fire()
	check(section.hits==1 and first.get("world_damage",{}).get("after",0)==1,style+": actual nearest-world shot records damaged state")
	check(target.state.damage_snapshot()==health and first.get("contacts",[]).is_empty(),style+": first shell does not damage vehicle behind intact cover")
	var second := await fire()
	check(section.hits==2 and second.get("world_damage",{}).get("collapsed",false),style+": second normal shot collapses section")
	check(target.state.damage_snapshot()==health and second.get("contacts",[]).is_empty(),style+": shell that breaks cover still terminates on it")
	check(manager.shot_records.count()==2 and manager.shot_records.get_record(0).terminal.has("world_damage"),"immutable shot replay retains actual structural transition")
	await frames(2)
	line = WorldQueryAdapter.query_world_stop(space,Vector3(0,1.5,0),Vector3.FORWARD,25)
	check(not line.hit,style+": actual shell and LOS ray passes through new visible opening")
	check(not shooter.tank.test_move(pose,Vector3(0,0,-12)),style+": opening removes the full vehicle blocker")
	var edge := section.global_position+Vector3(section.dimensions.x/2-0.15,0.18,5)
	line = WorldQueryAdapter.query_world_stop(space,edge,Vector3.FORWARD,10)
	check(line.hit and line.contact.collider==section,style+": visible side rubble still has matching collision")
	var third := await fire()
	check(not third.get("contacts",[]).is_empty() and third.get("world_damage",{}).is_empty(),style+": following real shell reaches target through opening")
	target.free(); await frames()
	for tick in 300:
		var cmd := VehicleCommand.new(); cmd.throttle=1.0; shooter.submit_command(cmd); await frames(1)
		if shooter.tank.global_position.z < -20: break
	check(shooter.tank.global_position.z < -20,style+": actual tank drives through destroyed section")
	check(section._seen.size()==2,"structural event history stays bounded by terminal state")
	await frames(100)
	check(section.find_children("*","StructureDust",true,false).is_empty(),"bounded impact dust retires after its lifetime")
	check(section.find_children("*","StructureCollapse",true,false).is_empty(),"bounded collapse pieces retire after their lifetime")
	world.free(); await frames()
func same_tick() -> void:
	var section := fixture("brick"); await frames(3)
	manager.set_physics_process(false)
	var spec := {"round_id":25,"shooter_id":"timing_fixture","shooter_life_id":1,"shot_id":1,"shell_id":"fixture",
		"armor_policy":"resolve","penetration_curve":PackedVector2Array([Vector2(0,100)]),
		"position_world":Vector3(0,1.5,-10),"velocity_world":Vector3(0,0,-600),"gravity_world":Vector3.ZERO,"max_age_s":1.0,"max_distance_m":100.0}
	var states: Array[ProjectileState] = []
	for i in 3:
		spec.shot_id=i+1
		var accepted := manager.try_spawn(spec); states.append(manager.get_projectile_state(accepted.projectile_id))
	for state in states: manager.advance_projectile(state,0.04,snapshots(),world.get_world_3d().direct_space_state)
	check(section.hits==2 and records.size()==3,"three same-tick projectile advances cannot over-damage a section")
	check(records[0].has("world_damage") and records[1].has("world_damage") and not records[2].get("contacts",[]).is_empty(),"same-tick later shot queries the committed opening")
	var hits := section.hits
	manager.finish_once(states[0].projectile_id,"impact_world",{})
	check(records.size()==3 and section.hits==hits,"duplicate terminal cannot repeat destruction")
	world.free(); await frames()
func maps() -> void:
	for map in [VillageDefinition.create(),IndustrialDefinition.create()]:
		world=Node3D.new(); root.add_child(world)
		SpecialStructures.build(world,map); await frames()
		var sections := world.find_children("*","DestructibleSection",true,false)
		check(sections.size()==8,map.id+": four optional structures have eight bounded sections")
		var fresh := true; var off_roads := true
		var nav := DriveNavigator.new(); nav.configure(map.graph)
		for section: DestructibleSection in sections:
			fresh = fresh and section.hits==0 and section._seen.is_empty() and not section._shape.disabled
			for edge in map.graph.edges:
				var a: Vector3=nav.nodes[edge.a]; var b: Vector3=nav.nodes[edge.b]
				var p := Geometry2D.get_closest_point_to_segment(Vector2(section.global_position.x,section.global_position.z),Vector2(a.x,a.z),Vector2(b.x,b.z))
				var half_diagonal := Vector2(section.dimensions.x,section.dimensions.z).length()/2
				if p.distance_to(Vector2(section.global_position.x,section.global_position.z)) < half_diagonal+float(edge.width)/2+map.max_vehicle_size.x/2: off_roads=false
		check(fresh,map.id+": fresh world restores every structural collision/state")
		check(off_roads,map.id+": optional structures leave all authored driving corridors clear")
		world.free(); await frames()
