class_name ShotExplanation
extends RefCounted

static func describe(record: Dictionary, target: VehicleActor) -> String:
	var lines: Array[String] = []
	if record.contacts.is_empty():
		lines.append(LocalizationService.text("ui_05df6d3bd66d") if not record.damage.is_empty() else LocalizationService.text("ui_befafc79e6cd"))
	for contact in record.contacts:
		lines.append(LocalizationService.text("ui_69a87e390eea") % [CoreUI.word(str(contact.get("surface_id",""))),CoreUI.word(str(contact.result)),contact.get("angle_deg",0)])
		if contact.result=="unknown_material":
			lines.append(LocalizationService.text("armor_unknown_material_detail"))
		elif contact.get("budget_unit","")==ArmorImpactProfile.UNIT:
			lines.append(LocalizationService.text("armor_game_budget_detail") % [contact.before_mm,contact.after_mm,contact.get("effective_mm",0),contact.get("path_thickness_mm",0)])
		else:
			lines.append(LocalizationService.text("ui_47f51be2e1cb") % [contact.before_mm,contact.after_mm,contact.get("effective_mm",0)])
		if lines.size() >= 4: break
	for damage in record.damage:
		lines.append("%s：%s" % [CoreUI.word(str(damage.item_id)),CoreUI.word(str(damage.reason))])
		if damage.has("ammo_event"):
			var loss := int(damage.ammo_event.after.lost)-int(damage.ammo_event.before.lost)
			lines.append(LocalizationService.text("ammo_compartment_replay_loss") % loss)
	if record.damage.is_empty(): lines.append(LocalizationService.text("ui_e0243783d60b"))
	if is_instance_valid(target):
		var caps := target.capabilities()
		lines.append(LocalizationService.text("ui_e11b049239a1") % [LocalizationService.text("ui_26a7584f13af") if target.state.destroyed else LocalizationService.text("ui_b994669232e7"),LocalizationService.text("ui_ba3def82979b") if caps.drive else LocalizationService.text("ui_399cbc80e9c7"),LocalizationService.text("ui_53301767ccab") if caps.fire else LocalizationService.text("ui_e6b8c85d1a18")])
	return "\n".join(lines)
