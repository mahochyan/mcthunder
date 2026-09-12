extends "res://tests/run_reference_admission_checks.gd"
## Modern draft tuning is exercised on an explicitly labelled legacy test hull.
## This does not deliver either modern model or validate its combat geometry.
const DRAFTS := "res://authoring/reference_data/modern_equipment/"
const MODERN_IDS := ["ussr_t_80b","germ_leopard_2a4"]

class SightDriver extends Node:
	var cam_rig: CameraRig
	var gunner: Gunner
	var range_requested := false
	var apply_requested := false
	func poll() -> VehicleCommand:
		var command := VehicleCommand.new(); command.aim_intent.active=true; command.aim_intent.mode="sight"
		command.range_requested=range_requested; command.apply_range_requested=apply_requested
		range_requested=false; apply_requested=false
		return command
	func reset_pending() -> void:
		range_requested=false; apply_requested=false

func equipped(id: String) -> Dictionary:
	var packet := _fixture()
	var draft := _read(DRAFTS+id+".json")
	for kind in VehicleEquipmentProfiles.FIELDS:
		packet[kind+"_profile"]=draft[kind+"_profile"].duplicate(true)
		packet.facts[kind+".profile"]=_claim(packet[kind+"_profile"].duplicate(true),"structured")
	packet.modules.append({"id":"test_stabilizer","kind":"stabilizer","part":"hull","position":[0,0.8,0.3],"size":[0.15,0.15,0.15],"external":false})
	packet.facts["geometry.modules"]=_claim(packet.modules.duplicate(true),"structured")
	packet.facts["equipment.stabilizer"]=_claim(VehicleEquipmentProfiles.stabilizer_equipment(packet),"structured")
	return packet

func admission_cases() -> void:
	for id in MODERN_IDS:
		var draft := _read(DRAFTS+id+".json")
		check(draft.id==id and draft.admission_status=="candidate_only" and not draft.historical_verified,"draft "+id+" preserves candidate identity and no historical claim")
		check(FileAccess.get_sha256(draft.source_candidate.artifact)==draft.source_candidate.sha256,"draft "+id+" binds the actual unchanged reference candidate hash")
		check(not VehicleContentPipeline.validate_package(draft).ok,"equipment draft alone cannot be admitted as a combat vehicle")
		for kind in VehicleEquipmentProfiles.FIELDS:
			var profile := VehicleEquipmentProfiles.from_packet(kind,draft[kind+"_profile"])
			check(profile.ok,id+" fully authored "+kind+" profile parses from JSON")
		var packet := equipped(id)
		var result := VehicleContentPipeline.validate_package(packet)
		check(result.ok,"independent "+id+" tuning admits on explicitly TEST ONLY existing hull")
		if not result.ok: print("[DETAIL] ",result.errors)
		var changed := packet.duplicate(true)
		changed.optics_profile.values.measurement_time_s=4
		check(not VehicleContentPipeline.validate_package(changed).ok,"actual measurement timing cannot diverge from independent evidence")
		changed=packet.duplicate(true); changed.facts.erase("drive.profile")
		check(not VehicleContentPipeline.validate_package(changed).ok,"omitted independent drive evidence blocks package")
		changed=packet.duplicate(true); changed.modules.pop_back()
		changed.facts["geometry.modules"]=_claim(changed.modules.duplicate(true),"structured")
		changed.facts["equipment.stabilizer"]=_claim(VehicleEquipmentProfiles.stabilizer_equipment(changed),"structured")
		check(not VehicleContentPipeline.validate_package(changed).ok,"two-axis capability without damageable stabilizer geometry is rejected")
		changed=packet.duplicate(true); changed.facts["optics.profile"].unit="s"
		check(not VehicleContentPipeline.validate_package(changed).ok,"equipment claims require structured units")
		changed=packet.duplicate(true); changed.facts["fire_control.profile"].origin="warthunder_reference"
		check(not VehicleContentPipeline.validate_package(changed).ok,"independent game tuning cannot be relabelled as source reference equipment")
		var fresh := VehicleContentPipeline.validate_package(packet)
		if result.ok and fresh.ok:
			result.definitions.vehicle.optics_profile.sight_fovs[0]=40
			check(fresh.definitions.vehicle.optics_profile.sight_fovs[0]==draft.optics_profile.values.sight_fovs[0] and packet.optics_profile.values.sight_fovs[0]!=40,"decoded resources and JSON remain isolated between admissions")
	var draft := _read(DRAFTS+MODERN_IDS[0]+".json")
	for spec in [["drive","gear_count",2.5],["drive","gear_count",true],["drive","neutral_turn",1],["drive","power_falloff",NAN],["optics","sight_fovs",[8,20]],["optics","sight_offset",[0,0]],["optics","sight_offset",[0,INF,0]],["optics","sight_fovs",[true,8]],["fire_control","stabilizer_mode","thermal"],["fire_control","provenance","documented"]]:
		var bad: Dictionary=draft[spec[0]+"_profile"].duplicate(true)
		bad.values[spec[1]]=spec[2]
		check(not VehicleEquipmentProfiles.from_packet(spec[0],bad).ok,"profile rejects invalid "+spec[0]+"."+spec[1])
	for kind in VehicleEquipmentProfiles.FIELDS:
		var bad: Dictionary=draft[kind+"_profile"].duplicate(true)
		bad.values.erase(VehicleEquipmentProfiles.FIELDS[kind][0])
		check(not VehicleEquipmentProfiles.from_packet(kind,bad).ok,"missing "+kind+" value cannot silently fall back to Resource default")
		bad=draft[kind+"_profile"].duplicate(true); bad.values["resource_path"]="res://untrusted.tres"
		check(not VehicleEquipmentProfiles.from_packet(kind,bad).ok,"profile "+kind+" cannot assign arbitrary resource properties")
		bad=draft[kind+"_profile"].duplicate(true); bad.schema_version=true
		check(not VehicleEquipmentProfiles.from_packet(kind,bad).ok,"boolean schema rejected for "+kind)
	check(VehicleContentPipeline.validate_package(_read(HISTORICAL)).ok,"legacy M24 without profile envelopes retains admission")

func actor_case(id: String) -> void:
	var packet := equipped(id)
	var defs := VehicleDefs.new()
	var result := VehicleCatalog.new().register(packet,defs)
	check(result.ok,id+" tuning registers through actual content registry")
	if not result.ok: return
	var world := Node3D.new(); root.add_child(world)
	TerrainFixtures.box(world,Vector3(0,-0.5,0),Vector3(100,1,100))
	TerrainFixtures.box(world,Vector3(0,2,-300),Vector3(40,20,1))
	var light := DirectionalLight3D.new(); light.rotation_degrees=Vector3(-45,-20,0); world.add_child(light)
	var environment := WorldEnvironment.new(); environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR; environment.environment.background_color=Color("8197b0")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; environment.environment.ambient_light_color=Color.WHITE; environment.environment.ambient_light_energy=0.6
	world.add_child(environment)
	for x in [-15,-5,5,15]: CoreVehicleVisual.box(world,Vector3(x,2,-299.48),Vector3(2,20,0.02),Color("e1d7af"))
	var actor := VehicleActor.new(); world.add_child(actor)
	var setup := actor.setup(defs,packet.id,"equipment_test",1,Transform3D(Basis.IDENTITY,Vector3(0,0.1,0)),GameConfig.VIS_LAYER_VEHICLE,null)
	check(setup.ok,id+" profiles reach actual Actor.setup")
	if not setup.ok: world.queue_free(); await _frames(3); return
	var manager := ProjectileManager.new(); manager.presentation_enabled=false; world.add_child(manager)
	manager.exclude_provider=func(_entity: String, _life: int) -> Array[RID]: return [actor.tank.get_rid()]
	actor.gunner.projectile_manager=manager; actor.gunner.round_provider=func() -> int: return 3031
	actor.gunner.aim_preview_enabled=false
	await _frames(20)
	var camera := actor.cam_rig
	camera.set_sight_requested(true); camera._update_camera_pose()
	var optics: Dictionary=packet.optics_profile.values
	check(is_equal_approx(camera.cam.fov,optics.sight_fovs[0]) and camera.cam.global_position.is_equal_approx(actor.turret.barrel_pivot.to_global(Vector3(optics.sight_offset[0],optics.sight_offset[1],optics.sight_offset[2]))),id+" authored FOV and optical offset drive actual camera")
	await capture(actor,world,id,0)
	camera.set_sight_requested(true); camera.cycle_zoom(); camera._update_camera_pose()
	check(is_equal_approx(camera.cam.fov,optics.sight_fovs[1]),id+" actual camera consumes authored second zoom")
	await capture(actor,world,id,1)
	var start_yaw := actor.tank.rotation.y
	for i in 30:
		var command := VehicleCommand.new(); command.steer=1
		actor.submit_command(command); await physics_frame
	var turned := absf(actor.tank.rotation.y-start_yaw)
	check(turned>0.05 if packet.drive_profile.values.neutral_turn else turned<0.00001,id+" actual stationary steering follows authored neutral-turn capability")
	check(actor.turret.mechanism.stabilizer_active and actor.turret.mechanism.stabilized_axes==Vector2i.ONE,id+" actual mechanism enables authored two-axis capability")
	var command := VehicleCommand.new(); command.zeroing_steps=1
	actor.submit_command(command); await _frames(2)
	check(actor.fire_control.zeroing_m==50,id+" authority consumes authored 50m zeroing step")
	var sight_driver := SightDriver.new(); world.add_child(sight_driver); actor.set_controller(sight_driver)
	sight_driver.range_requested=true; await _frames(1)
	check(is_equal_approx(actor.fire_control.measurement_duration_s,optics.measurement_time_s),id+" authority starts measurement using authored duration")
	await _frames(ceili(optics.measurement_time_s*60)+4)
	check(actor.fire_control.status=="measured" and actor.fire_control.measured_range_m==300,id+" actual geometry completes and quantizes the configured range measurement")
	sight_driver.apply_requested=true; await _frames(2)
	check(actor.fire_control.zeroing_m==300,id+" apply-range command consumes measured authority value")
	actor.set_controller(null); sight_driver.queue_free()
	# Declared state injection isolates damage consumption; projectile damage has separate suites.
	actor.state.module_states["test_stabilizer"]["integrity"]=0.0
	await _frames(3)
	check(not actor.turret.mechanism.stabilizer_active,id+" installed stabilizer module failure disables actual mechanism assistance")
	actor.reset_vehicle(); await _frames(3)
	check(actor.turret.mechanism.stabilizer_active and actor.fire_control.zeroing_m==0,id+" reset restores capability while clearing measurement/zeroing")
	var start := actor.tank.global_position
	for i in 60:
		command=VehicleCommand.new(); command.throttle=1; actor.submit_command(command); await physics_frame
	check(actor.tank.global_position.distance_to(start)>0.3 and actor.tank.forward_speed>0.1,id+" installed drive profile advances actual vehicle on real ground")
	command=VehicleCommand.new(); command.fire_requested=true
	actor.submit_command(command); await _frames(2)
	check(actor.gunner.shots_fired==1 and actor.gunner.rounds_remaining==47,id+" configured Actor still fires through normal authority weapon phase")
	manager.cancel_all("cancelled_equipment_check")
	world.queue_free(); await _frames(3)

func capture(actor: VehicleActor, world: Node3D, id: String, zoom: int) -> void:
	var args := OS.get_cmdline_user_args(); var index := args.find("--shot-dir")
	if index<0 or index+1>=args.size(): return
	check(DisplayServer.get_name()!="headless","equipment capture requires window renderer")
	if DisplayServer.get_name()=="headless": return
	var driver := SightDriver.new(); world.add_child(driver); actor.set_controller(driver)
	actor.cam_rig.zoom_step=zoom
	await _frames(5)
	actor.cam_rig._update_camera_pose()
	check(actor.cam_rig.sight and is_equal_approx(actor.cam_rig.cam.fov,actor.definition.optics_profile.sight_fovs[zoom]),"capture retains authoritative sight input across every physics step")
	var canvas := CanvasLayer.new(); world.add_child(canvas)
	var label := Label.new(); label.position=Vector2(24,24); label.add_theme_font_size_override("font_size",22)
	label.text="TEST HULL / GAME TUNING ONLY\n%s | zoom %d | vertical FOV %.1f deg\n300 m striped target | modern model/geometry NOT ADMITTED"%[id,zoom+1,actor.cam_rig.cam.fov]
	canvas.add_child(label)
	actor.cam_rig.cam.current=true
	await _frames(5)
	await RenderingServer.frame_post_draw
	var directory: String=args[index+1]; DirAccess.make_dir_recursive_absolute(directory)
	var picture := root.get_texture().get_image()
	check(picture!=null and not picture.is_empty() and picture.save_png(directory.path_join(id+"_zoom_"+str(zoom)+".png"))==OK,"actual equipment scope image saved")
	canvas.queue_free(); actor.set_controller(null); driver.queue_free(); await process_frame

func _run() -> void:
	admission_cases()
	for id in MODERN_IDS: await actor_case(id)
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("EQUIPMENT_PACKAGE_CHECKS_PASS" if failures==0 else "EQUIPMENT_PACKAGE_CHECKS_FAIL")
	quit(0 if failures==0 else 1)
