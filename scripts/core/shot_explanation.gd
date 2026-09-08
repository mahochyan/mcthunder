class_name ShotExplanation
extends RefCounted

static func describe(record: Dictionary, target: VehicleActor) -> String:
	var lines: Array[String] = []
	if record.contacts.is_empty():
		lines.append("直接命中外露部件，未经过装甲。" if not record.damage.is_empty() else "未命中目标；落点来自实际弹道。")
	for contact in record.contacts:
		lines.append("%s：%s（入射 %.1f°）" % [CoreUI.word(str(contact.get("surface_id",""))),CoreUI.word(str(contact.result)),contact.get("angle_deg",0)])
		lines.append("穿深预算 %.1f → %.1f mm；等效厚度 %.1f mm" % [contact.before_mm,contact.after_mm,contact.get("effective_mm",0)])
		if lines.size() >= 4: break
	for damage in record.damage:
		lines.append("%s：%s" % [CoreUI.word(str(damage.item_id)),CoreUI.word(str(damage.reason))])
	if record.damage.is_empty(): lines.append("没有实际内部损伤，不能仅凭命中判定击毁。")
	if is_instance_valid(target):
		var caps := target.capabilities()
		lines.append("目标：%s / %s / %s" % ["已阵亡" if target.state.destroyed else "存活","可驾驶" if caps.drive else "无法驾驶","可射击" if caps.fire else "无法射击"])
	return "\n".join(lines)
