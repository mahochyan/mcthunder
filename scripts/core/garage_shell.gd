class_name GarageShell
extends Control
signal training_requested(loadout: Dictionary, case_index: int)
signal laboratory_requested(id: String)
signal challenge_requested(id: String, difficulty: String)
signal quit_requested
signal tutorial_requested(chapter: int)
signal progress_reset
var challenge_button: Button
var challenge_selection: ChallengeSelection
var shell_choice: OptionButton
var rounds: SpinBox
var infinite: CheckBox
var case_choice: OptionButton
var start_button: Button
var inspect_button: Button
var error_label: Label
var preview: VehiclePreviewModel
var result_label: Label
var _view_mode := 0
var initial_loadout := {"vehicle_id":"test_vehicle","shell_id":"ap120","rounds":10,"infinite":false}
var initial_case := 0
var initial_vehicle_id := "player_tank"
var vehicle_choice: OptionButton
var catalog := VehicleCatalog.new()
var historical_defs := VehicleDefs.new()
var preview_note: Label
var preview_camera: Camera3D
var dossier_button: Button
var profile: ProfileStore
var preparation: GaragePreparation
var inspection_row: HBoxContainer
var inspection_choice: OptionButton
var inspection_value: Label

func _open_challenges() -> void:
	if is_instance_valid(challenge_selection): return
	challenge_selection = ChallengeSelection.new(); challenge_selection.profile = profile
	add_child(challenge_selection)
	challenge_selection.chosen.connect(func(id: String, difficulty: String) -> void: challenge_requested.emit(id,difficulty))

func _ready() -> void:
	if profile == null: profile = ProfileStore.new()
	catalog = profile.service.catalog
	historical_defs = profile.service.definitions
	theme = CoreUI.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("10191f")
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,24)
	var vertical := VBoxContainer.new()
	vertical.add_theme_constant_override("separation",12)
	margin.add_child(vertical)
	CoreUI.label(vertical,LocalizationService.text("ui_92f3a3e04627"),30)
	var toolbar := HBoxContainer.new(); vertical.add_child(toolbar)
	var settings_button := CoreUI.button(toolbar,LocalizationService.text("ui_eb9bb060c217"),func() -> void:
		var panel := InputSettingsPanel.new()
		panel.profile = profile
		panel.progress_reset.connect(func() -> void: progress_reset.emit())
		add_child(panel))
	settings_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	CoreUI.button(toolbar,"模型展厅 / Models",func() -> void:
		if get_node_or_null("ModelShowroom") == null: add_child(ModelShowroom.new()))
	CoreUI.button(toolbar,LocalizationService.text("menu_credits"),_show_credits)
	CoreUI.button(toolbar,LocalizationService.text("menu_quit"),func() -> void:
		AppDialog.show(self,LocalizationService.text("menu_quit"),LocalizationService.text("menu_quit_body"),LocalizationService.text("menu_quit_confirm"),func() -> void: quit_requested.emit()))
	CoreUI.label(vertical,LocalizationService.text("menu_version") % ProjectSettings.get_setting("application/config/version"),15)
	var tutorial_row := HBoxContainer.new(); vertical.add_child(tutorial_row)
	var checkpoint: Dictionary = profile.snapshot().tutorial if profile != null else {"chapter":0,"completed":[]}
	var resume := CoreUI.button(tutorial_row,LocalizationService.text("tutorial_resume") % [checkpoint.completed.size(),TutorialCatalog.COUNT],func() -> void: tutorial_requested.emit(mini(int(checkpoint.chapter),TutorialCatalog.COUNT-1)))
	resume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var chapters := OptionButton.new(); chapters.name = "TutorialChapters"; tutorial_row.add_child(chapters)
	for chapter in TutorialCatalog.COUNT: chapters.add_item("%d. %s" % [chapter+1,TutorialCatalog.title(chapter)])
	chapters.select(mini(int(checkpoint.chapter),TutorialCatalog.COUNT-1))
	CoreUI.button(tutorial_row,LocalizationService.text("tutorial_review"),func() -> void: tutorial_requested.emit(chapters.selected))
	CoreUI.button(tutorial_row,LocalizationService.text("tutorial_reset"),func() -> void:
		AppDialog.show(self,LocalizationService.text("tutorial_reset"),LocalizationService.text("tutorial_reset_body"),LocalizationService.text("tutorial_reset"),func() -> void:
			var next := profile.snapshot(); next.tutorial = {"chapter":0,"completed":[]}
			var saved := profile.commit(next)
			if saved.ok: resume.text = LocalizationService.text("tutorial_resume") % [0,TutorialCatalog.COUNT]; chapters.select(0); checkpoint.chapter=0; checkpoint.completed=[]
			else: error_label.text = saved.reason))
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation",24)
	vertical.add_child(columns)
	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size.x = 360
	columns.add_child(left_panel)
	var left_column := VBoxContainer.new()
	left_panel.add_child(left_column)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_column.add_child(scroll)
	var controls := VBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_theme_constant_override("separation",8)
	scroll.add_child(controls)
	CoreUI.label(controls,LocalizationService.text("ui_6f53fa2da6bd"),24)
	vehicle_choice = OptionButton.new()
	vehicle_choice.clip_text = true
	vehicle_choice.fit_to_longest_item = false
	vehicle_choice.add_item(LocalizationService.text("ui_5b2b85fb2264"))
	vehicle_choice.set_item_metadata(0,"player_tank")
	var admitted := {"ok":profile.service.ready,"errors":[]}
	for rejected in catalog.rejected.values(): admitted.errors.append_array(rejected.errors)
	var vehicle_ids := profile.service.vehicle_ids()
	for id in vehicle_ids:
		vehicle_choice.add_item(profile.service.vehicle_label(id))
		var index := vehicle_choice.item_count-1
		vehicle_choice.set_item_metadata(index,id)
		if id == initial_vehicle_id: vehicle_choice.select(index)
	controls.add_child(vehicle_choice)
	vehicle_choice.item_selected.connect(_select_vehicle)
	dossier_button = CoreUI.button(controls,LocalizationService.text("ui_3291552243b5"),_show_dossier)
	preparation = GaragePreparation.new(); controls.add_child(preparation)
	preparation.setup(self,profile)
	CoreUI.label(controls,LocalizationService.text("ui_3d45d76aac43"),16)
	shell_choice = OptionButton.new()
	shell_choice.add_item("AP70 · 70 mm")
	shell_choice.add_item("AP120 · 120 mm")
	shell_choice.select(0 if initial_loadout.shell_id == "ap70" else 1)
	controls.add_child(shell_choice)
	var ammo_row := HBoxContainer.new()
	controls.add_child(ammo_row)
	CoreUI.label(ammo_row,LocalizationService.text("ui_c18e41a7ea02"),16)
	rounds = SpinBox.new()
	rounds.min_value = 1
	rounds.max_value = 30
	rounds.value = initial_loadout.rounds
	ammo_row.add_child(rounds)
	infinite = CheckBox.new()
	infinite.text = LocalizationService.text("ui_f9ae85491761")
	infinite.button_pressed = initial_loadout.infinite
	controls.add_child(infinite)
	CoreUI.label(controls,LocalizationService.text("ui_356c28d4b95e"),16)
	case_choice = OptionButton.new()
	for title in TrainingDirector.TITLES: case_choice.add_item(title)
	case_choice.select(initial_case)
	controls.add_child(case_choice)
	var goal := CoreUI.label(controls,TrainingDirector.GOALS[initial_case],15)
	goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal.custom_minimum_size = Vector2(300,58)
	case_choice.item_selected.connect(func(index: int) -> void: goal.text = TrainingDirector.GOALS[index])
	start_button = CoreUI.button(left_column,LocalizationService.text("ui_e9229f452d99"),_start)
	CoreUI.button(controls,LocalizationService.text("ui_99b3769b6ee2"),func() -> void: laboratory_requested.emit("duel"))
	CoreUI.button(left_column,LocalizationService.text("ui_56b6b54bb00a"),func() -> void: laboratory_requested.emit("team"))
	challenge_button = CoreUI.button(left_column,LocalizationService.text("ui_21b701f1a8ae"),_open_challenges)
	error_label = CoreUI.label(controls,"",14)
	if not admitted.ok: error_label.text = LocalizationService.text("ui_9f0466b8a9c8")+", ".join(admitted.errors)
	error_label.modulate = Color("ffc282")
	CoreUI.label(controls,LocalizationService.text("ui_fcc47a11cdcd"),16)
	var labs := HBoxContainer.new()
	controls.add_child(labs)
	for item in [["armor",LocalizationService.text("ui_a7efe890de54")],["ballistics",LocalizationService.text("ui_f7799e469b10")],["recovery",LocalizationService.text("ui_e0534b8a4e46")],["terrain",LocalizationService.text("ui_51695ad45a11")]]:
		CoreUI.button(labs,item[1],func() -> void: laboratory_requested.emit(item[0]))
	CoreUI.button(controls,LocalizationService.text("ui_c0c91a16fecf"),func() -> void: laboratory_requested.emit("ai_drive"))
	CoreUI.button(controls,LocalizationService.text("ui_ff13698c8992"),func() -> void: laboratory_requested.emit("ai_combat"))
	CoreUI.button(controls,LocalizationService.text("ui_fdd1a39b2a3d"),func() -> void: laboratory_requested.emit("shells"))
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	var cards := HFlowContainer.new(); right.add_child(cards)
	for i in vehicle_ids.size():
		var card := CoreUI.button(cards,profile.service.vehicle_label(vehicle_ids[i]),func() -> void: vehicle_choice.select(i+1); _select_vehicle(i+1))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var viewport_container := SubViewportContainer.new()
	viewport_container.stretch = true
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_container.custom_minimum_size = Vector2(350,220)
	right.add_child(viewport_container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(760,400)
	viewport.own_world_3d = true
	viewport_container.add_child(viewport)
	preview = VehiclePreviewModel.new()
	viewport.add_child(preview)
	var layout := M4EngineeringProfile.layout()
	for patch in layout.armor_patches:
		if patch.id == "hull_front": patch.thickness_mm = 240
	preview.setup(layout)
	_apply_preview_mode()
	for extra in preview._extra_nodes.duplicate():
		if not extra.name.begins_with("Wire_"):
			preview._extra_nodes.erase(extra)
			extra.queue_free()
	M4LowPolyDetails.build(preview._part_nodes.hull,preview._part_nodes.turret,preview._part_nodes.barrel,1)
	_collect_preview_extras(preview)
	var camera := Camera3D.new()
	preview_camera = camera
	camera.fov = 38
	camera.position = Vector3(5.3,3.8,-6.4)
	viewport.add_child(camera)
	camera.look_at(Vector3(0,1.2,0))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40,-25,0)
	sun.light_energy = 1.8
	viewport.add_child(sun)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("25363b")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("aab9b1")
	environment.environment.ambient_light_energy = 0.8
	viewport.add_child(environment)
	CoreVehicleVisual.box(preview,Vector3(0,-0.06,0),Vector3(7,0.1,7),Color("40514c"))
	var view_controls := HBoxContainer.new()
	right.add_child(view_controls)
	CoreUI.button(view_controls,LocalizationService.text("ui_0cea635232f9"),func() -> void: preview.rotation.y -= PI/4)
	inspect_button = CoreUI.button(view_controls,LocalizationService.text("ui_2580d354c914"),_inspect)
	inspect_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	CoreUI.button(view_controls,LocalizationService.text("ui_12cd012a934f"),func() -> void: preview.rotation.y += PI/4)
	inspection_row = HBoxContainer.new(); right.add_child(inspection_row)
	inspection_choice = OptionButton.new(); inspection_choice.custom_minimum_size.x = 250
	inspection_choice.clip_text = true; inspection_choice.fit_to_longest_item = false
	inspection_row.add_child(inspection_choice)
	inspection_value = CoreUI.label(inspection_row,"",14)
	inspection_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspection_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspection_choice.item_selected.connect(_select_inspection)
	preview_note = CoreUI.label(right,"",15)
	preview_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label = CoreUI.label(right,LocalizationService.text("ui_c42121535102"),16)
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	CoreUI.label(vertical,LocalizationService.text("ui_c2d8db90e0eb"),15)
	_select_vehicle(vehicle_choice.selected)
	ModalNavigation.attach(self)

func _show_credits() -> void:
	var rules := "\n\n"+LocalizationService.text("menu_rules")+"\n"+GameConfig.ARMOR_RULES_VERSION+"\n"+GameConfig.DAMAGE_RULES_VERSION+"\n"+RecoveryRules.VERSION
	var body := LocalizationService.text("menu_credits_body")+rules
	body += "\n\nNoto Sans CJK SC — SIL Open Font License 1.1\n"+FileAccess.get_file_as_string("res://assets/fonts/OFL.txt")
	body += "\n\nGodot Engine\n"+Engine.get_license_text()
	AppDialog.show(self,LocalizationService.text("menu_credits"),body)

func build_loadout() -> Dictionary:
	return TrainingLoadout.validate({"vehicle_id":"test_vehicle","shell_id":"ap70" if shell_choice.selected == 0 else "ap120","rounds":int(rounds.value),"infinite":infinite.button_pressed})

func _start() -> void:
	if profile.service.has_vehicle(selected_vehicle_id()):
		laboratory_requested.emit("historical")
		return
	var value := build_loadout()
	if not value.ok: error_label.text = value.reason
	else: training_requested.emit(value.loadout,case_choice.selected)

func _inspect() -> void:
	_view_mode = (_view_mode+1)%3
	_apply_preview_mode()
	inspect_button.text = LocalizationService.text("ui_660648805666")+[LocalizationService.text("ui_86a63f23a076"),LocalizationService.text("ui_c0b8220b85c7"),LocalizationService.text("ui_b37ff83d968b")][_view_mode]+LocalizationService.text("ui_b0d87e0bb40b")

func _apply_preview_mode() -> void:
	preview.set_mode(["appearance","armor","interior"][_view_mode])
	for id in preview._patch_nodes:
		var mesh: MeshInstance3D = preview._patch_nodes[id]
		if _view_mode == 0: mesh.material_override.albedo_color = ArtPalette.color("olive")
		else: preview._restore_patch_color(mesh,id)
	if preparation != null: preparation.apply_rack_preview()
	_refresh_inspection()

func _refresh_inspection() -> void:
	if inspection_row == null: return
	inspection_row.visible = _view_mode != 0
	inspection_choice.clear()
	if _view_mode == 1:
		for patch in preview.layout.armor_patches:
			inspection_choice.add_item(_patch_label(patch)+" · "+str(inspection_choice.item_count+1))
			inspection_choice.set_item_metadata(inspection_choice.item_count-1,{"kind":"patch","id":patch.id})
	elif _view_mode == 2:
		for module in preview.layout.modules:
			inspection_choice.add_item(CoreUI.word(module.id))
			inspection_choice.set_item_metadata(inspection_choice.item_count-1,{"kind":"module","id":module.id})
		for station in preview.layout.crew_stations:
			inspection_choice.add_item(LocalizationService.text("ui_1495f29977e4")+CoreUI.word(station.id))
			inspection_choice.set_item_metadata(inspection_choice.item_count-1,{"kind":"crew","id":station.id})
	if inspection_choice.item_count > 0: _select_inspection(0)

func _select_inspection(index: int) -> void:
	if index < 0 or index >= inspection_choice.item_count: return
	var entry: Dictionary = inspection_choice.get_item_metadata(index)
	preview.select_module(""); preview.select_crew(""); preview.select_patch("")
	if entry.kind == "patch":
		preview.select_patch(entry.id)
		for patch in preview.layout.armor_patches:
			if patch.id == entry.id:
				inspection_value.text = LocalizationService.text("ui_e1fbe9145803")%[patch.thickness_mm,_evidence_word(patch.thickness_status),_evidence_word(patch.geometry_status)] if patch.has_thickness else LocalizationService.text("ui_5e8bb1906e1f")+_evidence_word(patch.geometry_status)
	elif entry.kind == "module":
		preview.select_module(entry.id)
		for module in preview.layout.modules:
			if module.id == entry.id: inspection_value.text = CoreUI.word(module.kind)+LocalizationService.text("ui_7a954e969839")+_evidence_word(module.geometry_status)
		if profile.service.has_vehicle(preparation.current_id):
			var checked := profile.service.build_loadout(preparation.loadouts[preparation.current_id])
			if checked.ok and checked.inventory.racks.has(entry.id): inspection_value.text += LocalizationService.text("ui_cf4bdbed893a")%checked.inventory.racks[entry.id]
	else:
		preview.select_crew(entry.id)
		inspection_value.text = LocalizationService.text("ui_560aa91f650c")
	preparation.apply_rack_preview()

func _evidence_word(value: String) -> String:
	return {"verified":LocalizationService.text("ui_b340063020e8"),"estimated":LocalizationService.text("ui_c58140e6cf83"),"unknown":LocalizationService.text("ui_4d8c1c5b4283")}.get(value,value)

func _patch_label(patch: ArmorPatchDefinition) -> String:
	var zones := {"hull_front_upper":LocalizationService.text("ui_a975c2bbfbb2"),"hull_front_lower":LocalizationService.text("ui_fdafc1ea7a60"),"hull_sides_front":LocalizationService.text("ui_f7761d7be028"),"hull_sides_rear":LocalizationService.text("ui_fac83f914eb7"),"hull_sides_lower":LocalizationService.text("ui_37a4ed647f46"),"hull_sides_lower_rear":LocalizationService.text("ui_9e82f34cf759"),"hull_rear_upper":LocalizationService.text("ui_35c3c1935288"),"hull_rear_lower":LocalizationService.text("ui_83ea31d22714"),"hull_roof_front":LocalizationService.text("ui_5fdaf3b2c3fd"),"hull_roof_rear":LocalizationService.text("ui_eafc7fde10e2"),"hull_floor_front":LocalizationService.text("ui_6dcd42477b3f"),"hull_floor_rear":LocalizationService.text("ui_d7b5d1597f8c"),"turret_front":LocalizationService.text("ui_2085f9e261dd"),"turret_sides":LocalizationService.text("ui_cb5f50600899"),"turret_rear":LocalizationService.text("ui_da9c27321e3c"),"turret_roof":LocalizationService.text("ui_9ad75fc4abfb"),"gun_shield":LocalizationService.text("ui_1ae02361da58"),"gun_tube":LocalizationService.text("ui_72c396fb3557")}
	var title: String = zones.get(patch.plate_group_id,CoreUI.word(patch.id))
	if "side" in patch.plate_group_id: title = (LocalizationService.text("ui_843fd39e3226") if patch.outward_normal_local.x<0 else LocalizationService.text("ui_1687ade07b67"))+title
	return title

func _collect_preview_extras(node: Node) -> void:
	for child in node.get_children():
		if child.is_queued_for_deletion(): continue
		if child is GeometryInstance3D and child.name.begins_with("Cosmetic"): preview._extra_nodes.append(child)
		_collect_preview_extras(child)

func selected_vehicle_id() -> String:
	return str(vehicle_choice.get_item_metadata(vehicle_choice.selected))

func _select_vehicle(_index: int) -> void:
	if preview == null or preview_note == null: return
	var id := selected_vehicle_id()
	var historical := profile.service.has_vehicle(id)
	shell_choice.disabled = historical
	rounds.editable = not historical; infinite.disabled = historical; case_choice.disabled = historical
	dossier_button.disabled = not historical
	start_button.text = LocalizationService.text("ui_720202c64f34") if historical else LocalizationService.text("ui_e9229f452d99")
	var layout: VehicleLayoutDefinition = catalog.packages[id].layout if historical else M4EngineeringProfile.layout()
	preview.setup(layout)
	for extra in preview._extra_nodes.duplicate():
		if not extra.name.begins_with("Wire_"):
			preview._extra_nodes.erase(extra); extra.queue_free()
	if historical:
		var packet: Dictionary = catalog.packages[id].packet
		var reference: bool = packet.get("evidence_profile","historical_verified")=="game_reference"
		if reference: start_button.text="驾驶所选参考车辆"
		if shell_choice.item_count < 3: shell_choice.add_item("")
		shell_choice.set_item_text(2,str(packet.assembly.shell)+" · "+str(packet.assembly.caliber_mm)+" mm")
		shell_choice.select(2)
		rounds.max_value = 150; rounds.value = packet.runtime.rounds
		HistoricalVehicleModel.build_details(preview._part_nodes.hull,preview._part_nodes.turret,preview._part_nodes.barrel,packet,1)
		preview_note.text = LocalizationService.text("ui_299e3fe8604d")%[packet.display_name,packet.assembly.shell,packet.runtime.rounds,packet.runtime.forward_max_speed*3.6]
		if reference: preview_note.text="%s\n%s · %d 发 · %.1f km/h 参考／设计速度\n游戏参考与工程估计，未做历史核验。"%[packet.display_name,packet.assembly.shell,packet.runtime.rounds,packet.runtime.forward_max_speed*3.6]
		var ammo := VehicleShellCatalog.build(packet)
		if ammo.ok:
			var names := PackedStringArray()
			for option in ammo.options: names.append(option.display_name)
			preview_note.text += "\n可用弹种："+" / ".join(names)
			preview_note.text += "\n默认全部携带此弹种。" if ammo.options.size()==1 else "\n默认主弹70%，其余弹种合计30%；可在备战中调整。"
			if not reference and id.begins_with("us_m24"): preview_note.text += LocalizationService.text("ui_7ec5dcfbc36a")
		var extent: float = maxf(float(HistoricalEvidenceGate.value(packet,"dimensions.reference_length_m")),float(packet.geometry.barrel_length)+3.5)
		preview_camera.position = Vector3(5.3,3.8,-6.4)*extent/6.0
	else:
		if shell_choice.item_count > 2: shell_choice.remove_item(2)
		shell_choice.select(0 if initial_loadout.shell_id == "ap70" else 1)
		rounds.max_value = 30; rounds.value = initial_loadout.rounds
		M4LowPolyDetails.build(preview._part_nodes.hull,preview._part_nodes.turret,preview._part_nodes.barrel,1)
		preview_note.text = LocalizationService.text("ui_96ad5ffe2ca2")
		preview_camera.position = Vector3(5.3,3.8,-6.4)
	preview_camera.look_at(Vector3(0,1.2,0))
	_collect_preview_extras(preview)
	preparation.select_vehicle(id)
	_apply_preview_mode()

func _show_dossier() -> void:
	var id := selected_vehicle_id()
	if not catalog.packages.has(id): return
	var packet: Dictionary = catalog.packages[id].packet
	var overlay := PanelContainer.new()
	var solid := StyleBoxFlat.new(); solid.bg_color = Color("17252d"); solid.set_content_margin_all(16)
	overlay.add_theme_stylebox_override("panel",solid)
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","top"]: overlay.set("offset_"+side,30)
	for side in ["right","bottom"]: overlay.set("offset_"+side,-30)
	var box := VBoxContainer.new(); overlay.add_child(box)
	CoreUI.label(box,packet.display_name+LocalizationService.text("ui_5d7d4009ab4d"),23)
	var view := RichTextLabel.new()
	view.bbcode_enabled = true; view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.selection_enabled = true; box.add_child(view)
	var reference: bool = packet.get("evidence_profile","historical_verified")=="game_reference"
	view.append_text("游戏参考／工程估计；未做历史核验。\n" if reference else LocalizationService.text("ui_286db738c052"))
	var ammunition := VehicleShellCatalog.build(packet)
	if ammunition.ok:
		view.append_text("\n[b]当前参考弹种[/b]\n" if reference else LocalizationService.text("ui_0f251c001808"))
		for entry in ammunition.entries:
			view.append_text("\n[b]"+str(entry.label)+"[/b] · "+str(entry.gun)+"\n")
			if not entry.get("fuze_policy", {}).is_empty():
				view.add_text("穿过足够厚的装甲后延迟起爆，出车后仍有效。当前为游戏设计规则；历史引信数值未知。\n")
			if not entry.get("post_penetration_profile",{}).is_empty():
				view.add_text("穿甲后按剩余预算分配定向破片，母弹继续飞行；破片受装甲、内构和掩体阻挡。当前为游戏设计规则。\n")
			if not entry.get("chemical_profile",{}).is_empty():
				view.add_text("HEAT首次接触后弹体结束飞行，独立射流按有限路径、装甲和内构消耗预算；不按弹体飞行距离衰减。当前为游戏设计规则。\n")
			if not entry.get("impact_profile", {}).is_empty():
				if entry.impact_profile.get("family")=="HEAT":
					view.add_text("射流使用独立化学防护系数与实际斜向厚度，不套用动能弹法线化和口径碾压。\n")
				elif entry.impact_profile.get("family")=="APFSDS":
					view.add_text("长杆弹按独立角度曲线与装甲材质结算；炮口口径不作为弹芯直径。当前为游戏设计规则。\n")
				else:
					view.add_text("命中结果结合装甲材质、入射角与弹径／板厚；当前响应参数为独立游戏设计值。\n")
			if reference:
				view.add_text(str(entry.muzzle_velocity_mps)+" m/s · estimated\n"+JSON.stringify(entry.penetration_curve)+" · estimated\n")
				for claim in entry.evidence.values():
					view.add_text(str(claim.origin)+" / "+str(claim.status)+"\n"+str(claim.location)+"\n"+str(claim.note)+"\n")
					for ref in claim.source_refs:
						var source: Dictionary=ammunition.sources[ref]
						view.add_text(str(source.artifact)+"\nSHA256 "+str(source.sha256)+"\n")
				continue
			view.add_text(LocalizationService.text("ui_51a92c8c7d53")+str(entry.muzzle_velocity_mps)+" m/s · "+str(entry.muzzle_velocity_status)+"\n")
			view.add_text(LocalizationService.text("ui_9a5d1dcbcbb9")+JSON.stringify(entry.penetration_curve)+" · estimated\n"+str(entry.estimate_reason)+"\n"+str(entry.historical_observations)+"\n")
			for ref in entry.source_refs:
				var source: Dictionary = ammunition.sources[ref]
				view.append_text("[url="+str(source.url)+"]"+str(source.title)+"[/url]\n")
				view.add_text(str(source.location)+"\nSHA256 "+str(source.sha256)+"\n")
		view.append_text("\n[b]车型包字段来源与估计[/b]\n" if reference else LocalizationService.text("ui_0c1302ad4a39"))
	for limitation in packet.get("limitations",[]): view.add_text(str(limitation)+"\n")
	for field in packet.facts:
		var row: Dictionary = packet.facts[field]
		view.append_text("\n[b]"+field+"[/b]  ·  "+str(row.status)+" / "+str(row.origin)+"\n")
		view.add_text(JSON.stringify(row.value)+"\n"+str(row.get("location",""))+"\n"+str(row.get("note",""))+"\n")
		for ref in row.get("source_refs",[]):
			var source: Dictionary = packet.sources[ref]
			var url := str(source.get("url",""))
			if url.begins_with("https://"): view.append_text("[url="+url+"]"+str(ref)+"[/url]\n")
			view.add_text("SHA256: "+str(source.get("sha256","local implementation"))+"\n")
	view.meta_clicked.connect(func(link: Variant) -> void:
		if str(link).begins_with("https://"): OS.shell_open(str(link)))
	CoreUI.button(box,LocalizationService.text("ui_9b1bf5d60f70"),overlay.queue_free)
	ModalNavigation.attach(overlay,overlay.queue_free)
