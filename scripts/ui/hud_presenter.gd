class_name HUDPresenter
extends RefCounted
## Read-only adapter. No combat clocks, damage resolution or enemy state enters this view model.
static var REASONS := {"engine":LocalizationService.text("ui_9df15869823f"),"transmission":LocalizationService.text("ui_896027ecfe58"),"track_left":LocalizationService.text("ui_fc5984f7b699"),"track_right":LocalizationService.text("ui_2bb45236fd65"),"breech":LocalizationService.text("ui_d99b56e78b9d"),"turret_drive":LocalizationService.text("ui_7b5c7359facb"),"driver":LocalizationService.text("ui_73b377788db6"),"gunner":LocalizationService.text("ui_569eb328ff48"),"cooldown":LocalizationService.text("ui_a3e842959775"),"grace":LocalizationService.text("ui_25f29cdadd6e"),"barrel_occluded":LocalizationService.text("ui_fb6fc87ce2d5"),"no_ammo":LocalizationService.text("ui_19122c16e8c1"),"chamber_empty":LocalizationService.text("ui_609f061f5455"),"vehicle_disabled":LocalizationService.text("ui_b636adf12053"),"paused":LocalizationService.text("ui_eb0c326b60ae"),"projectile_capacity":LocalizationService.text("ui_2e8591da52c2"),"manager_shutdown":LocalizationService.text("ui_3c03903fbcd6"),"invalid_shell":LocalizationService.text("ui_248e31a58b2b"),"invalid_spawn":LocalizationService.text("ui_858bdcc34e60")}
static var RECOVERY := {"not_on_fire":LocalizationService.text("ui_24c0a4f151d7"),"no_extinguishers":LocalizationService.text("ui_e0dd0811114a"),"cannot_repair_on_fire":LocalizationService.text("ui_e037ba61fff4"),"stop_to_repair":LocalizationService.text("ui_85971dca1413"),"nothing_to_repair":LocalizationService.text("ui_8c698299cca5"),"no_valid_replacement":LocalizationService.text("ui_bfc04978a32f"),"repair_interrupted_fire":LocalizationService.text("ui_d8163239b96e"),"repair_interrupted_motion_or_fire":LocalizationService.text("ui_bc2432f4a699"),"module_repaired":LocalizationService.text("ui_c07e7ebd9007"),"fire_extinguished":LocalizationService.text("ui_8108ab671c86"),"crew_replaced":LocalizationService.text("ui_f44b610d039e"),"replacement_cancelled":LocalizationService.text("ui_bdf0e676f94c"),"cancelled":LocalizationService.text("ui_176ead7baf1a"),"vehicle_destroyed":LocalizationService.text("ui_aaeb6d850849")}

static func reason(value: String) -> String: return REASONS.get(value,LocalizationService.text("ui_e0d07fde57bb"))
static var MECHANISM_REASONS := {
	"turret_horizontal_drive":LocalizationService.text("turret_horizontal_drive_disabled"),
	"turret_vertical_drive":LocalizationService.text("turret_vertical_drive_disabled"),
	"stabilizer":LocalizationService.text("stabilizer_disabled")
}
static func recovery_reason(value: String) -> String:
	if value == "cannot_repair_on_fire": return LocalizationService.text("ui_06e38b03bc8c")+InputBindingService.hint("extinguish")+LocalizationService.text("ui_8dc96c377cc2")
	if value == "stop_to_repair": return LocalizationService.text("ui_1aee287f279c")+InputBindingService.hint("repair")
	return RECOVERY.get(value,"")
static func present(vehicle: VehicleActor, match_info: Dictionary, protection: float = 0) -> Dictionary:
	if not is_instance_valid(vehicle): return {}
	var state := vehicle.state
	var gun := vehicle.gunner
	var caps := vehicle.capabilities()
	var modules: Array[Dictionary] = []
	var drive: Array[String] = []
	var weapon: Array[String] = []
	for id in state.module_states:
		var m: Dictionary = state.module_states[id]
		var fraction := float(m.integrity)/maxf(1,float(m.max_integrity))
		var condition := LocalizationService.text("ui_b0272ae322c9") if fraction <= 0 else (LocalizationService.text("ui_cefe31e5adf3") if fraction < 1 else LocalizationService.text("ui_955d487fd519"))
		modules.append({"id":id,"name":CoreUI.word(id),"status":condition,"fraction":fraction})
		if fraction > 0: continue
		if m.kind in ["engine","transmission","track"]: drive.append(REASONS.get(id,CoreUI.word(id)+LocalizationService.text("ui_b0272ae322c9")))
		if m.kind in ["breech","turret_drive"]: weapon.append(REASONS.get(id,CoreUI.word(id)+LocalizationService.text("ui_b0272ae322c9")))
		elif MECHANISM_REASONS.has(m.kind): weapon.append(MECHANISM_REASONS[m.kind])
	if not state.role_available("driver"): drive.append(REASONS.driver)
	if caps.get("track_pivot",false): drive.append(LocalizationService.text("drive_single_track_pivot"))
	if not state.role_available("gunner"): weapon.append(REASONS.gunner)
	if not state.role_available("loader"): weapon.append(LocalizationService.text("ui_f8a03ec8abed"))
	var crew: Array[Dictionary] = []
	for role in state.crew_assignments:
		crew.append({"role":role,"name":CoreUI.word(role),"available":state.role_available(role)})
	var ready: bool = caps.fire and gun.cooldown_left <= 0 and gun.inventory.chamber > 0 and gun.resume_grace <= 0 and not state.destroyed
	var gun_text := LocalizationService.text("ui_491169f99fb7")
	if state.destroyed: gun_text = LocalizationService.text("ui_aaeb6d850849")
	elif not caps.fire: gun_text = LocalizationService.text("ui_99d18b371d7d")
	elif gun.rounds_remaining <= 0: gun_text = LocalizationService.text("ui_c15ff473042d")
	elif gun.cooldown_left > 0: gun_text = LocalizationService.text("ui_779427f939dd")%gun.cooldown_left
	elif gun.inventory.chamber <= 0: gun_text = LocalizationService.text("ui_609f061f5455")
	elif gun.resume_grace > 0: gun_text = LocalizationService.text("ui_73f95a191364")%gun.resume_grace
	var duration := float({"repair":RecoveryRules.REPAIR_SECONDS,"extinguish":RecoveryRules.EXTINGUISH_SECONDS,"replace":RecoveryRules.REPLACEMENT_SECONDS}.get(state.recovery_action,0))
	var action := ""
	if duration > 0:
		action = LocalizationService.text("ui_e677b693fb2f")%[CoreUI.word(state.recovery_action)," "+CoreUI.word(state.action_target) if not state.action_target.is_empty() else "",state.action_progress,duration]
	var feedback := ""
	if gun.last_shot_result.begins_with("blocked:"): feedback = LocalizationService.text("ui_bc8f0b6e77bb")+reason(gun.blocked_reason)
	var shell_text := "AP120" if gun.shell.id.contains("120") else ("AP70" if gun.shell.id.contains("70") else gun.shell.id.to_upper())
	if gun.inventory.typed: shell_text = gun.shell_label(gun.inventory.chamber_shell)
	return {"life_id":vehicle.life_id,"entity_id":vehicle.entity_id,"destroyed":state.destroyed,"speed_kph":vehicle.tank.forward_speed*3.6,"crew_alive":state.alive_crew_count(),"crew":crew,"modules":modules,"drive_reasons":drive,"weapon_reasons":weapon,"drive_text":" · ".join(drive),"weapon_text":" · ".join(weapon),"ready":ready,"weapon_status":gun_text,"cooldown":gun.cooldown_left,"reload_time":gun.weapon.reload_time,"ammo":gun.rounds_remaining,"chamber":gun.inventory.chamber,"shell":shell_text,"extinguishers":state.extinguisher_charges,"fire":not state.fires.is_empty(),"action":action,"action_progress":state.action_progress,"action_duration":duration,"recovery_feedback":recovery_reason(state.recovery_reason),"shot_feedback":feedback,"protection":protection,"match":match_info.duplicate(true),"actual_point":gun.actual_hit_point,"intent_point":vehicle.cam_rig.intent_point(),"aim_error_degrees":vehicle.turret.alignment_error_deg(),"observing":vehicle.cam_rig.is_observing(),"optics_text":vehicle.cam_rig.optics_text()}
