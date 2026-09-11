extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func run() -> void:
	var definition := VehicleDefinition.new()
	var drive := DrivePowertrain.new()
	var low := drive.step(0,1,0,true,1.0/60,definition)
	drive.gear=4
	var high := drive.step(7,1,0,true,1.0/60,definition)-7
	check(low>high*1.3,"available acceleration falls with road speed")
	drive.reset(); drive.gear=1
	drive.step(2.1,1,0,true,1.0/60,definition)
	check(drive.gear==2 and drive.shift_left>0 and drive.traction_acceleration<1,"upshift interrupts traction")
	for i in 30: drive.step(1.8,1,0,true,1.0/60,definition)
	check(drive.gear==2,"downshift hysteresis prevents gear hunting near threshold")
	drive.step(1.0,1,0,true,1.0/60,definition)
	check(drive.gear==1,"lower road speed permits a downshift")
	drive.reset()
	var stopped := drive.step(0.01,-1,0,true,1.0/60,definition)
	check(stopped==0 and drive.braking,"opposite input brakes to zero without instant powered reversal")
	var reverse := drive.step(stopped,-1,0,true,1.0/60,definition)
	check(reverse<0 and absf(reverse)<=definition.reverse_accel/60.0+0.0001,"next step uses reverse engine acceleration, not brake strength")
	drive.reset(); var flat := drive.step(1,1,0,true,0.1,definition)
	drive.reset(); var uphill := drive.step(1,1,sin(deg_to_rad(20)),true,0.1,definition)
	drive.reset(); var downhill := drive.step(1,1,-sin(deg_to_rad(20)),true,0.1,definition)
	check(uphill<flat and flat<downhill,"continuous signed grade affects drive before the impassable-slope cutoff")
	var speed := 0.0
	for i in 900: speed=drive.step(speed,-1,-0.3,true,1.0/60,definition)
	check(speed>=-definition.reverse_max_speed,"downhill/reverse engine remains within speed governor")
	check(drive.step(0,0,-0.3,true,1.0/60,definition)==0,"released controls hold a stopped vehicle on a slope")
	var invalid := DriveProfile.new(); invalid.power_falloff=NAN
	check(not invalid.validate().is_empty(),"invalid design curves rejected")
	var world := NetworkBattleWorld.new(); root.add_child(world)
	check(world.ready_ok,"two real historical actors load design profiles")
	for i in 5: await physics_frame
	var starts: Array[Vector3]=[]
	for actor in world.actors: starts.append(actor.tank.global_position)
	for tick in 240:
		for actor in world.actors:
			var command := VehicleCommand.new(); command.throttle=1; actor.submit_command(command)
		await physics_frame
	var a: TankVehicle=world.actors[0].tank; var b: TankVehicle=world.actors[1].tank
	var da := a.global_position.distance_to(starts[0]); var db := b.global_position.distance_to(starts[1])
	print("[MEASURE] 4s M4A3 distance=%.3f speed=%.3f gear=%d; M24 distance=%.3f speed=%.3f gear=%d"%[da,a.forward_speed,a.powertrain.gear,db,b.forward_speed,b.powertrain.gear])
	check(da>5 and db>da+1,"same actor commands produce distinguishable actual four-second acceleration distances")
	check(a.powertrain.gear>=2 and b.powertrain.gear>=2,"real vehicle drive updates powertrain bands")
	world.actors[0].reset_vehicle()
	check(a.powertrain.gear==0 and a.powertrain.shift_left==0 and a.forward_speed==0,"actor reset clears powertrain and motion together")
	var ramp := StaticBody3D.new(); ramp.position=Vector3(1000,0,0); ramp.rotation.x=deg_to_rad(20)
	var collision := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size=Vector3(20,1,200)
	collision.shape=box; collision.position.y=-0.5; ramp.add_child(collision); world.add_child(ramp)
	a.global_transform=Transform3D(Basis.IDENTITY,Vector3(1000,tan(deg_to_rad(20))*10+0.02,-10))
	for i in 30: await physics_frame
	var ramp_start := a.global_position
	for i in 120:
		var command := VehicleCommand.new(); command.throttle=1; world.actors[0].submit_command(command)
		await physics_frame
	print("[MEASURE] M4A3 20deg actual ramp travel=%.3f speed=%.3f sampled_slope=%.3f"%[a.global_position.distance_to(ramp_start),a.forward_speed,a.ground_state.slope_deg])
	check(a.ground_state.slope_deg>18 and a.global_position.z<ramp_start.z-0.5 and a.forward_speed>0.3,"historical M4A3 can start uphill on real 20-degree geometry with continuous load")
	world.free()
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("POWERTRAIN_CHECKS_PASS" if failures==0 else "POWERTRAIN_CHECKS_FAIL")
	quit(0 if failures==0 else 1)
