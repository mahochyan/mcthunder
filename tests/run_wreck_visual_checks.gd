extends SceneTree
## Explicit starting-pose fixtures. Ammunition deaths and fire use actual historical
## shots; the isolated crew-out presentation case is named as a cause fixture.
var count:=0
var failed:=0
var defs:=VehicleDefs.new()
var world: Node3D
var shooter: VehicleActor
var target: VehicleActor
var manager: ProjectileManager
var visuals: RecoveryVisuals
var death_events:=0
var capture:=false
var folder:="res://docs/evidence/025/wip-wreck"
func _initialize() -> void: call_deferred("_run")
func check(value: bool, text: String) -> void:
	count+=1
	if not value: failed+=1
	print(("[PASS] " if value else "[FAIL] ")+text)
func frames(n: int=2) -> void:
	for i in n: await physics_frame
	await process_frame
func snapshots() -> Array:
	return [QuerySnapshotBuilder.build_from_vehicle(shooter.tank,shooter.damage_layout_override),QuerySnapshotBuilder.build_from_vehicle(target.tank,target.damage_layout_override)]
func damage(event: Dictionary, budget: float) -> Dictionary: return target.apply_projectile_damage(event,budget)
func _run() -> void:
	root.size=Vector2i(1280,720)
	var args:=OS.get_cmdline_user_args(); capture=args.has("--capture")
	for i in args.size():
		if args[i]=="--shot-dir" and i+1<args.size(): folder=args[i+1]
	defs.load_defaults(); check(VehicleCatalog.new().load_all(defs).ok,"historical content admitted for real wreck fixtures")
	for id in VehicleCatalog.IDS: await ammo_case(id)
	await fire_case()
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	if failed==0: print("WRECK_VISUAL_CHECKS_PASS")
	quit(0 if failed==0 else 1)
func setup(id: String) -> void:
	world=Node3D.new(); root.add_child(world); current_scene=world
	WorldArtKit.box(world,Vector3(0,-0.5,0),Vector3(100,1,100),"earth"); WorldLighting.build(world)
	shooter=VehicleActor.new(); world.add_child(shooter)
	shooter.setup(defs,VehicleCatalog.IDS[2],"A",1,Transform3D(Basis.IDENTITY,Vector3(0,0.03,0)),2,null)
	target=VehicleActor.new(); world.add_child(target)
	target.setup(defs,id,"B",2,Transform3D(Basis(Vector3.UP,PI/2),Vector3(0,0.03,-20)),4,null)
	shooter.label3d.visible=false; target.label3d.visible=false
	manager=ProjectileManager.new(); world.add_child(manager); manager.snapshot_provider=snapshots; manager.damage_handler=damage
	manager.projectile_damage.connect(target.present_damage_record)
	shooter.gunner.projectile_manager=manager; shooter.gunner.snapshot_provider=snapshots; shooter.gunner.round_provider=func() -> int: return 25
	visuals=RecoveryVisuals.new(); target.add_child(visuals); visuals.setup(target)
	death_events=0; target.vehicle_destroyed.connect(func(_record: Dictionary) -> void: death_events+=1)
	if capture:
		var camera:=Camera3D.new(); world.add_child(camera); camera.position=Vector3(9,5,-11); camera.look_at(Vector3(0,2.4,-20)); camera.fov=62; camera.current=true
		var canvas:=CanvasLayer.new(); world.add_child(canvas)
		var label:=Label.new(); label.add_theme_font_override("font",CoreUI.FONT); label.add_theme_font_size_override("font_size",22); label.position=Vector2(22,18)
		label.text="025 毁伤观察夹具 · "+str(defs.content_packets[id].display_name)+"\n真实历史炮弹 · 预设起始位置 · 非玩家视角"; canvas.add_child(label)
func shoot_module(id: String) -> void:
	var module: ModuleVolumeDefinition
	for item in target.damage_layout_override.modules:
		if item.id==id: module=item
	if module==null: check(false,"requested real module exists: "+id); return
	var aim: Vector3=DamageTrainingLayout.part_node(target,module.part_id).to_global(module.local_box_transform.origin)
	var before:=shooter.gunner.shots_fired
	for tick in 1500:
		var command:=VehicleCommand.new(); command.has_aim_point=true; command.aim_world_point=aim
		command.fire_requested=tick>=180 and shooter.gunner.shots_fired==before
		shooter.submit_command(command); await frames(1)
		if shooter.gunner.shots_fired>before and manager.active_count()==0: break
	check(shooter.gunner.shots_fired==before+1,"actual M26 shot consumes one loaded round after natural aim/reload")
func shot(name: String) -> void:
	if not capture: return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder+"/"+name+".png")==OK,"actual window capture "+name)
func ammo_case(id: String) -> void:
	setup(id); await frames(5)
	var bind:=target.turret.transform
	var original_pose:=target.turret.global_transform
	await shoot_module("ammo_floor_left")
	await frames(2) # The read-only presentation observes the committed death on its next render update.
	print("[real ammo impact] ",id," death=",target.state.death_record," shots=",shooter.gunner.shots_fired)
	check(target.state.destroyed and target.state.death_record.get("cause","")=="ammo_detonation",id+": actual loaded-rack shot commits ammunition death")
	if not is_instance_valid(target.wreck_turret): world.free(); await frames(); return
	check(death_events==1 and visuals.blast_count==1,id+": one committed death produces one blast")
	var skin:=target.tank.find_children("Skin_*","MeshInstance3D",true,false)
	skin.append_array(target.turret.find_children("Skin_*","MeshInstance3D",true,false))
	check(not skin.is_empty() and skin.all(func(mesh: MeshInstance3D) -> bool: return mesh.material_override is StandardMaterial3D and mesh.material_override.cull_mode==BaseMaterial3D.CULL_DISABLED),id+": actual wreck armor remains visible on both sides after death material replacement")
	check(target.turret.get_parent()==target.wreck_turret and target.state.death_record.get("turret_detached",false),id+": the actual turret is detached exactly once")
	await frames(10)
	if id==VehicleCatalog.IDS[0]: await shot("01_ammo_blast")
	await frames(32)
	var pose:=target.turret.global_transform
	check(pose.origin.y>original_pose.origin.y+1.0,id+": actual detached turret rises under bounded impulse")
	var snapshot:=QuerySnapshotBuilder.build_from_vehicle(target.tank,target.damage_layout_override)
	check(snapshot.part_world_transforms.turret.is_equal_approx(pose) and snapshot.part_world_transforms.barrel.is_equal_approx(target.turret.barrel_pivot.global_transform),id+": query turret and cannon follow airborne render parts")
	check(not snapshot.part_world_transforms.turret.is_equal_approx(original_pose),id+": no stationary invisible turret remains in query pose")
	var old_center:=original_pose.origin+Vector3.UP*0.3
	var old_ray:=ShotQueryService.query({"query_id":"old_turret_position","from_world":old_center-Vector3.RIGHT*4,"to_world":old_center+Vector3.RIGHT*4},[snapshot])
	var new_center:=pose*Vector3(0,0.3,0)
	var new_ray:=ShotQueryService.query({"query_id":"airborne_turret_position","from_world":new_center-pose.basis.x*4,"to_world":new_center+pose.basis.x*4},[snapshot])
	if not old_ray.events.is_empty() or new_ray.events.is_empty(): print("[wreck query diagnostic] ",id," old=",old_ray.events," new=",new_ray.events)
	check(old_ray.ok and old_ray.events.is_empty() and new_ray.ok and not new_ray.events.is_empty(),id+": real query misses old turret space and hits its airborne position")
	await shot("flying_"+id)
	var age:=visuals.death_age; var motion_time:=target.wreck_turret.elapsed
	paused=true; await frames(20)
	check(target.turret.global_transform==pose and visuals.death_age==age and target.wreck_turret.elapsed==motion_time,"pause freezes wreck physics, smoke and blast clocks")
	paused=false; await frames(300)
	check(target.wreck_turret.settled and target.wreck_turret.velocity==Vector3.ZERO and target.turret.global_position.y>=-0.5,id+": finite physical turret settles above terrain")
	check(visuals._smoke.visible and visuals._flames[0].visible and not visuals._blast.visible,id+": blast retires while bounded smoke and wreck fire remain")
	if id==VehicleCatalog.IDS[0]: await shot("06_settled_wreck")
	if id==VehicleCatalog.IDS[0]:
		var state_before:=target.state.damage_snapshot()
		visuals._process(61.0) # Explicit visual-clock boundary fixture only.
		check(not visuals._smoke.visible and not visuals._flames[0].visible and target.state.damage_snapshot()==state_before,"visual-only lifetime fixture retires smoke/fire without changing wreck damage")
	var records:=manager.shot_records.count(); target._publish_death()
	check(death_events==1 and visuals.blast_count==1 and manager.shot_records.count()==records,"repeated death publication creates neither a blast nor a score event")
	target.freeze_wreck(); pose=target.turret.global_transform; await frames(5)
	check(target.turret.global_transform==pose,"finished battle can freeze physical detached wreck")
	target.reset_vehicle(); await frames(2)
	check(target.turret.get_parent()==target.tank and target.turret.position.is_equal_approx(bind.origin) and not is_instance_valid(target.wreck_turret),id+": normal reset restores turret parent/bind position and removes extra collision")
	check(not target.state.destroyed and visuals.blast_count==0 and not visuals._smoke.visible and not visuals._flames[0].visible,"new life clears char, blast and fire without persistent old effects")
	world.free(); await frames()
func fire_case() -> void:
	setup(VehicleCatalog.IDS[0]); await frames(5)
	await shoot_module("engine")
	check(not target.state.destroyed and target.state.fires.has("engine"),"actual engine hit starts repairable fire without inventing ammunition death")
	check(visuals._flames[0].visible and visuals._smoke.visible and visuals.blast_count==0 and not is_instance_valid(target.wreck_turret),"engine fire emits flame/smoke but no blast or turret launch")
	await shot("07_engine_fire")
	var command:=VehicleCommand.new(); command.extinguish_requested=true; target.submit_command(command); await frames(250)
	check(target.state.fires.is_empty() and not target.state.destroyed and not visuals._flames[0].visible and not visuals._smoke.visible,"actual timed extinguisher clears live-fire visuals")
	# Explicit presentation fixture. Actual crew injury/death rules remain covered by damage/recovery suites.
	target.state.destroy_once("crew_out",{"fixture":"presentation_cause_only"}); target._commit_death(); target._publish_death(); await frames(3)
	check(target.state.destroyed and visuals.blast_count==0 and not visuals._burning_wreck and not is_instance_valid(target.wreck_turret),"crew-out cause fixture produces a quiet wreck without invented explosion")
	await shot("08_crew_out_wreck")
	world.free(); await frames()
