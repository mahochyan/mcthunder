extends SceneTree
var count:=0
var failed:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	count+=1
	if not ok: failed+=1
	print(("[PASS] " if ok else "[FAIL] ")+label)
func run() -> void:
	var world:=NetworkBattleWorld.new(); root.add_child(world)
	check(world.ready_ok,"actual historical vehicles ready")
	TerrainFixtures.box(world,Vector3(-2,0.5,0),Vector3(4,1,80))
	var actor:=world.actors[0]
	var speeds: Array[float]=[]
	for x in [-2.0,-0.2]:
		actor.reset_vehicle(); actor.tank.global_position=Vector3(x,1,0)
		for i in 5: await physics_frame
		var sample: Dictionary=actor.tank.ground_state
		print("[SUPPORT] x=",x," left=",sample.left_support," right=",sample.right_support," rays=",sample.support_count)
		if x==-2: check(sample.traction_support==1,"both tracks fully supported on platform")
		else: check(sample.left_support==1 and sample.right_support==0 and sample.support_count==5,"rays see lower ground but unsupported right track contributes no grip")
		for tick in 60:
			var cmd:=VehicleCommand.new(); cmd.throttle=1; actor.submit_command(cmd)
			await physics_frame
		speeds.append(actor.tank.forward_speed)
	print("[MEASURE] full/partial one_second_speed=",speeds)
	check(speeds[0]>speeds[1]*1.4 and speeds[1]>0.1,"real partial support reduces acceleration instead of keeping full traction")
	actor.reset_vehicle(); actor.tank.global_position=Vector3(-0.2,1,0)
	for i in 5: await physics_frame
	var yaw:=actor.tank.global_rotation.y
	for tick in 30:
		var cmd:=VehicleCommand.new(); cmd.steer=1; actor.submit_command(cmd)
		await physics_frame
	check(is_equal_approx(yaw,actor.tank.global_rotation.y),"normal two-track steering cannot use unsupported side")
	var power:=DrivePowertrain.new(); var def:=VehicleDefinition.new()
	var full:=power.step(3,-1,0,true,0.1,def,0,1)
	power.reset(); var partial:=power.step(3,-1,0,true,0.1,def,0,0.5)
	check(partial>full and partial<3,"partial contact reduces brake authority")
	check(power.step(3,0,0,true,0.1,def,0,0)==3,"belly-only support does not create track coast resistance")
	world.free(); await process_frame
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("PARTIAL_SUPPORT_CHECKS_PASS" if failed==0 else "PARTIAL_SUPPORT_CHECKS_FAIL")
	quit(0 if failed==0 else 1)
