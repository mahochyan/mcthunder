extends SceneTree
class LongRange extends BallisticsRange:
	func _build_world() -> void:
		TerrainFixtures.box(self,Vector3(0,-0.5,-1200),Vector3(100,1,2800))
var count := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	count+=1
	if not ok: failed+=1
	print(("[PASS] " if ok else "[FAIL] ")+label)
func frames(n: int = 3) -> void:
	for i in n: await physics_frame
	await process_frame
func set_sight(camera: CameraRig, point: Vector3) -> void:
	var direction := (point-camera.turret.barrel_pivot.global_position).normalized()
	camera.set_aim(atan2(-direction.x,-direction.z),asin(direction.y))
	camera.sight=true; camera.set_sight_requested(true); camera.clear_intent_cache()
func run() -> void:
	var scene := LongRange.new(); scene.selected_vehicle_id="us_m4a3_75w_vvss_1944"
	root.add_child(scene); current_scene=scene
	var shooter := scene.actor; shooter.set_controller(null)
	var target := VehicleActor.new(); scene.add_child(target)
	var setup := target.setup(scene.defs,scene.selected_vehicle_id,"B",2,Transform3D(Basis.IDENTITY,Vector3(0,0.03,-500)),4,null)
	check(setup.ok,"long range uses admitted historical vehicle and unchanged weapon definition")
	target.set_physics_process(false)
	var camera := shooter.cam_rig; camera.set_process(false)
	await frames(20)
	for distance in [500.0,1500.0,2400.0]:
		target.tank.global_position=Vector3(0,0.03,-distance)
		await frames(2)
		var point := target.tank.global_position+Vector3.UP*1.2
		camera.sight=false; camera.set_sight_requested(false); camera.clear_intent_cache()
		camera.cam.global_position=Vector3(0,1.5,6.5); camera.cam.look_at(point)
		check(camera.get_aim_point().distance_to(point)<6,"third-person world/vehicle ray reaches %.0fm target"%distance)
		set_sight(camera,point)
		check(camera.intent_point().distance_to(point)<6,"scope world/vehicle ray reaches %.0fm target"%distance)
		camera.refresh_intent(false)
		check(camera.intent_contact.get("entity_id","")=="B" and camera.intent_point().distance_to(point)<6,"precise armor aim reaches %.0fm target"%distance)
	check(camera.cam.far>=shooter.weapon.gun_range+GameConfig.AIM_CAMERA_MARGIN_M,"render far plane covers weapon budget and camera offset")
	camera.set_aim(0,deg_to_rad(10)); camera.sight=true; camera.set_sight_requested(true); camera.clear_intent_cache()
	var pivot := shooter.turret.barrel_pivot.global_position
	var horizon := GameConfig.aim_query_distance(shooter.weapon.gun_range)
	check(absf(camera.intent_point().distance_to(pivot)-horizon)<0.01,"empty scope ray converges at shared horizon instead of artificial 60m")
	camera.refresh_intent(false)
	check(camera.intent_contact.is_empty() and absf(camera.intent_point().distance_to(pivot)-horizon)<0.01,"precise empty-sky fallback uses the same horizon")
	target.tank.global_position=Vector3(0,0.03,-1500); await frames(2)
	var wall := TerrainFixtures.box(scene,Vector3(0,3,-800),Vector3(20,6,1))
	await frames(2); set_sight(camera,target.tank.global_position+Vector3.UP*1.2); camera.refresh_intent(false)
	check(camera.intent_contact.get("entity_id","")!="B" and camera.intent_point().z>-801 and camera.intent_point().z < -798,"distant world cover still occludes precise target geometry")
	wall.free(); await frames(2)
	# Actual long flight: normal gun, shell, solver, command mailbox and projectile query.
	target.tank.global_position=Vector3(0,0.03,-1000); await frames(2)
	var cmd := VehicleCommand.new(); cmd.has_aim_point=true
	cmd.aim_world_point=AimSolver.solve(shooter.turret.muzzle.global_position,{"aim_point":target.tank.global_position+Vector3.UP*1.2,"velocity":Vector3.ZERO},shooter.gunner.shell,Vector3.ZERO,Vector2.ZERO)
	shooter.submit_command(cmd); await frames(180)
	var hits: Array=[]
	scene.projectiles.projectile_contact.connect(func(event: Dictionary) -> void:
		if event.get("entity_id","")=="B": hits.append(event.duplicate(true)))
	cmd.fire_requested=true; shooter.submit_command(cmd)
	await frames(220)
	check(shooter.gunner.shots_fired==1 and not hits.is_empty(),"real historical shell reaches actual vehicle armor at 1000m")
	print("[long flight] contacts=",hits.size()," muzzle_velocity=",shooter.gunner.shell.muzzle_velocity_mps," query_horizon=",horizon," camera_far=",camera.cam.far)
	scene.free(); await process_frame
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("ENGAGEMENT_DISTANCE_CHECKS_PASS" if failed==0 else "ENGAGEMENT_DISTANCE_CHECKS_FAIL")
	quit(0 if failed==0 else 1)
