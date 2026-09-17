class_name TeamRange
extends BallisticsRange
signal restart_requested
signal return_requested(result: Dictionary)
var director: TeamMatchDirector
var nav := DriveNavigator.new()
var wrecks: WreckRegistry
var team_ready := false
var top_label: Label
var action_label: Label
var capture_ring: MeshInstance3D
var capture_material: StandardMaterial3D
var waiting_panel: PanelContainer
var waiting_label: Label
var respawn_button: Button
var vehicle_choice: OptionButton
var result_panel: PanelContainer
var result_text: Label
var result_body := ""
var restart_button: Button
var return_button: Button
var spectator: Camera3D
var spectator_index := 0
var shield_visuals: Dictionary = {}
var battle_ui: BattleUI
var match_seed := 1600
var ai_only := false # Explicit scenario-runner configuration; normal garage play is false.
var telemetry: TrafficTelemetry = null      # read-only mobility sampling, fresh per match
var _telemetry_phase := ""
var ammunition_supply := AmmunitionSupply.new()
var respawn_vehicle_id := ""
## WT-040-R1 (2026-09-17 ruling, work order D/C): an explicit ENGINEERING SCENARIO hook, empty by default so
## nothing changes unless a test or an internal engineering entry sets it. It assigns the OPPOSING team's vehicle
## type so one internal match can field T-80B against Leopard 2A4, which is what the ruling asks the modern river
## record to show. It changes team composition only - no ticket, capture, damage, reload or termination rule is
## touched, and an unknown id is still refused by the readiness gate.
var opposing_engineering_id := ""
var garage_service: GarageService
var simulation_snapshot: SimulationSnapshot
var coordinators: Dictionary = {}          # team -> TeamCoordinator (WT-040-R1)
var _match_objectives: Array = []          # cached result of the match_objectives() hook
var _task_tick := 0                        # WT-040-R1: throttles the task layer to 2 Hz
var _applied_task: Dictionary = {}         # entity_id -> "role:objective" last handed to the AI

func _ready() -> void:
	# 027-A moved named input actions out of project.godot into the binding
	# service; any path that instantiates a battle scene directly (tests, editor
	# run of a scene) would otherwise get an EMPTY InputMap. The real game calls
	# app_flow first with the persisted path — the static initialized guard then
	# skips this default-only call, so user bindings are never overwritten.
	InputBindingService.initialize()
	super._ready()
	if not _initialized: return
	process_physics_priority = SimulationPhases.SUPPLY
	vehicle_simulation.actor_provider=Callable(self,"combat_actors")
	simulation_snapshot = SimulationSnapshot.new()
	simulation_snapshot.battle = self
	add_child(simulation_snapshot)
	if prepared_match != null: garage_service = GarageService.new(); respawn_vehicle_id = prepared_match.selected()
	director = TeamMatchDirector.new()
	add_child(director)
	# WT-040-R1 (user finding, verified in source): the director was begun with NO objectives, so
	# state.objectives stayed null and capturing could never happen on any map; and TeamCoordinator
	# was never instantiated at all, so the AI role/task layer never ran and task_objective stayed
	# empty. The objectives now come from a scene hook. It returns an empty array by default, and
	# everything below is gated on "objectives present", so maps that do not override the hook behave
	# exactly as before - only a map that supplies its objectives (the river today) takes this path.
	director.begin(4, match_objectives())
	projectiles.projectile_contact.connect(director.observe_contact)
	if ai_only: director.state.roster.A.player = false
	nav.configure(navigation_graph())
	director.respawns.spawn_provider = Callable(self,"spawn_slot")
	director.round_started.connect(_start_playing)
	director.vehicle_lost.connect(_on_lost)
	director.match_finished.connect(_finish_match)
	wrecks = WreckRegistry.new()
	add_child(wrecks)
	wrecks.protected_provider = func(vehicle: VehicleActor) -> bool: return vehicle == actor
	actor.tank.global_transform = spawn_candidates(1)[0]
	_configure_vehicle(actor,"A")
	director.state.register_spawn("A",actor)
	for id in director.state.roster:
		if id == "A": continue
		var vehicle := spawn_slot(id)
		if vehicle == null:
			push_error("016 initial spawn blocked: "+id)
			return
		director.state.register_spawn(id,vehicle)
	projectiles.contact_policy = Callable(self,"contact_policy")
	projectiles.damage_handler = Callable(self,"_apply_projectile_damage")
	projectiles.armor_handler = Callable(self,"_apply_projectile_armor")
	replay.allowed_record = func(_record: Dictionary) -> bool: return director.state.phase == "finished"
	replay.auto_replay = false
	replay.view.chinese = true
	hud.replay_toggle_button.visible = false
	CoreUI.apply(hud)
	hud.font_cjk = true
	hud.S = hud._strings(true)
	_build_ui()
	_build_capture_ring()
	spectator = Camera3D.new()
	spectator.position = Vector3(-30,28,55)
	add_child(spectator)
	spectator.look_at(Vector3.ZERO)
	if ai_only:
		spectator.position = Vector3(-115,60,125)
		spectator.look_at(Vector3.ZERO)
		spectator.current = true
	controller.commands_enabled = false
	controller.reset_pending()
	team_ready = true
	battle_ui = BattleUI.new()
	add_child(battle_ui)
	battle_ui.setup(self)

func _build_world() -> void: TeamArena.build(self)
func supply_positions(_team: int) -> Array[Vector3]: return []

func _in_supply_area(vehicle: VehicleActor) -> bool:
	for point in supply_positions(vehicle.state.team_id):
		if Vector2(vehicle.tank.global_position.x-point.x,vehicle.tank.global_position.z-point.z).length() <= AmmunitionSupply.RADIUS_M: return true
	return false

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not team_ready: return
	if _telemetry_phase != director.state.phase:
		if director.state.phase == "playing": telemetry = TrafficTelemetry.new()
		_telemetry_phase = director.state.phase
	if get_tree().paused or director.state.phase != "playing": return
	for vehicle in combat_actors():
		ammunition_supply.step(vehicle,delta,_in_supply_area(vehicle))
	telemetry.step(combat_actors(),delta)
	# WT-040-R1: drive the per-team task coordinators. Gated on objectives being present, so the
	# default (empty) hook leaves existing behaviour untouched.
	if not _match_objectives.is_empty():
		# WT-040-R1: the task layer is a decision layer with hysteresis, and apply_task resolves an
		# objective position per actor (which can query the navigator). Running it every physics tick
		# starved the simulation - the first attempt produced no samples at all in ninety seconds - so
		# it runs at 2 Hz. No thresholds, speeds or decisions are changed; only how often the layer is
		# consulted.
		_task_tick += 1
		if _task_tick % 30 == 0:
			for team in [1,2]:
				var coordinator := coordinator_for(team)
				coordinator.set_roster(roster_rows(team))
				coordinator.step(director.state.elapsed,delta*30.0)
				# WT-040-R1: apply_task() is documented as "consume one allocation round", so it is
				# called when the allocation actually CHANGES for that actor, not on every tick of this
				# throttle. Calling it unconditionally re-ran set_patrol (and therefore a route plan)
				# for every actor twice a second, which made the river match crawl; the semantics are
				# unchanged, only the redundant re-application is gone.
				for actor in combat_actors():
					if int(actor.state.team_id) != team: continue
					var team_ai: AITankController = actor.controller as AITankController
					if team_ai == null: continue
					var task := coordinator.allocator.task_for(actor.entity_id)
					var signature := "%s:%s" % [str(task.get("role","")), str(task.get("objective",""))]
					if _applied_task.get(actor.entity_id,"") == signature: continue
					_applied_task[actor.entity_id] = signature
					team_ai.apply_task(coordinator.context)

## WT-040-R1 scene hook: the map's capture objectives in the allocator's shape,
## [{id, position:Vector3, owner_team}]. Empty means "this map does not publish objectives yet".
func match_objectives() -> Array:
	if _match_objectives.is_empty(): _match_objectives = _build_match_objectives()
	return _match_objectives

func _build_match_objectives() -> Array:
	return []

## The allocator's own shape, derived from the same authored rows: [{id, position, owner_team}].
## Keeping the conversion here means the capture layer and the task layer can never disagree about
## where the objectives are, and the map only authors them once.
##
## WT-040-R1: each centre is passed through _snap_to_graph() first. The capture centre of an
## objective is a place to stand, not necessarily a point on the driving graph - feeding the raw
## centre to the allocator made a slot report driver="unreachable" the moment it took its task, which
## is the same class of failure as the earlier task-point bug. Maps that know their graph override
## _snap_to_graph (the river does); the default returns the point unchanged.
func allocator_objectives() -> Array:
	var out: Array = []
	for row in match_objectives():
		if not row is Dictionary: continue
		var center: Variant = row.get("center", null)
		if not center is Vector3: continue
		out.append({"id": str(row.get("id","")), "position": _snap_to_graph(center), "owner_team": 0})
	return out

## Default: no graph knowledge in the base class, so the point is returned unchanged.
func _snap_to_graph(wanted: Vector3) -> Vector3:
	return wanted

## One coordinator per team, configured with the same objectives the director got.
func coordinator_for(team: int) -> TeamCoordinator:
	if coordinators.has(team): return coordinators[team]
	var coordinator := TeamCoordinator.new()
	coordinator.configure(team,allocator_objectives(),{},Callable())
	coordinators[team] = coordinator
	return coordinator

## The roster rows the coordinator's own contract expects (see TeamCoordinator.classify).
func roster_rows(team: int) -> Array:
	var rows: Array = []
	for actor in combat_actors():
		if int(actor.state.team_id) != team: continue
		var ai: AITankController = actor.controller as AITankController
		var speed: float = actor.tank.velocity.length()
		rows.append({
			"entity_id": actor.entity_id,
			"position": actor.tank.global_position,
			"destroyed": actor.state.destroyed,
			"mobile": actor.capabilities().drive,
			"speed_mps": speed,
			"blocked": ai != null and ai.driver.phase == "blocked",
			"at_objective": ai != null and actor.tank.global_position.distance_to(ai.patrol_goal) < 15.0,
			"engaging": ai != null and ai.phase == "engage",
			"repairing": ai != null and ai.phase == "repair",
		})
	return rows
func navigation_graph() -> Dictionary: return TeamArena.graph()
func spawn_candidates(team: int) -> Array[Transform3D]: return TeamArena.candidates(team)
func objective_goal(team: int, index: int) -> Vector3: return TeamArena.goal(team,index)
func minimap_metadata() -> Dictionary:
	return {"bounds":Rect2(-50,-70,100,140),"obstacles":[Rect2(-10,-36,20,4),Rect2(-10,32,20,4),Rect2(-16,12,8,6),Rect2(8,-18,8,6)],"title":LocalizationService.text("ui_e1ffb1a7924d")}
func get_round_id() -> int: return director.state.match_id if director != null else 0
func combat_actors() -> Array:
	var out: Array = []
	for child in get_children():
		if child is VehicleActor and not child.is_queued_for_deletion(): out.append(child)
	return out
func query_snapshots() -> Array:
	var out: Array = []
	for vehicle in combat_actors():
		if vehicle.damage_layout_override != null: out.append(QuerySnapshotBuilder.build_from_vehicle(vehicle.tank,vehicle.damage_layout_override))
	return out
func projectile_exclude_rids(shooter_id: String, shooter_life_id: int) -> Array[RID]:
	var vehicle := find_actor(shooter_id,shooter_life_id)
	var excluded: Array[RID] = []
	if vehicle != null: excluded.append(vehicle.tank.get_rid())
	return excluded
func find_actor(id: String, life: int) -> VehicleActor:
	for vehicle in combat_actors():
		if vehicle.entity_id == id and vehicle.life_id == life: return vehicle
	return null

func spawn_slot(id: String) -> VehicleActor:
	if director == null or director.state.phase not in ["countdown","playing"]: return null
	var row: Dictionary = director.state.roster[id]
	var occupied: Array[Vector3] = []
	for existing in combat_actors(): occupied.append(existing.tank.global_position)
	# WT-032-R1: wrecks still occupy ground; without them a respawn could be placed inside
	# a wreck. SpawnSelector then either picks another slot or reports spawn_blocked.
	if wrecks != null: occupied.append_array(wrecks.wreck_positions())
	var candidates := spawn_candidates(row.team)
	var type_id := vehicle_id_for_slot(id)
	# WT-040-R1 (2026-09-17 ruling): an admitted combat vehicle uses its own drive collision size. When the
	# definition is not loaded in this context the documented training box is used and the gap is REPORTED as a
	# warning - not silently swallowed and not turned into a refusal, because a synthetic test context may
	# legitimately not load the catalog. Genuinely unknown ids never reach here: vehicle_id_for_slot refuses them.
	var size := Vector3(2.85,1.68,5.45)
	if defs.vehicles.has(type_id):
		size = defs.get_vehicle(type_id).drive_collision_size
	else:
		push_warning("spawn size fallback: no definition loaded for known vehicle id: "+type_id)
	var checked := SpawnSelector.evaluate(get_world_3d().direct_space_state,candidates,size,occupied)
	if not checked.ok: return null
	var vehicle := VehicleActor.new()
	vehicle.name = "Vehicle_"+id+"_"+str(row.spawns+1)
	add_child(vehicle)
	var setup := vehicle.setup(defs,type_id,id,row.team,checked.transform,2 if id == "A" else 4,null)
	if not setup.ok: vehicle.free(); return null
	_configure_vehicle(vehicle,id)
	if id == "A":
		actor = vehicle
		if not ai_only:
			vehicle.set_controller(controller)
			controller.reset_pending()
			controller.require_fire_release()
			controller.commands_enabled = true
			if is_instance_valid(spectator): spectator.current = false
			vehicle.cam_rig.cam.current = true
			if is_instance_valid(waiting_panel): waiting_panel.visible = false
			if DisplayServer.get_name() != "headless": Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	return vehicle

func vehicle_id_for_slot(id: String) -> String:
	# WT-040-R1 (2026-09-17 ruling): the known training hull keeps its own path and never enters the combat
	# readiness gate (the gate's admitted list is built from content packets and does not contain it). Everything
	# else must be curated history or an explicitly admitted engineering vehicle; a genuinely unknown id is
	# REFUSED instead of being silently replaced by player_tank.
	if VehicleCatalog.is_training(selected_vehicle_id): return "player_tank"
	if not VehicleCatalog.is_known_vehicle(selected_vehicle_id):
		push_error("team match refused: selected vehicle is not a known vehicle: "+selected_vehicle_id)
		return ""
	var requested := selected_vehicle_id
	if id == "A":
		requested = respawn_vehicle_id if prepared_match != null else selected_vehicle_id
	else:
		var ids: Array = director.state.roster.keys()
		ids.sort()
		# Same four-vehicle rotation on both teams, anchored on the player's selected type.
		# WT-040-R1: the four-vehicle rotation is a HISTORICAL roster affair. When the player has chosen an
		# engineering vehicle the whole team fields that type instead of being rotated into history.
		if VehicleCatalog.is_historical(selected_vehicle_id):
			requested = VehicleCatalog.IDS[(ids.find(id)%4+VehicleCatalog.IDS.find(selected_vehicle_id))%4]
		else:
			requested = selected_vehicle_id
		# The engineering scenario hook, when set, gives the opposing team the other modern type. It is applied
		# AFTER the rotation decision and only for AI slots, and the readiness gate still decides whether that id
		# may fight at all.
		if not opposing_engineering_id.is_empty() and id != "A":
			requested = opposing_engineering_id
	# WT-031-R1: AI slots and respawn go through the same readiness gate as the player;
	# a preview-only or unadmitted id can never reach the battlefield.
	# WT-040-R1 (2026-09-17 ruling): use the definitions the MATCH actually loaded. A fresh VehicleCatalog has an
	# empty packages dictionary, so the readiness gate fell back to VehicleCatalog.IDS and every engineering
	# vehicle was ineligible - the AI slots then took the first historical type instead of the chosen engineering
	# one, which the direct wiring check showed as definition id us_m4a3_75w_vvss_1944 on every AI slot. No gate
	# is widened; the gate now simply sees the same admitted set the spawn path uses.
	# WT-040-R1 (2026-09-17 ruling): the MODE must match the vehicle being checked. The primary check below used
	# to pass "training" while only the fallback used the engineering mode, so every engineering request was
	# judged preview_only by the primary check and then rescued by the fallback - functionally right but with a
	# spurious warning on every AI slot, and with the wrong mode standing in for a decision. Both now use the same
	# mode, derived from either the selected or the requested vehicle. No gate is widened: the mode only decides
	# whether the PUBLIC preview_only mark blocks, exactly as before.
	var catalog: VehicleCatalog = historical_catalog if historical_catalog != null else VehicleCatalog.new()
	var gate_mode := "engineering" if (VehicleCatalog.is_engineering(selected_vehicle_id) or VehicleCatalog.is_engineering(requested)) else "training"
	var checked := VehicleReadiness.eligible(requested,gate_mode,{},catalog)
	if checked.ok: return requested
	var fallback := VehicleReadiness.first_eligible([requested,selected_vehicle_id],gate_mode,{},catalog)
	if fallback.ok:
		push_warning("vehicle readiness fallback slot=%s requested=%s code=%s" % [id,requested,checked.code])
		return str(fallback.get("id",""))
	push_error("team match refused: no admitted combat vehicle for slot %s (requested %s, code %s)" % [id,requested,checked.code])
	return ""

func _configure_vehicle(vehicle: VehicleActor, id: String) -> void:
	vehicle.simulation_driver=weakref(vehicle_simulation)
	if id == "A" and prepared_match != null:
		if not garage_service.install(vehicle,prepared_match.loadout(vehicle.definition.id)): push_error("respawn loadout rejected")
	# WT-040-R1 (2026-09-17 ruling): the training profile belongs to the training vehicle only. An engineering
	# vehicle keeps its own admitted configuration, and anything that is not a known vehicle is refused rather
	# than quietly given training armour.
	var combat_id := vehicle.definition.id
	if combat_id == "player_tank":
		M4EngineeringProfile.apply(vehicle)
	elif not VehicleCatalog.is_known_vehicle(combat_id):
		push_error("vehicle configuration refused: not a known vehicle: "+combat_id)
		return
	vehicle.state.recovery_enabled = true
	vehicle.gunner.projectile_manager = projectiles
	vehicle.gunner.snapshot_provider = Callable(self,"query_snapshots")
	vehicle.gunner.round_provider = Callable(self,"get_round_id")
	vehicle.gunner.shell = vehicle.gunner.shell.duplicate(true)
	# WT-040-R1 (2026-09-17 ruling): the training round, its policy and its flat curve belong to the training
	# vehicle only; an engineering vehicle keeps the round its own admitted loadout installed.
	if combat_id == "player_tank":
		vehicle.gunner.shell.id = "team_ap120"
		vehicle.gunner.shell.armor_policy = "resolve"
		vehicle.gunner.shell.penetration_curve = PackedVector2Array([Vector2(0,120),Vector2(200,120)])
	vehicle.gunner.training_resupply = false
	vehicle.command_observer = Callable(director,"observe_command")
	vehicle.vehicle_destroyed.connect(director.on_vehicle_destroyed)
	vehicle.label3d.font = CoreUI.FONT
	vehicle.label3d.text = LocalizationService.text("ui_991e63fe2920") if id == "A" else (LocalizationService.text("ui_75955e05c89a")+id if vehicle.state.team_id == 1 else LocalizationService.text("ui_f951074d9cca")+id)
	vehicle.label3d.modulate = Color("8ecde6") if vehicle.state.team_id == 1 else Color("e7ae8b")
	var visuals := RecoveryVisuals.new()
	vehicle.add_child(visuals)
	visuals.setup(vehicle)
	var shield := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 1.8
	ring.outer_radius = 1.9
	ring.rings = 24
	ring.ring_segments = 4
	shield.mesh = ring
	shield.position.y = 0.08
	shield.scale.z = 1.65
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("96e6ee")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shield.material_override = material
	vehicle.tank.add_child(shield)
	shield_visuals[vehicle.life_id] = {"actor":weakref(vehicle),"mesh":shield}
	if id != "A" or ai_only:
		var ai := AITankController.new()
		vehicle.add_child(ai)
		var index := 0 if id.length() == 1 else int(id.substr(1))-1
		ai.configure(vehicle,nav,Callable(self,"combat_actors"),prepared_match.difficulty() if prepared_match != null else "normal",match_seed+vehicle.state.team_id*100+index*17+int(director.state.roster[id].spawns)*101)
		ai.advance_while_engaged = true
		ai.set_patrol(objective_goal(vehicle.state.team_id,index),spawn_candidates(vehicle.state.team_id)[index].origin*Vector3(1,0,1))
		# WT-040-R1: bind the team's task allocator so the AI actually receives a role/objective.
		# Gated on objectives being present, so maps without the hook keep their current behaviour.
		if not match_objectives().is_empty():
			ai.bind_allocator(coordinator_for(int(vehicle.state.team_id)).allocator)
		vehicle.set_controller(ai)
		vehicle.cam_rig.set_process(false)
		vehicle.cam_rig.set_physics_process(false)
		vehicle.gunner.aim_preview_enabled = false
		vehicle.turret.set_aim_point(Vector3(0,2,0))
		vehicle.turret.snap_to_aim()
	vehicle.set_physics_process(director.state.phase == "playing")

func contact_policy(shooter: Dictionary, contact: Dictionary) -> Dictionary:
	if director == null or director.state.phase != "playing" or shooter.get("round_id",-1) != get_round_id(): return {"allow":false,"reason":"match_not_playing"}
	var target := find_actor(str(contact.get("entity_id","")),int(contact.get("life_id",0)))
	if target == null: return {"allow":false,"reason":"stale_target"}
	if target.state.team_id == shooter.get("shooter_team_id",-1): return {"allow":false,"reason":"friendly_block"}
	if target.state.destroyed: return {"allow":false,"reason":"wreck_block"}
	if director.state.is_protected(target.entity_id,target.life_id): return {"allow":false,"reason":"spawn_protected"}
	return {"allow":true}

func _apply_projectile_armor(event: Dictionary, direction: Vector3, budget: Dictionary) -> Dictionary:
	if director==null or director.state.phase!="playing" or event.get("round_id",-1)!=get_round_id(): return {"ok":false,"reason":"match_not_playing"}
	var vehicle := find_actor(str(event.get("entity_id","")),int(event.get("life_id",0)))
	if vehicle==null or vehicle.state.destroyed or director.state.is_protected(vehicle.entity_id,vehicle.life_id): return {"ok":false,"reason":"target_unavailable"}
	var shooter := director.state.actor_for(str(event.get("shooter_id","")))
	if shooter!=null and shooter.state.team_id==vehicle.state.team_id: return {"ok":false,"reason":"friendly_block"}
	return vehicle.apply_projectile_armor(event,direction,budget)

func _apply_projectile_damage(event: Dictionary, available_mm: float) -> Dictionary:
	if director == null or director.state.phase != "playing" or int(event.get("round_id",-1)) != get_round_id(): return {"ok":false,"reason":"match_not_playing"}
	var vehicle := find_actor(str(event.get("entity_id","")),int(event.get("life_id",0)))
	if vehicle == null or vehicle.state.destroyed or director.state.is_protected(vehicle.entity_id,vehicle.life_id): return {"ok":false,"reason":"target_unavailable"}
	var shooter := director.state.actor_for(str(event.get("shooter_id","")))
	if shooter != null and shooter.state.team_id == vehicle.state.team_id: return {"ok":false,"reason":"friendly_block"}
	return vehicle.apply_projectile_damage(event,available_mm)

func _start_playing() -> void:
	controller.reset_pending()
	controller.require_fire_release()
	controller.commands_enabled = true
	for vehicle in combat_actors(): vehicle.set_physics_process(true)

func _on_lost(id: String) -> void:
	var vehicle := director.state.actor_for(id)
	if vehicle == null: return
	vehicle.set_controller(null)
	vehicle.set_physics_process(false)
	vehicle.gunner.aim_preview_enabled = false
	vehicle.cam_rig.set_process(false)
	vehicle.cam_rig.set_physics_process(false)
	vehicle.turret.set_process(false)
	vehicle.tank.forward_speed = 0
	vehicle.tank.velocity = Vector3.ZERO
	# A previous player hull becomes ordinary visible cover in the next life's gunsight.
	for geometry in vehicle.find_children("*","GeometryInstance3D",true,false): geometry.layers = 4
	wrecks.register(vehicle)
	if id == "A" and not ai_only:
		controller.commands_enabled = false
		controller.reset_pending()
		spectator.current = true
		waiting_panel.visible = true
		if DisplayServer.get_name() != "headless": Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func request_respawn() -> void:
	if director.state.phase != "playing": return
	var row: Dictionary = director.state.roster.A
	if row.respawn_at >= 0 and director.state.elapsed >= row.respawn_at:
		if prepared_match != null:
			var chosen := str(vehicle_choice.get_item_metadata(vehicle_choice.selected))
			if chosen not in prepared_match.vehicle_ids(): return
			respawn_vehicle_id = chosen
		row.respawn_requested = true

func abandon_vehicle() -> void:
	if not team_ready or director.state.phase != "playing" or actor.state.destroyed: return
	if actor.state.destroy_once("abandoned_vehicle",{"round_id":get_round_id()}):
		actor._commit_death()
		actor._publish_death()
	if _paused: _resume()

func _finish_match(result: Dictionary) -> void:
	if telemetry != null:
		var evidence_path := TrafficTelemetry.match_evidence_path(int(director.state.match_id))
		if telemetry.write_evidence(evidence_path): print("TRAFFIC_EVIDENCE %s" % evidence_path)
	projectiles.close_round()
	wrecks.set_physics_process(false)
	for vehicle in combat_actors():
		vehicle.pause_block(true)
		vehicle.clear_commands()
		vehicle.set_physics_process(false)
		vehicle.turret.set_process(false)
		vehicle.freeze_wreck()
		vehicle.tank.forward_speed = 0
		vehicle.tank.velocity = Vector3.ZERO
	controller.commands_enabled = false
	controller.reset_pending()
	waiting_panel.visible = false
	result_panel.visible = true
	var explanation: String = {"victory":LocalizationService.text("ui_7357b726ae6b"),"defeat":LocalizationService.text("ui_cfe636d7d427"),"draw":LocalizationService.text("ui_759487f44034"),"abandoned":LocalizationService.text("ui_876d78e52e6b")}.get(result.outcome,"")
	if result.reason == "time_limit": explanation = LocalizationService.text("ui_8090ccc7d57b")
	result_text.text = LocalizationService.text("ui_fd213e8aecf4")%[{"victory":LocalizationService.text("ui_943874ecb6bd"),"defeat":LocalizationService.text("ui_bd5cdcb6f4f6"),"draw":LocalizationService.text("ui_eff519ae471f"),"abandoned":LocalizationService.text("ui_4be334f6b7c5")}.get(result.outcome,LocalizationService.text("ui_c7b24e7997e9")),result.seconds,result.tickets[1],result.tickets[2],result.shots,explanation]
	var summary: Dictionary = result.get("combat_summary",{})
	if not summary.is_empty():
		result_text.text += "\n\n"+LocalizationService.text("flow_combat_summary") % [summary.hits,summary.penetrations,summary.kills,summary.deaths,summary.capture_seconds]
		if not str(summary.last_death).is_empty(): result_text.text += "\n"+LocalizationService.text("flow_last_death")+LocalizationService.status(summary.last_death)
	result_body = result_text.text
	hud.show_pause(false)
	get_tree().paused = false
	_paused = false
	if DisplayServer.get_name() != "headless": Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func leave_match() -> void:
	if director.state.phase != "finished": director.finish_once("abandoned","player_returned")
	return_requested.emit(director.state.result.duplicate(true))

func _build_capture_ring() -> void:
	capture_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = TeamMatchState.CAPTURE_RADIUS-0.1
	torus.outer_radius = TeamMatchState.CAPTURE_RADIUS+0.1
	torus.rings = 64
	torus.ring_segments = 4
	capture_ring.mesh = torus
	capture_ring.position.y = 0.08
	capture_material = StandardMaterial3D.new()
	capture_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	capture_ring.material_override = capture_material
	add_child(capture_ring)
	CoreVehicleVisual.box(self,Vector3(0,2,0),Vector3(0.12,4,0.12),Color("d2d4b7"))
	var flag := Label3D.new()
	flag.text = LocalizationService.text("ui_912d8357ca25")
	flag.font = CoreUI.FONT
	flag.font_size = 60
	flag.position = Vector3(0,4.4,0)
	add_child(flag)

func _refresh_capture_markers(state: TeamMatchState) -> void:
	capture_material.albedo_color = {0:Color("c8c8a0"),1:Color("57b9e5"),2:Color("e79c68")}[state.capture_owner]

func _panel(size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	hud.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -size.x/2
	panel.offset_right = size.x/2
	panel.offset_top = -size.y/2
	panel.offset_bottom = size.y/2
	panel.visible = false
	return panel

func _build_ui() -> void:
	top_label = CoreUI.label(hud,"",22)
	top_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top_label.offset_left = -270
	top_label.offset_right = 270
	top_label.offset_top = 20
	top_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_label = CoreUI.label(hud,"",17)
	action_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	action_label.offset_left = -250
	action_label.offset_right = 250
	action_label.offset_top = -75
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	waiting_panel = _panel(Vector2(500,310))
	var waiting := VBoxContainer.new()
	waiting.add_theme_constant_override("separation",14)
	waiting_panel.add_child(waiting)
	waiting_label = CoreUI.label(waiting,LocalizationService.text("ui_ed28d4bf2bc2"),25)
	vehicle_choice = OptionButton.new()
	if prepared_match != null:
		for id in prepared_match.vehicle_ids():
			vehicle_choice.add_item(str(defs.content_packets[id].display_name))
			vehicle_choice.set_item_metadata(vehicle_choice.item_count-1,id)
			if id == selected_vehicle_id: vehicle_choice.select(vehicle_choice.item_count-1)
	elif selected_vehicle_id in VehicleCatalog.IDS:
		vehicle_choice.add_item(str(defs.content_packets[selected_vehicle_id].display_name))
	else: vehicle_choice.add_item(LocalizationService.text("ui_d6a3783e0e8f"))
	waiting.add_child(vehicle_choice)
	CoreUI.label(waiting,LocalizationService.text("ui_d5f1aabb1300"),16)
	respawn_button = CoreUI.button(waiting,LocalizationService.text("ui_32043d8fbb16"),request_respawn)
	CoreUI.button(waiting,LocalizationService.text("ui_6ea101bebe06"),leave_match)
	ModalNavigation.attach(waiting_panel)
	result_panel = _panel(Vector2(580,410))
	var result_box := VBoxContainer.new()
	result_box.add_theme_constant_override("separation",16)
	result_panel.add_child(result_box)
	var result_scroll := ScrollContainer.new()
	result_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	result_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	result_scroll.focus_mode = Control.FOCUS_ALL
	result_box.add_child(result_scroll)
	result_text = CoreUI.label(result_scroll,"",22)
	result_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation",16)
	result_box.add_child(buttons)
	restart_button = CoreUI.button(buttons,LocalizationService.text("ui_db04b4c1355c"),func() -> void: restart_requested.emit())
	return_button = CoreUI.button(buttons,LocalizationService.text("ui_6ea101bebe06"),leave_match)
	ModalNavigation.attach(result_panel)
	var abandon := CoreUI.button(hud._training_btn.get_parent(),LocalizationService.text("ui_19064416524b"),abandon_vehicle)
	abandon.tooltip_text = LocalizationService.text("ui_b4c2af5575cc")
	hud.resume_btn.text = LocalizationService.text("ui_7c9691192f1b")
	for control in hud.resume_btn.get_parent().get_children():
		if control is Label: control.text = LocalizationService.text("ui_eb0c326b60ae")
		if control is Button and control.text == LocalizationService.text("ui_48fbf5cf003e"): control.visible = false
	CoreUI.apply(hud)

func _reset_range() -> void: pass

func _unhandled_input(event: InputEvent) -> void:
	if not team_ready: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_R,KEY_X,KEY_1,KEY_2,KEY_3]:
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("scoreboard"):
			if actor.state.destroyed: spectator_index += 1
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE and director.state.phase == "finished": leave_match(); return
	if InputBindingService.is_pause(event):
		if _paused: _resume()
		else: _pause()

func _pause() -> void:
	if director != null and director.state.phase == "finished": return
	super._pause()
	for vehicle in combat_actors(): vehicle.pause_block(true)
func _resume() -> void:
	super._resume()
	for vehicle in combat_actors():
		vehicle.pause_block(false)
		vehicle.gunner.resume_grace = GameConfig.RESUME_GRACE
	if actor.state.destroyed and DisplayServer.get_name() != "headless": Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	super._process(delta)
	if not team_ready: return
	var state := director.state
	var owner_text: String = {0:LocalizationService.text("ui_518b1e77363c"),1:LocalizationService.text("ui_718d084817ca"),2:LocalizationService.text("ui_cce7e5e9eecb")}[state.capture_owner]
	top_label.text = LocalizationService.text("ui_bfa451c50895")%[state.tickets[1],state.tickets[2],owner_text,absf(state.capture_progress)*100,LocalizationService.text("ui_cc37c84eb3de") if state.contested else ""]
	if state.phase == "countdown": top_label.text += LocalizationService.text("ui_00799d20ed40")%ceili(state.countdown)
	hud.control_label.text = LocalizationService.text("ui_56b6b54bb00a")
	hud.hint_label.text = LocalizationService.text("ui_b26a9aa7b19e")
	hud.ammo_label.text = LocalizationService.text("ui_913b00faa6c4")%actor.gunner.rounds_remaining
	hud.projectiles_label.text = LocalizationService.text("ui_4cce74d3cbde")%projectiles.active_count()
	hud.gunline_label.text = LocalizationService.text("ui_7f0fba1b3b64")
	action_label.text = ""
	if state.is_protected(actor.entity_id,actor.life_id): action_label.text = LocalizationService.text("ui_167e0fd046f6")%state.roster.A.protection_left
	elif not actor.state.fires.is_empty(): action_label.text = LocalizationService.text("ui_0fac49793e34")%actor.state.extinguisher_charges
	elif not actor.capabilities().drive: action_label.text = LocalizationService.text("ui_f84d46746392")
	elif not actor.capabilities().fire: action_label.text = LocalizationService.text("ui_373d66b7d585")
	if not actor.state.recovery_action.is_empty(): action_label.text += LocalizationService.text("ui_b11e8dc2e1aa")%[CoreUI.word(actor.state.recovery_action),actor.state.action_progress]
	_refresh_capture_markers(state)
	for life in shield_visuals.keys():
		var entry: Dictionary = shield_visuals[life]
		var vehicle: VehicleActor = entry.actor.get_ref()
		if vehicle == null or not is_instance_valid(entry.mesh): shield_visuals.erase(life); continue
		entry.mesh.visible = not vehicle.state.destroyed and state.is_protected(vehicle.entity_id,vehicle.life_id)
	if actor.state.destroyed and state.phase == "playing":
		var row: Dictionary = state.roster.A
		var left := maxf(0,row.respawn_at-state.elapsed)
		waiting_label.text = LocalizationService.text("ui_c954af1bb479")%left if left>0 else (LocalizationService.text("ui_03b03144e7fd") if row.waiting_reason == "spawn_blocked" else LocalizationService.text("ui_af7467336cea"))
		respawn_button.disabled = left>0 or state.tickets[1]<=0
		var friends: Array = []
		for id in state.roster:
			var friend := state.actor_for(id)
			if friend != null and friend.state.team_id == 1 and not friend.state.destroyed: friends.append(friend)
		if not friends.is_empty():
			var observed: VehicleActor = friends[spectator_index%friends.size()]
			spectator.global_position = observed.tank.global_position+Vector3(0,7,12)
			spectator.look_at(observed.tank.global_position+Vector3.UP)

func input_context() -> String: return "battle"
