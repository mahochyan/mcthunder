extends SceneTree
## WT-EXPANSION-01 secondary armament, SCENARIO FIRST. Written before any implementation, on the rule this package
## follows everywhere else: the acceptance check exists first, it fails for the right reason, and only then is the
## implementation written against it.
##
## THE CONTRACT IT ASSERTS comes from the local War Thunder install (build 2.59.0.13) and is recorded in
## docs/wt/wt-reference/WT_REFERENCE_SECONDARY.json:
##   T-80B      coaxial 7.62 mm PKT   belt 750  reload 8 s  cadence 11.66 /s  round ap_i_ball   817.5 m/s
##              AA     12.7 mm NSV     belt 250  reload 5 s  cadence 11.666 /s round ap_i_t_ball 865   m/s
##   Leopard    coaxial 7.92 mm MG3   belt 200  reload 8 s  cadence 20 /s     round ap_ball     853   m/s
##              hull   7.92 mm MG3    belt 200  reload 8 s  cadence 20 /s     round ap_ball     853   m/s
##
## THIS IS AN AUTHORISED EXPANSION BEYOND THE PACKAGE 96 CASES, not one of them: the user asked on 2026-09-19 for
## the game completeness to be raised directly from the unpacked War Thunder data. The probe says so in its own
## name and in the record, so no reader can mistake it for package content.
##
## WHAT IS EXPECTED TODAY: FAILURE. The secondary weapons are not modelled, so the declaration checks fail and
## every cadence check after them is reported as unmet rather than silently skipped.

const SECONDARY := {
	"ussr_t_80b": [
		{"group":"coaxial","caliber_mm":7.62,"belt":750,"reload_s":8.0,"cadence_rps":11.66,"round":"ap_i_ball","speed_mps":817.5},
		{"group":"machinegun","caliber_mm":12.7,"belt":250,"reload_s":5.0,"cadence_rps":11.666,"round":"ap_i_t_ball","speed_mps":865.0}
	],
	"germ_leopard_2a4": [
		{"group":"coaxial","caliber_mm":7.92,"belt":200,"reload_s":8.0,"cadence_rps":20.0,"round":"ap_ball","speed_mps":853.0},
		{"group":"machinegun","caliber_mm":7.92,"belt":200,"reload_s":8.0,"cadence_rps":20.0,"round":"ap_ball","speed_mps":853.0}
	]
}

var checks := 0
var fail := 0
var unmet := 0
const STEP := 1.0/60.0

func _initialize() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: fail += 1
	print("[PASS] " if ok else "[FAIL] ",label)
func _frames(n: int) -> void:
	for i in n: await process_frame

## Site 2 of 3, exercised the only way a player can exercise it: the fire_secondary edge the controller captures in its
## own _process handler, in the same frame the trigger arrives, followed by the release so the next press is a fresh edge
## rather than a held key.
##
## MEASURED, not assumed: in this mode Input.parse_input_event(InputEventKey) does NOT update the action state - the
## event maps to the action (InputMap.event_is_action true) but is_action_pressed stays false before and after a frame
## boundary, so a key-event injection would have "failed" for a reason that has nothing to do with the product. See
## logs/COMBAT-DEEPEN-01/wtexp01-itemB4-diag.log. The action API is the route that works, and the key binding itself is
## asserted from the real InputMap in _run, so both halves are still covered.
func _press_secondary(controller: PlayerController) -> void:
	Input.action_press("fire_secondary")
	controller._process(0.0)
	Input.action_release("fire_secondary")

func _run() -> void:
	var defs := VehicleDefs.new()
	check(defs.load_defaults().ok,"WT-EXPANSION-01 the vehicle definitions load")
	var catalog := VehicleCatalog.new()
	check(catalog.load_all(defs).ok,"WT-EXPANSION-01 the historical packages load")
	check(catalog.load_engineering(defs).ok,"WT-EXPANSION-01 both engineering packets are admitted")
	var world := Node3D.new(); root.add_child(world)
	# The trigger BINDING, read from the real InputMap rather than from the probe's own string, plus the collision check
	# that found the first key choice unusable: physical H is already apply_range in the rebindable table
	# (InputBindingService.ACTIONS), so H would have fired the rangefinder apply and the secondary gun on one press. The
	# chosen key must collide with NO action in the table and NO action in the real InputMap.
	var trigger_event := InputEventKey.new(); trigger_event.physical_keycode = KEY_I; trigger_event.pressed = true
	check(InputMap.has_action("fire_secondary") and InputMap.event_is_action(trigger_event,"fire_secondary"),
		"WT-EXPANSION-01 the secondary trigger key (physical I) is bound to fire_secondary in the real InputMap")
	var trigger_key := 0
	var bound_events: Array = InputMap.action_get_events("fire_secondary")
	if not bound_events.is_empty() and bound_events[0] is InputEventKey: trigger_key = int((bound_events[0] as InputEventKey).physical_keycode)
	var clashes: Array = []
	for action in InputBindingService.ACTIONS.keys():
		if str(action) != "fire_secondary" and int(InputBindingService.ACTIONS[action][1]) == trigger_key: clashes.append(str(action))
	for action in InputMap.get_actions():
		if str(action) == "fire_secondary": continue
		for event in InputMap.action_get_events(action):
			if event is InputEventKey and int((event as InputEventKey).physical_keycode) == trigger_key:
				clashes.append(str(action)); break
	check(clashes.is_empty(),
		"WT-EXPANSION-01 the secondary trigger key collides with no other binding (found: %s)" % str(clashes))
	var index := 0
	for id in SECONDARY.keys():
		index += 1
		var path := "res://configs/vehicles/engineering/" + str(id) + ".json"
		var handle := FileAccess.open(path,FileAccess.READ)
		check(handle != null,"WT-EXPANSION-01 %s packet is readable" % str(id))
		if handle == null: continue
		var packet: Dictionary = JSON.parse_string(handle.get_as_text())
		# 1. THE DECLARATION, read from the packet rather than assumed: a list of secondary weapons with the
		#    groups the file names, so a coaxial and an anti-air gun are distinguishable.
		var declared: Array = packet.get("secondary_weapons",[])
		check(declared.size()==(SECONDARY[id] as Array).size(),
			"WT-EXPANSION-01 %s declares its %d secondary weapons" % [str(id),(SECONDARY[id] as Array).size()])
		var by_group := {}
		for row in declared:
			if row is Dictionary: by_group[str(row.get("group",""))] = row
		for want in SECONDARY[id]:
			var got: Dictionary = by_group.get(str(want.group),{})
			check(not got.is_empty(),"WT-EXPANSION-01 %s declares a %s weapon" % [str(id),str(want.group)])
			if got.is_empty():
				unmet += 1
				continue
			check(absf(float(got.get("caliber_mm",0.0))-float(want.caliber_mm))<0.01,
				"WT-EXPANSION-01 %s %s caliber is the file value %.2f mm" % [str(id),str(want.group),float(want.caliber_mm)])
			check(int(got.get("belt",0))==int(want.belt),
				"WT-EXPANSION-01 %s %s belt is the file value %d" % [str(id),str(want.group),int(want.belt)])
			check(absf(float(got.get("reload_s",0.0))-float(want.reload_s))<0.01,
				"WT-EXPANSION-01 %s %s reload is the file value %.1f s" % [str(id),str(want.group),float(want.reload_s)])
			check(absf(float(got.get("cadence_rps",0.0))-float(want.cadence_rps))<0.01,
				"WT-EXPANSION-01 %s %s cadence is the file value %.3f /s" % [str(id),str(want.group),float(want.cadence_rps)])
			check(absf(float(got.get("speed_mps",0.0))-float(want.speed_mps))<0.5,
				"WT-EXPANSION-01 %s %s round speed is the file value %.1f m/s" % [str(id),str(want.group),float(want.speed_mps)])
			check(str(got.get("round",""))==str(want.round),
				"WT-EXPANSION-01 %s %s carries the file round %s" % [str(id),str(want.group),str(want.round)])
		# 2. THE RUNTIME: a real actor must expose the second firing channel with its own belt and cadence, and the
		#    main gun must be untouched, which is the whole point of a separate channel rather than a bigger magazine.
		var actor := VehicleActor.new(); world.add_child(actor)
		var installed := actor.setup(defs,str(id),"wtexp01_"+str(index),index,Transform3D.IDENTITY,2,null)
		check(installed.ok,"WT-EXPANSION-01 %s installs a real actor" % str(id))
		await _frames(30)
		actor.set_physics_process(false); actor.tank.set_physics_process(false)
		var channels := 0
		if actor.gunner != null and actor.gunner.get("secondary") != null: channels = (actor.gunner.secondary as Array).size()
		check(channels==(SECONDARY[id] as Array).size(),
			"WT-EXPANSION-01 %s runtime exposes %d secondary firing channels" % [str(id),channels])
		if channels==0: unmet += 1
		# 3. THE FIRE REQUEST IS ANSWERED, never faked: with the channels installed the request must be answered
		#    with either a real shot or a refusal BY NAME. Until the round own impact profile is declared the honest
		#    answer is secondary_round_profile_missing, and a belt that was not debited proves no silent shot.
		if channels > 0:
			# A REAL manager is bound first: without one the channel would only account for a round, and the
			# difference between an accounted round and a flown one is exactly what this leg exists to measure.
			var manager := ProjectileManager.new(); manager.presentation_enabled=false
			world.add_child(manager); manager.set_physics_process(false)
			actor.gunner.projectile_manager = manager
			actor.gunner.round_provider = func() -> int: return 7001
			var belt_before: int = int(actor.gunner.secondary_channel(0).get("belt_remaining",0))
			# ITEM A: the shot must enter the SAME record path the replay reads. Written against the store REAL
			# interface this time - count() and get_record(index) exist, and a record is a DICTIONARY, so its
			# fields are read with get() rather than with property access, which is what produced three script
			# errors when this leg was first attempted and then reverted.
			var records_before: int = manager.shot_records.count()
			var answer: Dictionary = actor.gunner.try_fire_secondary(0)
			var belt_after: int = int(actor.gunner.secondary_channel(0).get("belt_remaining",0))
			var pid: int = int(actor.gunner.secondary_channel(0).get("last_projectile_id",0))
			# THE FLIGHT MUST BE ADVANCED FIRST: the manager freezes a shot record when the round TERMINATES
			# (ShotRecordBuilder.freeze at the terminal path), not when it spawns. The previous round read records
			# 0 -> 0 without flying the round and called that a product gap; it was this leg own gap, and this is
			# the correction.
			var space := world.get_world_3d().direct_space_state
			var flight: ProjectileState = manager.get_projectile_state(pid)
			var advanced := 0
			if flight != null:
				# The cap must EXCEED the round own flight age: 4 s at a 1/240 step is 960 steps, so the first
				# version cap of 900 stopped the flight just short of its own expiry and the record never froze.
				for i in 2400:
					if flight.is_terminal(): break
					manager.advance_projectile(flight,1.0/240.0,[],space)
					advanced += 1
			var records_after: int = manager.shot_records.count()
			var identity_line := "none"
			if records_after > records_before:
				var record: Dictionary = manager.shot_records.get_record(records_after-1)
				var ident: Dictionary = record.get("identity",{})
				identity_line = "shell_id=%s shooter=%s shot=%s terminal=%s" % [str(ident.get("shell_id","")),str(ident.get("shooter_id","")),str(ident.get("shot_id","")),str(record.get("terminal_reason",""))]
			print("[WT-EXPANSION-01] %s fire answer: %s (belt %d -> %d, projectile_id=%d, advanced=%d, records %d -> %d)" % [str(id),str(answer),belt_before,belt_after,pid,advanced,records_before,records_after])
			print("[WT-EXPANSION-01] %s record identity: %s" % [str(id),identity_line])
			check(records_after>records_before,"WT-EXPANSION-01 %s the secondary shot enters the SAME shot-record path the replay reads" % str(id))
			check(answer.get("reason","")!="" ,"WT-EXPANSION-01 %s the secondary fire request is ANSWERED" % str(id))
			if not bool(answer.get("ok",false)):
				check(belt_after==belt_before,"WT-EXPANSION-01 %s a refused secondary shot debits NOTHING" % str(id))
			else:
				check(belt_after==belt_before-1,"WT-EXPANSION-01 %s a fired secondary shot debits exactly one round" % str(id))
				# The projectile is judged through its RECORD, because a terminated round is removed from the active
				# states: asserting get_projectile_state after the flight is advanced tests the wrong moment.
				check(pid!=0 and records_after>records_before,
					"WT-EXPANSION-01 %s the launched round is a real projectile AND is recorded (%d / %d records)" % [str(id),pid,records_after])
			# 4. THE INPUT PATH, which is the only path a player has. Legs 2-3 call the Gunner directly and would keep
			#    passing even if no key, no command field and no simulation site existed. This leg binds a REAL
			#    PlayerController to the actor, presses the real key, and lets the actor's own committed step run the
			#    whole chain: controller edge -> VehicleCommand -> VehicleCommandCodec body -> mailbox -> consume ->
			#    finish_simulation_command -> Gunner. Nothing here calls try_fire_secondary.
			actor.gunner.secondary_channel(0)["cooldown_left"] = 0.0   # the input leg measures the input path, not leg 3's cadence
			var controller := PlayerController.new(); world.add_child(controller)
			actor.set_controller(controller)
			var seen: Array = []
			actor.command_observer = func(_a: VehicleActor,c: VehicleCommand) -> void: seen.append(c.secondary_fire_requested)
			var belt_in: int = int(actor.gunner.secondary_channel(0).get("belt_remaining",0))
			var shots_in: int = int(actor.gunner.secondary_channel(0).get("shots_fired",0))
			_press_secondary(controller)
			actor.advance_standalone_tick(STEP)
			actor.command_observer = Callable()
			var belt_out: int = int(actor.gunner.secondary_channel(0).get("belt_remaining",0))
			var shots_out: int = int(actor.gunner.secondary_channel(0).get("shots_fired",0))
			var answer_input: Dictionary = actor.last_secondary_result
			var live_pid: int = int(actor.gunner.secondary_channel(0).get("last_projectile_id",0))
			var live: bool = manager.get_projectile_state(live_pid) != null
			print("[WT-EXPANSION-01] %s input path: command carried secondary=%s, answer=%s, belt %d -> %d, shots %d -> %d, live projectile %d=%s" % [str(id),str(seen),str(answer_input),belt_in,belt_out,shots_in,shots_out,live_pid,str(live)])
			check(seen.size()==1 and seen[0]==true,
				"WT-EXPANSION-01 %s a press of the real secondary key publishes a secondary request on the committed command" % str(id))
			check(shots_out==shots_in+1 and belt_out==belt_in-1,
				"WT-EXPANSION-01 %s the input path fires the secondary channel and debits exactly one round" % str(id))
			check(str(answer_input.get("reason",""))=="fired",
				"WT-EXPANSION-01 %s the input path records the Gunner answer (fired) on the actor" % str(id))
			check(live,"WT-EXPANSION-01 %s the input path launches a LIVE projectile from the channel muzzle" % str(id))
			# 5. THE CADENCE CLOCK. A channel whose clock never ticks fires once per belt and then refuses as cooldown
			#    forever, so this leg first proves the request is an EDGE, then proves the declared cadence is actually
			#    decremented by the simulation advance. The clock is FORCED OPEN for the latch probe so that cooldown
			#    cannot explain the silence, and it is the real declared cadence that has to run down afterwards.
			actor.gunner.secondary_channel(0)["cooldown_left"] = 0.0
			actor.advance_standalone_tick(STEP)
			var no_press: int = int(actor.gunner.secondary_channel(0).get("shots_fired",0))
			check(no_press==shots_out,
				"WT-EXPANSION-01 %s the request is an EDGE not a latch: a tick with no new press fires nothing" % str(id))
			var cadence_s := float(actor.gunner.secondary_channel(0).get("cadence_s",0.0))
			_press_secondary(controller)
			actor.advance_standalone_tick(STEP)
			var armed: int = int(actor.gunner.secondary_channel(0).get("shots_fired",0))
			var armed_cooldown := float(actor.gunner.secondary_channel(0).get("cooldown_left",0.0))
			check(armed==no_press+1 and absf(armed_cooldown-cadence_s)<0.000001,
				"WT-EXPANSION-01 %s a fired channel arms the declared cadence %.4f s" % [str(id),cadence_s])
			var waited := 0
			while float(actor.gunner.secondary_channel(0).get("cooldown_left",0.0)) > 0.0 and waited < 600:
				actor.advance_standalone_tick(STEP); waited += 1
			var clock_ran := float(actor.gunner.secondary_channel(0).get("cooldown_left",0.0)) <= 0.0
			_press_secondary(controller)
			actor.advance_standalone_tick(STEP)
			var shots_after_wait: int = int(actor.gunner.secondary_channel(0).get("shots_fired",0))
			print("[WT-EXPANSION-01] %s cadence: declared %.4f s, %d simulation steps cleared the clock (ran=%s), then shots %d -> %d, answer=%s" % [str(id),cadence_s,waited,str(clock_ran),armed,shots_after_wait,str(actor.last_secondary_result)])
			check(clock_ran,"WT-EXPANSION-01 %s the simulation advance decrements the declared cadence to zero (%d steps)" % [str(id),waited])
			check(shots_after_wait==armed+1,
				"WT-EXPANSION-01 %s the channel fires again once its cadence elapses in simulation time" % str(id))
			# 6. THE WIRE BODY carries the intent, so the field is not silently dropped between controller and actor.
			#    Asserted on the codec itself because the input leg above would otherwise pass on the local mailbox while
			#    the encoded body lost the field it supposed to carry.
			var rt_cmd := VehicleCommand.new(); rt_cmd.secondary_fire_requested = true; rt_cmd.secondary_fire_index = 1
			var roundtrip: Dictionary = VehicleCommandCodec.decode({"version":VehicleCommandCodec.VERSION,"entity_id":actor.entity_id,"life_id":actor.life_id,"generation":actor.state.generation,"control_epoch":actor.control_epoch,"sequence":1,"input_tick":Engine.get_physics_frames(),"command":VehicleCommandCodec.encode_body(rt_cmd)})
			check(roundtrip.get("ok",false) and roundtrip.command.secondary_fire_requested and int(roundtrip.command.secondary_fire_index)==1,
				"WT-EXPANSION-01 %s the command body round-trips the secondary trigger and its channel index" % str(id))
			controller.queue_free()
		actor.queue_free()
	world.queue_free(); await _frames(2)
	# 7. THE OVERLAY. Everything above proves the channels exist, fire and answer; none of it proves a player can SEE
	#    them. This leg loads the real battle scene with the engineering T-80B as the player vehicle and reads the HUD
	#    label the ordinary battle draws, so the chain is packet -> actor -> battle_ui model -> on-screen text. The
	#    scene setup follows the established pattern in tests/run_vehicle_damage_hud_checks.gd.
	var battle: RiverTeamRange = load(MapRegistry.scene_path("river_junction_team")).instantiate()
	battle.selected_vehicle_id = "ussr_t_80b"
	battle.opposing_engineering_id = "germ_leopard_2a4"
	root.add_child(battle); current_scene = battle
	for i in 200: await physics_frame
	check(battle.team_ready,"WT-EXPANSION-01 the battle scene with the engineering T-80B reaches ready")
	if battle.team_ready:
		for actor in battle.combat_actors(): actor.set_physics_process(false)
		var hud: BattleHUD = battle.battle_ui.overlay
		for i in 12: await physics_frame
		var rows: Variant = hud.view_model.get("secondary_channels",null)
		var text: String = hud.ammo_label.text
		print("[WT-EXPANSION-01] overlay rows=%s label=%s" % [str(rows),text.replace("\n"," | ")])
		check(rows is Array and (rows as Array).size()==2,
			"WT-EXPANSION-01 the battle HUD model carries both authored secondary channels of the player vehicle")
		check(text.contains("coaxial 750/750") and text.contains("machinegun 250/250"),
			"WT-EXPANSION-01 both secondary channel rows are DRAWN on the battle HUD with their belt state")
		check(text.contains("SEC") and text.contains("I"),
			"WT-EXPANSION-01 the drawn row carries the trigger key read back from the real InputMap")
	battle.free(); await _frames(2)
	print("=== result: %d checks, %d failed, %d unmet-declaration legs ==="%[checks,fail,unmet])
	print("WT_EXPANSION_01_%s"%("PASS" if fail==0 else "FAIL"))
	quit(0 if fail==0 else 1)
