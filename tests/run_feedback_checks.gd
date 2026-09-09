extends SceneTree
var count:=0
var failed:=0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	count+=1
	if not ok: failed+=1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func frames(n: int=2) -> void:
	for i in n: await physics_frame
	await process_frame

func damage_case(muted: bool, kind: String="engine") -> Dictionary:
	AccessibilitySettings.audio_volume=0 if muted else 0.8
	AccessibilitySettings.fx_level=0 if muted else 2
	AccessibilitySettings.stable_camera=muted; AccessibilitySettings.replay_enabled=not muted
	var world:=Node3D.new(); root.add_child(world)
	var defs:=VehicleDefs.new(); defs.load_defaults()
	var actor:=VehicleActor.new(); world.add_child(actor)
	actor.setup(defs,"player_tank","target",2,Transform3D.IDENTITY,2,null)
	var layout: VehicleLayoutDefinition=ArmorTrainingTargets.build([{"center":Vector3(0,1,-1),"thickness":40}]).layout
	layout.recovery_enabled=true
	var module:=ModuleVolumeDefinition.new(); module.id=kind; module.kind=kind; module.part_id="hull"
	module.local_box_transform=Transform3D(Basis.IDENTITY,Vector3(0,1,-2)); module.size_m=Vector3.ONE
	layout.modules.append(module); actor.set_damage_layout(layout)
	var manager:=ProjectileManager.new(); world.add_child(manager)
	manager.damage_handler=actor.apply_projectile_damage
	manager.projectile_damage.connect(actor.present_damage_record)
	actor.gunner.projectile_manager=manager
	await frames()
	var snapshots: Array=[QuerySnapshotBuilder.build_from_vehicle(actor.tank,layout)]
	var result:=manager.try_spawn({"round_id":26,"shooter_id":"fixture","shooter_life_id":1,"shot_id":1,
		"shell_id":"test_ap","armor_policy":"resolve","penetration_curve":PackedVector2Array([Vector2(0,140 if kind=="ammo" else 70)]),
		"position_world":Vector3(0,1,0),"velocity_world":Vector3(0,0,-600),"gravity_world":Vector3.ZERO,
		"max_age_s":2.0,"max_distance_m":100.0})
	check(result.ok,"real damage fixture launch admitted")
	var state:=manager.get_projectile_state(result.projectile_id)
	manager.advance_projectile(state,1.0/60.0,snapshots,world.get_world_3d().direct_space_state)
	var answer:={"integrity":actor.state.module_states[kind].integrity,"consumed":state.consumed_mm,
		"result":state.contacts[0].result,"drive":actor.capabilities().drive,"destroyed":actor.state.destroyed}
	check(answer.integrity==0 and (not answer.drive if kind=="engine" else answer.destroyed),"real penetration commits actual "+kind+" damage")
	var feedback:=manager.feedback
	var before:=int(feedback.presented.get("penetrated",0))
	feedback.on_contact(state.contacts[0]); feedback.on_contact(state.contacts[0])
	check(int(feedback.presented.get("penetrated",0))==before and before==1,"duplicate actual contact never presents a second sound or spark event")
	check(feedback.fx.spawned==(0 if muted else 1),"effects setting changes only visible particle allocation")
	if kind=="ammo":
		feedback.on_destroyed(actor.state.death_record,weakref(actor))
		check(feedback.presented.get("explosion",0)==1,"actual loaded-rack death presents exactly once even when its record is repeated")
	world.free(); await frames()
	return answer

func _run() -> void:
	var normal:=await damage_case(false)
	var disabled:=await damage_case(true)
	check(normal==disabled,"mute/no-FX/no-shake/no-replay preserves actual penetration, module damage and disabled result exactly")
	var normal_death:=await damage_case(false,"ammo")
	var disabled_death:=await damage_case(true,"ammo")
	check(normal_death==disabled_death and normal_death.destroyed,"all feedback disabled preserves the actual lethal hit and destruction outcome")
	var dust:=StructureDust.new(); root.add_child(dust); dust.start(Vector3.ZERO,"wood")
	var debris:=StructureCollapse.new(); root.add_child(debris); debris.start(Vector3.ONE,"wood")
	await frames(2)
	check(not dust.visible and not debris.visible,"disabled effects hide actual building dust and cosmetic fragments")
	AccessibilitySettings.fx_level=1; await frames(2)
	check(dust.visible and dust._puffs.filter(func(puff: MeshInstance3D) -> bool: return puff.visible).size()==3 and debris._parts.filter(func(row: Dictionary) -> bool: return row.node.visible).size()==4,"reduced effects halve building dust and cosmetic fragment visibility")
	dust.free(); debris.free()
	AccessibilitySettings.audio_volume=0.8; AccessibilitySettings.fx_level=2; AccessibilitySettings.stable_camera=true; AccessibilitySettings.replay_enabled=true
	var world:=Node3D.new(); root.add_child(world)
	WorldArtKit.box(world,Vector3(0,-0.5,0),Vector3(100,1,100),"earth")
	WorldArtKit.box(world,Vector3(0,3,-25),Vector3(30,6,1),"brick")
	var defs:=VehicleDefs.new(); defs.load_defaults()
	var actor:=VehicleActor.new(); world.add_child(actor)
	actor.setup(defs,"player_tank","source",1,Transform3D.IDENTITY,2,null)
	var manager:=ProjectileManager.new(); world.add_child(manager)
	actor.gunner.projectile_manager=manager; actor.gunner.training_resupply=true
	actor.gunner.round_provider=func() -> int: return 26
	actor.gunner.snapshot_provider=func() -> Array: return []
	var feedback:=manager.feedback
	await frames(5)
	var allocated:=feedback.get_child_count()+feedback.audio.get_child_count()+feedback.fx.get_child_count()
	for tick in 16000:
		var command:=VehicleCommand.new(); command.has_aim_point=true; command.aim_world_point=Vector3(0,1.5,-25)
		command.fire_requested=actor.gunner.shots_fired<100
		actor.submit_command(command); await frames(1)
		if actor.gunner.shots_fired>=100 and manager.active_count()==0: break
	check(actor.gunner.shots_fired==100,"100 real Gunner shots with natural reload, finite cooldown and explicit training resupply")
	check(feedback.presented.get("shot",0)==100,"each actual successful shot presents once")
	await frames(150)
	check(feedback.audio.peak_voices<=CombatAudioPool.CAPACITY and feedback.fx.peak_active<=CombatFXPool.CAPACITY,"100 shots stay within allocated audio and particle pools")
	check(feedback.fx.active_count()==0 and allocated==feedback.get_child_count()+feedback.audio.get_child_count()+feedback.fx.get_child_count(),"finished effects recycle without node growth")
	check(feedback.audio.active_count()>0,"live vehicle has a real engine loop")
	paused=true
	for i in 4: await process_frame
	check(feedback.audio.active_count()==0,"pause stops all live audio sources immediately")
	paused=false; await frames(6)
	check(feedback.audio.active_count()>0,"resume recreates only current continuous sound")
	var count_before:=int(feedback.presented.get("shot",0))
	actor.reset_vehicle(); await frames(12)
	check(feedback.presented.get("shot",0)==count_before and feedback.audio.active_count()<=3,"reset does not replay old shots and removes old loop identity")
	for i in CombatAudioPool.CAPACITY:
		feedback.audio.play_voice("load:"+str(i),"engine",Vector3.ZERO,0,1,1,true)
	for i in 8: feedback.audio.play_voice("event_load:"+str(i),"world",Vector3.ZERO,0)
	check(feedback.audio.play_voice("critical","explosion",Vector3.ZERO,4),"priority-pool fixture: a critical clip replaces a saturated low-priority loop")
	check((CombatAudioPool.LOOP_CAPACITY*CombatAudioPool.LOOP_GAIN+8*CombatAudioPool.EVENT_GAIN)*0.8<0.71,"reserved event/loop slots retain a coherent worst-case peak below clipping")
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/manifest.json"))
	check(manifest.clips.size()==13 and manifest.redistribute_source_allowed,"all thirteen original audio clips have provenance and fixed hashes")
	var hashes_ok:=true
	for clip in manifest.clips.values(): hashes_ok=hashes_ok and FileAccess.get_sha256(clip.path)==clip.sha256
	check(hashes_ok,"independent file SHA256 checks match every recorded original audio clip")
	manager.close_round(); await frames(5)
	check(feedback.audio.voices.all(func(voice: Dictionary) -> bool: return voice.key.is_empty() or not voice.loop),"match close stops all continuous sounds while final impact can finish")
	await frames(130)
	check(feedback.audio.active_count()==0 and feedback.fx.active_count()==0,"final impact sounds and transient visuals expire after match close")
	var weak: WeakRef=weakref(feedback.audio)
	world.free(); await frames(3)
	check(weak.get_ref()==null,"leaving the scene releases the sound pool entirely")
	# Fixed-fps simulation runs faster than the audio mixing thread. Let its
	# queued stop commands drain before checking final process cleanup.
	OS.delay_msec(100)
	await frames(3)
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	if failed==0: print("FEEDBACK_CHECKS_PASS")
	quit(0 if failed==0 else 1)
