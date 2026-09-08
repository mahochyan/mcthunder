extends "res://tests/run_industrial_checks.gd"
## Physical wreck fixture separated from ordinary battle and normal player evidence.
func _run() -> void:
	root.size = Vector2i(1280,720)
	defs.load_defaults(); check(VehicleCatalog.new().load_all(defs).ok,"historical content admitted for wreck-route fixtures")
	var map := IndustrialDefinition.create()
	world = Node3D.new(); root.add_child(world); current_scene = world
	IndustrialWorld.build(world,map)
	await frames()
	for team in [1,2]:
		var sign := 1 if team==1 else -1
		var wreck := VehicleActor.new(); world.add_child(wreck)
		wreck.setup(defs,VehicleCatalog.IDS[2],"wreck_fixture",team,Transform3D(Basis.IDENTITY,Vector3(-78,0.03,sign*65)),4,null)
		wreck.state.destroy_once("explicit_wreck_fixture",{})
		wreck.set_physics_process(false); wreck.gunner.aim_preview_enabled=false
		await frames()
		var nav := DriveNavigator.new(); nav.configure(map.graph)
		for id in [VehicleCatalog.IDS[1],VehicleCatalog.IDS[2]]:
			var result := await drive(map,nav,id,team,0,TeamArena.goal(team,0))
			print("[actual wreck route] team=",team," type=",id," ",result)
			check(result.phase=="arrived" and result.bounded and result.recovery_attempts>0,"T023-H01 actual "+id+" recovers and routes around a physical M26 wreck for team "+str(team))
		wreck.free(); await frames()
	world.free()
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("INDUSTRIAL_OBSTRUCTION_CHECKS_PASS" if failed == 0 else "INDUSTRIAL_OBSTRUCTION_CHECKS_FAIL")
	quit(0 if failed == 0 else 1)
