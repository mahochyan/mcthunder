class_name VehicleActor
extends Node3D
## 003：车辆实体容器——统一生成/销毁/本地控制者设置。
## 拥有：共享定义（VehicleDefinition/WeaponDefinition/ShellDefinition）、
## 独立 VehicleRuntimeState、TankVehicle（驾驶）、TurretRig（瞄准）、
## CameraRig（观察）、Gunner（射击）、可选 PlayerController（本地控制者）。
## 003-R2：submit_command 是唯一命令提交入口（验证/复制/暂存，不执行）；
## 每步消费一次；团队由世界调度阶段调用，独立场景由本车物理回调调用同一执行器。

static var _life_counter := 0   # 003-R2：实体生命周期计数（同名车销毁重建后新旧区分）

var definition: VehicleDefinition
var weapon: WeaponDefinition
var shell: ShellDefinition
var state: VehicleRuntimeState
var damage_layout_override: VehicleLayoutDefinition
var model_binding_installed := false
signal damage_recorded(record: Dictionary)
signal vehicle_disabled(record: Dictionary)
signal vehicle_destroyed(record: Dictionary)
signal recovery_recorded(record: Dictionary)
var last_recovery_record: Dictionary = {}
var _recovery_sequence := 0
var entity_id := ""   # 003-R1：实体标识（HUD 提示/命中事件来源）
var life_id := 0      # 003-R2：实体生命周期标识（setup 生成；同 id 重建后不同）
var tank: TankVehicle
var turret: TurretRig
var cam_rig: CameraRig
var gunner: Gunner
var controller: Node = null   # PlayerController（本地控制者）或 null（零命令静止）
var label3d: Label3D
var wreck_turret: WreckTurretMotion
var _mailbox := CommandMailbox.new()   # 003-R2：命令暂存
var debug_command_trace := false       # 003-R2：提交/消费/执行三处调试记录（默认关）
## WT-039-R1: read-only observability. A hull that sits still while its controller reports
## throttle 0.31 cannot currently be told apart from a command that never reached it, because
## debug_command_trace prints nothing on the standalone path; these fields record what the actor
## actually consumed and whether the controller's submission was accepted.
var last_consumed_throttle := 0.0
var last_consumed_steer := 0.0
var last_submit_accepted := false
var command_observer := Callable() # Match rules may cancel spawn protection before an actual command executes.
var supply_motion_active := false
var control_epoch := 0
var _last_input_sequence := -1
var _pending_input_tick := -1
var simulation_driver: WeakRef
var presentation_enabled := true
var fire_control := FireControlState.new()
var last_consumed_sequence := -1
var _staged_sequence := -1

func _expire_pending_input() -> void:
	if _pending_input_tick>=0 and Engine.get_physics_frames()-_pending_input_tick>GameConfig.COMMAND_MAX_AGE_TICKS:
		_mailbox.clear()
		_pending_input_tick = -1
		_staged_sequence = -1

func invalidate_input_epoch() -> void:
	control_epoch += 1
	_last_input_sequence = -1
	_pending_input_tick = -1
	_mailbox.clear()
	_staged_sequence=-1; last_consumed_sequence=-1
	fire_control.cancel_measurement("input_reset")
	if is_instance_valid(turret) and is_instance_valid(turret.barrel_pivot):
		turret.mechanism.hold(Vector2(turret.barrel_pivot.rotation.x,turret.rotation.y),turret.get_parent().global_basis)

func submit_command_envelope(value: Variant) -> Dictionary:
	if state == null or not is_inside_tree(): return {"ok":false,"reason":"actor_unavailable"}
	var parsed := VehicleCommandCodec.decode(value)
	if not parsed.ok: return parsed
	if state.destroyed or value.entity_id!=entity_id or int(value.life_id)!=life_id or int(value.generation)!=state.generation or int(value.control_epoch)!=control_epoch:
		return {"ok":false,"reason":"stale_identity"}
	if int(value.sequence)<=_last_input_sequence: return {"ok":false,"reason":"stale_sequence"}
	var age := Engine.get_physics_frames()-int(value.input_tick)
	if age<0 or age>GameConfig.COMMAND_MAX_AGE_TICKS: return {"ok":false,"reason":"invalid_input_tick"}
	_expire_pending_input()
	if not submit_command(parsed.command): return {"ok":false,"reason":"command_rejected"}
	_pending_input_tick = int(value.input_tick) if _pending_input_tick<0 else mini(_pending_input_tick,int(value.input_tick))
	_last_input_sequence = int(value.sequence)
	_staged_sequence = _last_input_sequence
	return {"ok":true,"accepted_tick":Engine.get_physics_frames(),"sequence":_last_input_sequence}
var _consume_count := 0                # 003-R2：本步消费计数（调试用）

func setup(defs: VehicleDefs, vehicle_id: String, entity_id: String, team_id: int, spawn: Transform3D, visual_layer: int, ctrl: Node) -> Dictionary:
	# 返回 {ok, errors}；定义引用解析失败 → 明确报错并定位字段；
	# 003-R1：校验失败受控停止——不继续生成半有效实体（调用方负责释放本节点）
	var res := defs.resolve_vehicle(vehicle_id)
	if not res.ok:
		return res
	definition = res.vehicle
	weapon = res.weapon
	shell = res.shell
	_life_counter += 1
	life_id = _life_counter   # 003-R2：同名车重建后生命周期不同
	state = VehicleRuntimeState.new()
	state.entity_id = entity_id
	state.life_id = life_id
	state.team_id = team_id
	state.definition_id = definition.id
	if not definition.layout_id.is_empty():
		var initial_layout: VehicleLayoutDefinition = res.layout if res.has("layout") else LayoutCatalog.load_layout(definition.layout_id)
		state.initialize_damage(initial_layout)
		if res.has("layout"): damage_layout_override = initial_layout
	self.entity_id = entity_id   # 003-R1：实体标识（HUD 提示/命中事件来源）
	controller = ctrl
	transform = spawn
	var ps: PackedScene = load("res://scenes/tank.tscn")
	tank = ps.instantiate()
	tank.presentation_enabled = presentation_enabled
	tank.name = "Tank"
	tank.visual_layer = visual_layer
	tank.defs = definition   # 003-R1：驾驶参数唯一来源
	add_child(tank)
	tank.position = Vector3.ZERO   # 003：位置由 actor.transform 统一管理（tank.tscn 根自带偏移清零）
	tank.set_spawn(tank.transform)   # 003：局部出生点（世界位置 = actor 全局变换）
	turret = tank.turret_rig
	cam_rig = tank.camera_rig
	cam_rig.fire_control=fire_control
	turret.cam_rig = cam_rig if presentation_enabled else null
	turret.defs = definition   # 003-R1：炮塔转速/俯仰限位唯一来源
	cam_rig.turret = turret
	cam_rig.tank = tank
	cam_rig.configure_weapon(weapon)
	cam_rig.visual_layer = visual_layer
	cam_rig.snapshot_provider = Callable(self,"_aim_snapshots")
	gunner = Gunner.new()
	gunner.name = "Gunner"
	add_child(gunner)
	gunner.setup(tank, turret, weapon, shell)   # 003-R1：装填/射程唯一来源；006：弹种运动参数
	gunner.vehicle_definition_id = definition.id
	_configure_inventory(state._damage_layout)
	gunner.shooter_id = entity_id   # 003-R1：命中事件携带射手标识
	tank.capabilities_provider = Callable(self,"capabilities")
	tank.state_generation = state.generation
	turret.capabilities_provider = Callable(self,"capabilities")
	gunner.capabilities_provider = Callable(self,"capabilities")
	gunner.shooter_team_id = team_id   # 006：发射身份队伍（冻结）
	tank.entity_id = entity_id   # 003-R2：命中事件 target 身份来源
	tank.life_id = life_id       # 003-R2：目标生命周期标识
	process_mode = Node.PROCESS_MODE_PAUSABLE   # 003：暂停时整实体（驱动/武器）冻结
	tank.process_mode = Node.PROCESS_MODE_PAUSABLE
	process_physics_priority = SimulationPhases.VEHICLES
	gunner.process_mode = Node.PROCESS_MODE_PAUSABLE
	set_controller(ctrl)   # 003-R1：统一控制者绑定入口（含相机 current 管理）
	# 003：A/PLAYER 与 B/TEST TARGET 明确标识（不改共享配置伪造实例状态）
	# 003-R1：提示来自实际状态（控制者绑定是实际状态，不是写死的标签文字）
	label3d = Label3D.new()
	label3d.font = CoreUI.FONT
	label3d.text = entity_id + (LocalizationService.text("ui_4c6d3932b74f") if controller != null else LocalizationService.text("ui_0631c4adcd74"))
	label3d.position = Vector3(0, 2.7, 0)
	label3d.font_size = 48
	label3d.outline_size = 10
	label3d.modulate = Color(0.4, 1.0, 0.4) if controller != null else Color(1.0, 0.85, 0.3)
	tank.add_child(label3d)
	if res.has("packet"):
		var model_result := HistoricalVehicleModel.apply(self,res.packet,res.layout,res.get("model_source",{}))
		if not model_result.ok:
			set_controller(null); tank.set_physics_process(false); set_physics_process(false)
			return model_result
		model_binding_installed=res.packet.has("model_binding")
	if res.has("packet") and definition.content_tier == "production":
		var shell_result := VehicleShellCatalog.install(self,res.packet)
		if not shell_result.ok: return shell_result
		if OS.get_cmdline_user_args().has("--geometry-overlay"): GeometryOverlay.attach(self)
	return {"ok": true}

func set_controller(ctrl: Node) -> void:
	invalidate_input_epoch()
	fire_control.reset()
	# 003-R1：统一控制者绑定/解绑——解绑清理引用；只有被控制的车拥有有效本地游戏相机
	# 003-R2：控制者变更时清空暂存（不跨绑定继承旧请求）
	_mailbox.clear()
	if controller != null:
		if controller != ctrl and controller.has_method("on_detached"): controller.on_detached()
		controller.cam_rig = null
		controller.gunner = null
	controller = ctrl
	if controller != null:
		controller.cam_rig = cam_rig
		controller.gunner = gunner
		cam_rig.set_local_control(not controller.has_method("is_local_controller") or controller.is_local_controller())
	else:
		cam_rig.set_local_control(false)

func capabilities() -> Dictionary:
	return VehicleCapabilities.compute(state,definition.loading_profile if definition!=null else null)

func _aim_snapshots() -> Array:
	if gunner != null and gunner.shell != null and gunner.shell.armor_policy == "resolve" and gunner.snapshot_provider.is_valid():
		return gunner.snapshot_provider.call()
	return []

func set_damage_layout(layout: VehicleLayoutDefinition) -> void:
	invalidate_input_epoch()
	damage_layout_override = layout
	state.initialize_damage(layout)
	tank.state_generation = state.generation
	_configure_inventory(layout)

func _configure_inventory(layout: VehicleLayoutDefinition) -> void:
	if gunner == null: return
	var rack_ids: Array = []
	var capacities := {}
	if layout != null:
		for module in layout.modules:
			if module.kind == "ammo":
				rack_ids.append(module.id)
				if module.ammo_capacity > 0: capacities[module.id] = module.ammo_capacity
	gunner.inventory.configure(gunner.rounds_remaining,rack_ids,capacities)
	if not gunner.initial_shell_counts.is_empty():
		gunner.configure_shell_loadout(gunner.shell_options,gunner.initial_shell_counts,gunner.initial_shell_id)

func apply_projectile_armor(event: Dictionary, direction: Vector3, budget: Dictionary) -> Dictionary:
	if event.get("entity_id")!=entity_id or event.get("life_id")!=life_id or event.get("target_generation")!=state.generation:
		return {"ok":false,"reason":"stale_armor_target"}
	if state.destroyed: return {"ok":false,"reason":"target_destroyed"}
	var id := str(event.get("surface_id",""))
	var event_id := str(event.get("event_id",""))
	if not state.reactive_armor.has(id) or event_id.is_empty() or state._armor_seen.has(event_id): return {"ok":false,"reason":"invalid_or_duplicate_armor"}
	var patch: ArmorPatchDefinition
	for item in state._damage_layout.armor_patches:
		if item.id==id and item.part_id==event.get("part_id"): patch=item; break
	if patch==null or patch.reactive_profile!=event.get("reactive_profile") or patch.response_profile!=event.get("response_profile",{}) or patch.material_kind!=event.get("material_kind") or patch.thickness_mm!=event.get("thickness_mm") or patch.has_thickness!=event.get("has_thickness") or patch.thickness_status!=event.get("thickness_status"):
		return {"ok":false,"reason":"stale_armor_geometry"}
	var actual := event.duplicate(true); actual.reactive_before=int(state.reactive_armor[id])
	var result := ArmorResolver.resolve(actual,direction,budget)
	if result.get("reactive_triggered",false): state.reactive_armor[id]=int(result.reactive_after)
	state._armor_seen[event_id]=true
	if state._armor_seen.size()>256: state._armor_seen.erase(state._armor_seen.keys()[0])
	VehicleArmorLayers.refresh_reactive_visuals(self)
	return {"ok":true,"result":result,"reactive_before":actual.reactive_before}

func apply_projectile_damage(event: Dictionary, available_mm: float) -> Dictionary:
	if str(event.get("entity_id","")) != entity_id or int(event.get("life_id",0)) != life_id:
		return {"ok":false,"reason":"stale_entity"}
	if int(event.get("target_generation",-1)) >= 0 and int(event.target_generation) != state.generation:
		return {"ok":false,"reason":"stale_generation"}
	var snapshot := state.damage_snapshot()
	# CD01-T01 / CombatQuerySnapshotV2.ammo_contents: a logical ammunition volume whose stored rounds are exhausted
	# must not take part in the ammunition phase, while fixed structures keep their own rules. The occupancy is read
	# from the real inventory here; when a rack is absent from the map the resolver keeps its previous behaviour
	# instead of assuming an empty rack, because unknown is not zero.
	if gunner != null:
		var contents := {}
		for rack_id in gunner.inventory.racks: contents[rack_id] = int(gunner.inventory.racks[rack_id])
		snapshot["ammo_contents"] = contents
	var delta := DamageResolver.resolve(event,available_mm,snapshot)
	if not delta.get("ok",false):
		return delta
	delta["source"] = VehicleRecovery.source_from(event)
	var commit := state.apply_damage_delta(str(event.get("event_id","")),delta)
	if not commit.get("ok",false):
		return commit
	var record := event.duplicate(true)
	record.merge(delta,true)
	var secondary_death := VehicleRecovery.on_direct_damage(state,gunner.inventory,record)
	if record.has("ammo_event"): delta["ammo_event"]=record.ammo_event.duplicate(true)
	delta["newly_destroyed"] = commit.newly_destroyed or secondary_death
	delta["state_generation"] = state.generation
	if delta.newly_destroyed:
		_commit_death()
		delta["death_record"] = state.death_record.duplicate(true)
	return delta # No external callbacks until manager has committed projectile budget and record.

func present_damage_record(record: Dictionary) -> void:
	var generation := state.generation
	damage_recorded.emit(record.duplicate(true))
	if state.generation == generation and int(record.get("state_generation",generation)) == generation and record.get("newly_destroyed",false):
		_publish_death()

func _commit_death() -> void:
	fire_control.reset()
	state.death_record["point_world"] = tank.global_position
	state.death_record["ammo_before_loss"] = gunner.inventory.snapshot()
	if state.death_record.get("cause","")=="ammo_detonation" and (definition.id in VehicleCatalog.IDS or model_binding_installed) and not is_instance_valid(wreck_turret):
		wreck_turret=WreckTurretMotion.new(); add_child(wreck_turret); wreck_turret.launch(self)
		state.death_record["turret_detached"]=true
	gunner.inventory.lose_all()
	_mailbox.clear()
	if controller != null: controller.reset_pending()

func _publish_death() -> void:
	if not state.destroyed or state.death_notified: return
	state.death_notified = true
	var record := state.death_record.duplicate(true)
	vehicle_destroyed.emit(record.duplicate(true))
	if state.generation == int(record.generation) and state.destroyed:
		vehicle_disabled.emit(record.duplicate(true))

func _notification(what: int) -> void:
	# 003-R2：暂停瞬间清空暂存——恢复时不补执行上一轮待发请求（自动兜底；
	# 暂停/重置/解绑路径另有显式清理，见 pause_block/clear_commands）
	if what == NOTIFICATION_PAUSED:
		_mailbox.clear()
		_staged_sequence=-1
		fire_control.cancel_measurement("input_reset")

func pause_block(value: bool) -> void:
	invalidate_input_epoch()
	# 003-R2：暂停/恢复等状态切换的显式清理入口（main._pause/_resume 调用）——
	# 不指望已停止物理回调的 actor 自己清掉暂存
	_mailbox.set_blocked(value)

func clear_commands() -> void:
	invalidate_input_epoch()
	# 003-R2：重开/解绑路径显式清空暂存
	_mailbox.clear()

func _exit_tree() -> void:
	# 003-R1：销毁后引用清理（控制者不再指向已释放组件）
	if controller != null:
		if controller.has_method("on_detached"): controller.on_detached()
		controller.cam_rig = null
		controller.gunner = null

func submit_command(cmd: VehicleCommand) -> bool:
	# 003-R2：唯一命令提交入口——验证/复制/暂存，不移动、不射击。
	# 玩家输入与脚本命令走同一入口；执行由本车唯一的 _physics_process 完成。
	# 返回 false = 本步命令被拒绝（暂停/实体无效/无效瞄点）。
	if not is_inside_tree() or get_tree().paused:
		_mailbox.clear()   # 暂停拒绝并清空（恢复不补执行）
		return false
	if not is_instance_valid(tank) or not is_instance_valid(gunner) or not is_instance_valid(turret):
		return false
	if cmd != null and cmd.has_aim_point:
		var p := cmd.aim_world_point
		if not (is_finite(p.x) and is_finite(p.y) and is_finite(p.z)):
			return false   # 无效瞄点整条拒绝（NaN/INF 不得进入瞄准）
	var ok := _mailbox.submit(cmd)
	last_submit_accepted = ok
	if ok and debug_command_trace and cmd != null:
		print("[cmd-trace] submit entity=%s throttle=%.2f fire=%s" % [entity_id, cmd.throttle, str(cmd.fire_requested)])
	return ok

func _physics_process(delta: float) -> void:
	if simulation_driver != null and is_instance_valid(simulation_driver.get_ref()): return
	advance_standalone_tick(delta)

func advance_standalone_tick(delta: float) -> void:
	_apply_command_once(collect_simulation_command(delta),delta)

func collect_simulation_command(_delta: float) -> VehicleCommand:
	# Expire the oldest merged input before a fresh controller poll can merge
	# an old fire edge into a new driving sample.
	# 003-R2：每辆车唯一物理执行器——有控制者先经同一提交入口收集本步命令，
	_expire_pending_input()
	# 然后消费恰好一次（无输入 = 零命令静止）；脚本不再传入 delta 决定运动时间。
	_consume_count = 0
	if controller != null:
		var before_generation := state.generation
		var before_epoch := control_epoch
		var bound_controller := controller
		var next_command: VehicleCommand = controller.poll()
		if not is_instance_valid(self): return VehicleCommand.new()
		if state.generation == before_generation and control_epoch == before_epoch and controller == bound_controller and not state.destroyed:
			if next_command != null:
				submit_command_envelope(VehicleCommandCodec.encode(next_command,self,_last_input_sequence+1,Engine.get_physics_frames()))
	var cmd := _mailbox.consume()
	last_consumed_throttle = cmd.throttle if cmd != null else 0.0
	last_consumed_steer = cmd.steer if cmd != null else 0.0
	if _staged_sequence>=0: last_consumed_sequence=_staged_sequence
	_staged_sequence=-1
	_pending_input_tick = -1
	_consume_count += 1
	if debug_command_trace:
		print("[cmd-trace] consume entity=%s tick=%d throttle=%.2f fire=%s" % [entity_id, Engine.get_physics_frames(), cmd.throttle, str(cmd.fire_requested)])
	return cmd

func _apply_command_once(cmd: VehicleCommand, delta: float) -> void:
	var step := begin_simulation_command(cmd,delta)
	if step.is_empty(): return
	advance_simulation_drive(step,delta)
	advance_simulation_loading(step,delta)
	advance_simulation_aim(step,delta)
	advance_simulation_mechanism(step,delta)
	finish_simulation_command(step)

func simulation_step_valid(step: Dictionary) -> bool:
	return not step.is_empty() and is_inside_tree() and not get_tree().paused and state.generation==step.generation and control_epoch==step.epoch

func begin_simulation_command(cmd: VehicleCommand, delta: float) -> Dictionary:
	# 003-R2：命令执行体（由原 apply_command 改名而来；驾驶/瞄准算法不变）。
	# 003-R1：入口合法性约束——实体无效拒绝、有限值、输入范围钳制
	if not is_instance_valid(tank) or not is_instance_valid(gunner) or not is_instance_valid(turret):
		return {}
	if command_observer.is_valid():
		var before_generation := state.generation
		var before_epoch := control_epoch
		command_observer.call(self,cmd)
		if not is_instance_valid(self) or state.generation != before_generation or control_epoch != before_epoch or state.destroyed or get_tree().paused: return {}
	var throttle := clampf(cmd.throttle if is_finite(cmd.throttle) else 0.0, -1.0, 1.0)
	var steer := clampf(cmd.steer if is_finite(cmd.steer) else 0.0, -1.0, 1.0)
	supply_motion_active = absf(throttle)>0.01 or absf(steer)>0.01
	var repair_target := state.action_target if state.recovery_action == "repair" else ""
	var repair_before := float(state.module_states.get(repair_target,{}).get("integrity",0.0))
	var died_now := VehicleRecovery.step(state,delta,tank.forward_speed,cmd)
	var completed_repair := not repair_target.is_empty() and not state.destroyed and state.recovery_action.is_empty() and state.recovery_reason == "module_repaired" and float(state.module_states[repair_target].integrity) > repair_before
	if died_now: _commit_death()
	if debug_command_trace:
		print("[cmd-trace] execute entity=%s tick=%d throttle=%.2f steer=%.2f fire=%s" % [entity_id, Engine.get_physics_frames(), throttle, steer, str(cmd.fire_requested)])
	return {"cmd":cmd,"generation":state.generation,"epoch":control_epoch,"throttle":throttle,"steer":steer,"died_now":died_now,"completed_repair":completed_repair,"repair_target":repair_target,"repair_before":repair_before}

func advance_simulation_drive(step: Dictionary, delta: float) -> void:
	if not simulation_step_valid(step): return
	tank.apply_drive(step.throttle,step.steer,delta)

func advance_simulation_loading(step: Dictionary, delta: float) -> void:
	if not simulation_step_valid(step): return
	# Recovery and actual movement commit first. Complete the current chamber
	# before solving this tick's sight trajectory so a new shell uses its own speed.
	gunner.advance_timers(delta)

func advance_simulation_aim(step: Dictionary, delta: float) -> void:
	if not simulation_step_valid(step): return
	var cmd: VehicleCommand = step.cmd
	turret.observation_hold=cmd.hold_aim
	if cmd.aim_intent.active:
		cam_rig.apply_aim_intent(cmd.aim_intent)
	turret.observation_hold=cmd.hold_aim or cam_rig.is_observing()
	if cmd.has_aim_point:
		turret.set_aim_point(cmd.aim_world_point)
	elif cmd.clear_aim:
		turret.clear_aim_point()
	if not cmd.aim_intent.active: cam_rig.set_sight_requested(cmd.aim_held)
	if cmd.clear_aim or cmd.aim_intent.active: cam_rig.refresh_intent()
	fire_control.advance(self,cmd,delta)
	if cmd.aim_intent.active and not turret.observation_hold:
		turret.set_aim_point(cam_rig.intent_point())
		var solution := fire_control.aim_solution(self)
		if solution.get("ok",false):
			# A direction target at the pivot preserves the solved muzzle direction;
			# finite mechanism motion and the actual weapon remain authoritative.
			turret.set_aim_point(turret.barrel_pivot.global_position+solution.direction*maxf(100,fire_control.zeroing_m))

func advance_simulation_mechanism(step: Dictionary, delta: float) -> void:
	if not simulation_step_valid(step): return
	# Drive and aim intent are committed before the mechanism, then firing reads
	# this tick's actual barrel transform. Rendering cannot advance these axes.
	turret.advance_mechanism(delta)

func finish_simulation_command(step: Dictionary) -> void:
	if not simulation_step_valid(step): return
	var cmd: VehicleCommand = step.cmd
	if cmd.select_shell >= 0 and not state.destroyed: gunner.select_shell(cmd.select_shell)
	elif cmd.cycle_shell_requested and not state.destroyed and not gunner.shell_options.is_empty():
		# Relative selection is resolved here, never against a client replica's
		# possibly delayed inventory. Explicit numbered selection wins a merged tick.
		var selected_index := -1
		for index in gunner.shell_options.size():
			if gunner.shell_options[index].id == gunner.inventory.selected_shell:
				selected_index = index
				break
		gunner.select_shell((selected_index + 1) % gunner.shell_options.size())
	if cmd.fire_requested and not cam_rig.binoculars:
		# A controller may veto its own shot against the completed movement,
		# chamber and mechanism state. Weapon admission remains in Gunner.
		var permitted := true
		if is_instance_valid(controller) and controller.has_method("authorize_fire"):
			permitted = controller.call("authorize_fire",cmd) == true
			if not simulation_step_valid(step): return
		if permitted: gunner.request_fire()
	# 状态同步：真实状态来源（HUD/试射目标只读，不另算一套显示用结果）
	state.forward_speed = tank.forward_speed
	state.turret_yaw = turret.global_rotation.y
	state.gun_pitch = turret.barrel_pivot.rotation.x
	state.cooldown_left = gunner.cooldown_left
	state.resume_grace = gunner.resume_grace
	state.shots_fired = gunner.shots_fired
	state.last_shot_result = gunner.last_shot_result
	state.hits_taken = tank.hits_taken
	if step.died_now: _publish_death()
	if step.completed_repair and simulation_step_valid(step):
		var repair_target: String = step.repair_target
		_recovery_sequence += 1
		last_recovery_record = {"event_id":"%s:%d:%d:repair:%d"%[entity_id,life_id,state.generation,_recovery_sequence],"entity_id":entity_id,"life_id":life_id,"generation":state.generation,"kind":"repair","item_id":repair_target,"before":step.repair_before,"after":float(state.module_states[repair_target].integrity)}
		last_recovery_record.make_read_only()
		recovery_recorded.emit(last_recovery_record.duplicate(true))

func reset_vehicle() -> void:
	invalidate_input_epoch()
	fire_control.reset()
	last_recovery_record = {}
	if is_instance_valid(wreck_turret): wreck_turret.restore()
	wreck_turret=null
	# 003：单车重置——不污染其他车/靶场/试射目标
	# 003-R1：清理旧瞄点/待发命令/炮镜请求/瞬时状态
	# 003-R2：重置清空暂存（不跨回合执行旧请求）
	_mailbox.clear()
	tank.reset()
	cam_rig.reset_optics()
	cam_rig.aim_yaw = 0.0
	cam_rig.aim_pitch = 0.0
	cam_rig.set_sight_requested(false)
	cam_rig.clear_intent_cache()
	turret.clear_aim_point()   # 先清旧瞄点再 snap（否则 snap 会追旧脚本目标）
	turret.snap_to_aim()
	gunner.reset_state()
	_configure_inventory(state._damage_layout)
	turret.reset_state()
	if controller != null and controller.has_method("reset_pending"):
		controller.reset_pending()
	state.reset()
	tank.state_generation = state.generation
	VehicleArmorLayers.refresh_reactive_visuals(self)

func freeze_wreck() -> void:
	if is_instance_valid(wreck_turret): wreck_turret.freeze()
