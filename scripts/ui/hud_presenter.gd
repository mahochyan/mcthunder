class_name HUDPresenter
extends RefCounted
## Read-only adapter. No combat clocks, damage resolution or enemy state enters this view model.
const REASONS := {"engine":"发动机损毁","transmission":"传动损毁","track_left":"左履带损毁","track_right":"右履带损毁","breech":"炮闩损毁","turret_drive":"炮塔驱动损毁","driver":"驾驶员失能","gunner":"炮手失能","cooldown":"尚在装填","grace":"恢复操作宽限","barrel_occluded":"炮管被障碍物挡住","no_ammo":"弹药已耗尽","chamber_empty":"膛内无弹","vehicle_disabled":"火炮或乘员失能","paused":"已暂停","projectile_capacity":"当前炮弹数量已达上限","manager_shutdown":"对局已结束","invalid_shell":"弹药配置不可用","invalid_spawn":"无法从当前炮口发射"}
const RECOVERY := {"not_on_fire":"车辆没有起火","no_extinguishers":"灭火器已用尽","cannot_repair_on_fire":"请先按 F 灭火，再停车维修","stop_to_repair":"松开驾驶键并停车后按 T","nothing_to_repair":"没有需要维修的部件","no_valid_replacement":"没有可用的替补乘员","repair_interrupted_fire":"起火中断维修","repair_interrupted_motion_or_fire":"驾驶动作中断维修","module_repaired":"部件已修复至可用状态","fire_extinguished":"火势已扑灭","crew_replaced":"乘员已完成替补","replacement_cancelled":"替补已取消","cancelled":"已取消动作","vehicle_destroyed":"车辆已阵亡"}

static func reason(value: String) -> String: return REASONS.get(value,"发射暂不可用")
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
		var condition := "损毁" if fraction <= 0 else ("受损" if fraction < 1 else "完好")
		modules.append({"id":id,"name":CoreUI.word(id),"status":condition,"fraction":fraction})
		if fraction > 0: continue
		if m.kind in ["engine","transmission","track"]: drive.append(REASONS.get(id,CoreUI.word(id)+"损毁"))
		if m.kind in ["breech","turret_drive"]: weapon.append(REASONS.get(id,CoreUI.word(id)+"损毁"))
	if not state.role_available("driver"): drive.append(REASONS.driver)
	if not state.role_available("gunner"): weapon.append(REASONS.gunner)
	if not state.role_available("loader"): weapon.append("装填手失能 · 装填减慢")
	var crew: Array[Dictionary] = []
	for role in state.crew_assignments:
		crew.append({"role":role,"name":CoreUI.word(role),"available":state.role_available(role)})
	var ready: bool = caps.fire and gun.cooldown_left <= 0 and gun.inventory.chamber > 0 and gun.resume_grace <= 0 and not state.destroyed
	var gun_text := "可开火"
	if state.destroyed: gun_text = "车辆已阵亡"
	elif not caps.fire: gun_text = "火炮失能"
	elif gun.rounds_remaining <= 0: gun_text = "弹药耗尽"
	elif gun.cooldown_left > 0: gun_text = "装填 %.1f 秒"%gun.cooldown_left
	elif gun.inventory.chamber <= 0: gun_text = "膛内无弹"
	elif gun.resume_grace > 0: gun_text = "恢复操作 %.1f 秒"%gun.resume_grace
	var duration := float({"repair":RecoveryRules.REPAIR_SECONDS,"extinguish":RecoveryRules.EXTINGUISH_SECONDS,"replace":RecoveryRules.REPLACEMENT_SECONDS}.get(state.recovery_action,0))
	var action := ""
	if duration > 0:
		action = "%s%s · %.1f / %.0f 秒"%[CoreUI.word(state.recovery_action)," "+CoreUI.word(state.action_target) if not state.action_target.is_empty() else "",state.action_progress,duration]
	var feedback := ""
	if gun.last_shot_result.begins_with("blocked:"): feedback = "上次发射未执行："+reason(gun.blocked_reason)
	var shell_text := "AP120" if gun.shell.id.contains("120") else ("AP70" if gun.shell.id.contains("70") else gun.shell.id.to_upper())
	if gun.inventory.typed: shell_text = gun.shell_label(gun.inventory.chamber_shell)
	return {"life_id":vehicle.life_id,"entity_id":vehicle.entity_id,"destroyed":state.destroyed,"speed_kph":vehicle.tank.forward_speed*3.6,"crew_alive":state.alive_crew_count(),"crew":crew,"modules":modules,"drive_reasons":drive,"weapon_reasons":weapon,"drive_text":" · ".join(drive),"weapon_text":" · ".join(weapon),"ready":ready,"weapon_status":gun_text,"cooldown":gun.cooldown_left,"reload_time":gun.weapon.reload_time,"ammo":gun.rounds_remaining,"chamber":gun.inventory.chamber,"shell":shell_text,"extinguishers":state.extinguisher_charges,"fire":not state.fires.is_empty(),"action":action,"action_progress":state.action_progress,"action_duration":duration,"recovery_feedback":RECOVERY.get(state.recovery_reason,""),"shot_feedback":feedback,"protection":protection,"match":match_info.duplicate(true),"actual_point":gun.actual_hit_point}
