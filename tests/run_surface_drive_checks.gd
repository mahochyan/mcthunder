extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(("[PASS] " if ok else "[FAIL] ")+label)
func run() -> void:
	var p := DrivePowertrain.new(); var def := VehicleDefinition.new()
	var road := p.step(2,1,0,true,0.1,def,0.12)
	p.reset(); var soil := p.step(2,1,0,true,0.1,def,1)
	check(soil<road,"surface resistance reduces powered acceleration")
	p.reset(); var air := p.step(2,1,0,false,0.1,def,1)
	p.reset(); check(air==p.step(2,1,0,false,0.1,def,0),"airborne vehicle receives no surface resistance")
	p.reset(); road=p.step(-2,0,0,true,0.1,def,0.12)
	p.reset(); soil=p.step(-2,0,0,true,0.1,def,1)
	check(soil>road and soil<0,"reverse coasting loses speed without changing direction")
	check(p.step(0,0,0,true,1,def,1)==0,"resistance does not push stationary vehicle backwards")
	var world := NetworkBattleWorld.new(); root.add_child(world)
	check(world.ready_ok,"actual two historical actors load")
	var ground := world.get_child(0) as StaticBody3D
	var results: Array=[]
	for kind in ["road","soft_soil"]:
		DriveSurface.configure(ground,kind)
		for actor in world.actors: actor.reset_vehicle()
		for i in 5: await physics_frame
		var starts: Array[Vector3]=[]
		for actor in world.actors: starts.append(actor.tank.global_position)
		for tick in 240:
			for actor in world.actors:
				var cmd := VehicleCommand.new(); cmd.throttle=1; actor.submit_command(cmd)
			await physics_frame
		var distances: Array=[]
		for index in 2:
			var tank: TankVehicle=world.actors[index].tank
			distances.append(tank.global_position.distance_to(starts[index]))
			check(is_equal_approx(tank.ground_state.surface_drag,GameConfig.DRIVE_SURFACE_DRAG[kind]),"actual ground probes read "+kind+" "+str(index))
		print("[MEASURE] ",kind," four_second_distances=",distances)
		results.append(distances)
	for index in 2: check(results[0][index]>results[1][index]+2,"same real commands travel further on road "+str(index))
	# Same painted road endpoints/widths used by production village builder.
	var map := VillageDefinition.create()
	DriveSurface.configure(ground,"grass",map,5.5)
	var strip: Array=ground.get_meta("drive_surface").strips[0]
	var midpoint: Vector2=(strip[0]+strip[1])*0.5
	check(DriveSurface.kind_at(ground,ground.to_global(Vector3(midpoint.x,0,midpoint.y)))=="road","painted village road center maps to road resistance")
	check(DriveSurface.kind_at(ground,Vector3(150,0,150))=="grass","village off-road ground retains grass identity")
	ground.set_meta("drive_surface",{"kind":"grass","strips":[[Vector2(-20,0),Vector2(20,0),2.0]]})
	var actor := world.actors[0]; actor.reset_vehicle()
	actor.tank.global_position=Vector3(0,0,2)
	for i in 5: await physics_frame
	check(actor.tank.ground_state.surface_drag>0.12 and actor.tank.ground_state.surface_drag<0.55,"road boundary combines real support samples")
	actor.tank.global_position.y=20
	var sample := GroundProbe.sample(actor.tank,Vector3.FORWARD,Vector2(1,2))
	check(not sample.grounded and sample.surface_drag==0,"missing ground contact contributes no drag")
	world.free(); await process_frame
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("SURFACE_DRIVE_CHECKS_PASS" if failures==0 else "SURFACE_DRIVE_CHECKS_FAIL")
	quit(0 if failures==0 else 1)
