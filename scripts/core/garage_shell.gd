class_name GarageShell
extends Control
signal training_requested(loadout: Dictionary, case_index: int)
signal laboratory_requested(id: String)
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

func _ready() -> void:
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
	CoreUI.label(vertical,"MCTHUNDER   /   低多边形装甲",30)
	CoreUI.label(vertical,"车库候选 0.2.2  ·  编成、配弹与轻量研发  ·  几何与部分模拟参数仍为估算",15)
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
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_column.add_child(scroll)
	var controls := VBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_theme_constant_override("separation",8)
	scroll.add_child(controls)
	CoreUI.label(controls,"战前准备",24)
	vehicle_choice = OptionButton.new()
	vehicle_choice.clip_text = true
	vehicle_choice.fit_to_longest_item = false
	vehicle_choice.add_item("M4A3 外形工程样车 · 训练设计值")
	vehicle_choice.set_item_metadata(0,"player_tank")
	var admitted := catalog.load_all(historical_defs)
	for id in VehicleCatalog.IDS:
		vehicle_choice.add_item(id if not catalog.packages.has(id) else str(catalog.packages[id].packet.display_name))
		var index := vehicle_choice.item_count-1
		vehicle_choice.set_item_metadata(index,id)
		vehicle_choice.set_item_disabled(index,not catalog.packages.has(id))
		if id == initial_vehicle_id: vehicle_choice.select(index)
	controls.add_child(vehicle_choice)
	vehicle_choice.item_selected.connect(_select_vehicle)
	dossier_button = CoreUI.button(controls,"查看车型资料与未核验字段",_show_dossier)
	if profile == null: profile = ProfileStore.new()
	preparation = GaragePreparation.new(); controls.add_child(preparation)
	preparation.setup(self,profile)
	CoreUI.label(controls,"弹种 / 游戏设计穿深",16)
	shell_choice = OptionButton.new()
	shell_choice.add_item("AP70 · 70 mm")
	shell_choice.add_item("AP120 · 120 mm")
	shell_choice.select(0 if initial_loadout.shell_id == "ap70" else 1)
	controls.add_child(shell_choice)
	var ammo_row := HBoxContainer.new()
	controls.add_child(ammo_row)
	CoreUI.label(ammo_row,"携弹量",16)
	rounds = SpinBox.new()
	rounds.min_value = 1
	rounds.max_value = 30
	rounds.value = initial_loadout.rounds
	ammo_row.add_child(rounds)
	infinite = CheckBox.new()
	infinite.text = "无限训练弹（仍需自然装填）"
	infinite.button_pressed = initial_loadout.infinite
	controls.add_child(infinite)
	CoreUI.label(controls,"选择课目",16)
	case_choice = OptionButton.new()
	for title in TrainingDirector.TITLES: case_choice.add_item(title)
	case_choice.select(initial_case)
	controls.add_child(case_choice)
	var goal := CoreUI.label(controls,TrainingDirector.GOALS[initial_case],15)
	goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal.custom_minimum_size = Vector2(300,58)
	case_choice.item_selected.connect(func(index: int) -> void: goal.text = TrainingDirector.GOALS[index])
	start_button = CoreUI.button(left_column,"进入训练",_start)
	CoreUI.button(controls,"1 对 1 歼灭（工程夹具）",func() -> void: laboratory_requested.emit("duel"))
	CoreUI.button(left_column,"4 对 4 占点",func() -> void: laboratory_requested.emit("team"))
	error_label = CoreUI.label(controls,"",14)
	if not admitted.ok: error_label.text = "历史配置未通过装配检查："+", ".join(admitted.errors)
	error_label.modulate = Color("ffc282")
	CoreUI.label(controls,"专项实验室（工程夹具）",16)
	var labs := HBoxContainer.new()
	controls.add_child(labs)
	for item in [["armor","装甲"],["ballistics","弹道"],["recovery","恢复"],["terrain","地形"]]:
		CoreUI.button(labs,item[1],func() -> void: laboratory_requested.emit(item[0]))
	CoreUI.button(controls,"电脑驾驶实验室",func() -> void: laboratory_requested.emit("ai_drive"))
	CoreUI.button(controls,"电脑交战实验室",func() -> void: laboratory_requested.emit("ai_combat"))
	CoreUI.button(controls,"AP / APHE 弹药实验室",func() -> void: laboratory_requested.emit("shells"))
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	var cards := HBoxContainer.new(); right.add_child(cards)
	for i in VehicleCatalog.IDS.size():
		var card := CoreUI.button(cards,["M4A3\n中型","M24\n轻型","M26\n重型 / 中型","M36\n歼击车"][i],func() -> void: vehicle_choice.select(i+1); _select_vehicle(i+1))
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
	CoreUI.button(view_controls,"转左",func() -> void: preview.rotation.y -= PI/4)
	inspect_button = CoreUI.button(view_controls,"查看：外观 → 装甲 → 内构",_inspect)
	inspect_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	CoreUI.button(view_controls,"转右",func() -> void: preview.rotation.y += PI/4)
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
	result_label = CoreUI.label(right,"尚无本次会话训练结果。",16)
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	CoreUI.label(vertical,"W/S 驾驶  ·  A/D 转向  ·  鼠标瞄准  ·  左键开炮  ·  Esc 暂停与返回",15)
	_select_vehicle(vehicle_choice.selected)

func build_loadout() -> Dictionary:
	return TrainingLoadout.validate({"vehicle_id":"test_vehicle","shell_id":"ap70" if shell_choice.selected == 0 else "ap120","rounds":int(rounds.value),"infinite":infinite.button_pressed})

func _start() -> void:
	if selected_vehicle_id() in VehicleCatalog.IDS:
		laboratory_requested.emit("historical")
		return
	var value := build_loadout()
	if not value.ok: error_label.text = value.reason
	else: training_requested.emit(value.loadout,case_choice.selected)

func _inspect() -> void:
	_view_mode = (_view_mode+1)%3
	_apply_preview_mode()
	inspect_button.text = "当前："+["外观","装甲（橙：估算，灰：未知）","内构（蓝：部件，绿：乘员）"][_view_mode]+" · 点击切换"

func _apply_preview_mode() -> void:
	preview.set_mode(["appearance","armor","interior"][_view_mode])
	for id in preview._patch_nodes:
		var mesh: MeshInstance3D = preview._patch_nodes[id]
		if _view_mode == 0: mesh.material_override.albedo_color = Color("667653")
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
			inspection_choice.add_item("乘员 / "+CoreUI.word(station.id))
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
				inspection_value.text = "名义厚度 %.1f mm · %s\n局部几何：%s"%[patch.thickness_mm,_evidence_word(patch.thickness_status),_evidence_word(patch.geometry_status)] if patch.has_thickness else "厚度未知，不以0 mm替代。\n局部几何："+_evidence_word(patch.geometry_status)
	elif entry.kind == "module":
		preview.select_module(entry.id)
		for module in preview.layout.modules:
			if module.id == entry.id: inspection_value.text = CoreUI.word(module.kind)+" · 内构位置与尺寸："+_evidence_word(module.geometry_status)
		if preparation.current_id in VehicleCatalog.IDS:
			var checked := profile.service.build_loadout(preparation.loadouts[preparation.current_id])
			if checked.ok and checked.inventory.racks.has(entry.id): inspection_value.text += "\n架内%d发；空架隐藏。"%checked.inventory.racks[entry.id]
	else:
		preview.select_crew(entry.id)
		inspection_value.text = "乘员位置盒为估算；具体角色与原始资料见车型档案。"
	preparation.apply_rack_preview()

func _evidence_word(value: String) -> String:
	return {"verified":"已核验","estimated":"估算","unknown":"未知"}.get(value,value)

func _patch_label(patch: ArmorPatchDefinition) -> String:
	var zones := {"hull_front_upper":"车体前上","hull_front_lower":"车体前下","hull_sides_front":"车体侧部前段","hull_sides_rear":"车体侧部后段","hull_sides_lower":"车体下侧前段","hull_sides_lower_rear":"车体下侧后段","hull_rear_upper":"车体后上","hull_rear_lower":"车体后下","hull_roof_front":"车顶前段","hull_roof_rear":"车顶后段","hull_floor_front":"车底前段","hull_floor_rear":"车底后段","turret_front":"炮塔正面","turret_sides":"炮塔侧面","turret_rear":"炮塔后面","turret_roof":"炮塔顶面","gun_shield":"炮盾","gun_tube":"炮管"}
	var title: String = zones.get(patch.plate_group_id,CoreUI.word(patch.id))
	if "side" in patch.plate_group_id: title = ("左 · " if patch.outward_normal_local.x<0 else "右 · ")+title
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
	var historical := catalog.packages.has(id)
	shell_choice.disabled = historical
	rounds.editable = not historical; infinite.disabled = historical; case_choice.disabled = historical
	dossier_button.disabled = not historical
	start_button.text = "驾驶所选历史车辆" if historical else "进入训练"
	var layout: VehicleLayoutDefinition = catalog.packages[id].layout if historical else M4EngineeringProfile.layout()
	preview.setup(layout)
	for extra in preview._extra_nodes.duplicate():
		if not extra.name.begins_with("Wire_"):
			preview._extra_nodes.erase(extra); extra.queue_free()
	if historical:
		var packet: Dictionary = catalog.packages[id].packet
		if shell_choice.item_count < 3: shell_choice.add_item("")
		shell_choice.set_item_text(2,str(packet.assembly.shell)+" · "+str(packet.assembly.caliber_mm)+" mm")
		shell_choice.select(2)
		rounds.max_value = 150; rounds.value = packet.runtime.rounds
		HistoricalVehicleModel.build_details(preview._part_nodes.hull,preview._part_nodes.turret,preview._part_nodes.barrel,packet,1)
		preview_note.text = "%s\n%s · %d 发 · %.1f km/h 文献道路速度\n局部形状、内构盒、装填与穿深模拟为估算；详见资料档案。"%[packet.display_name,packet.assembly.shell,packet.runtime.rounds,packet.runtime.forward_max_speed*3.6]
		var ammo := HistoricalShellCatalog.build(packet)
		if ammo.ok:
			preview_note.text += "\n1 / 2 选择下一发："+ammo.options[0].display_name+" / "+ammo.options[1].display_name
			preview_note.text += "\n默认主弹70%、另一弹30%；APHE有游戏化内部爆发。"
			if id.begins_with("us_m24"): preview_note.text += "\nM72适配来自手册瞄准图，1951实际配发未核实。"
		var extent: float = maxf(float(HistoricalEvidenceGate.value(packet,"dimensions.reference_length_m")),float(packet.geometry.barrel_length)+3.5)
		preview_camera.position = Vector3(5.3,3.8,-6.4)*extent/6.0
	else:
		if shell_choice.item_count > 2: shell_choice.remove_item(2)
		shell_choice.select(0 if initial_loadout.shell_id == "ap70" else 1)
		rounds.max_value = 30; rounds.value = initial_loadout.rounds
		M4LowPolyDetails.build(preview._part_nodes.hull,preview._part_nodes.turret,preview._part_nodes.barrel,1)
		preview_note.text = "M4A3 外形工程样车：正面240、其他20 mm为训练设计值。\n历史配置另列；专项实验室继续使用工程夹具。"
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
	CoreUI.label(box,packet.display_name+" · 字段证据",23)
	var view := RichTextLabel.new()
	view.bbcode_enabled = true; view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.selection_enabled = true; box.add_child(view)
	view.append_text("[b]已核验 = 引用记录有史料支持；不等于几何、游戏表现已全部实测。[/b]\n")
	var ammunition := HistoricalShellCatalog.build(packet)
	if ammunition.ok:
		view.append_text("\n[b]021 当前弹种（覆盖下方020包的弹道初值）[/b]\n")
		for entry in ammunition.entries:
			view.append_text("\n[b]"+str(entry.label)+"[/b] · "+str(entry.gun)+"\n")
			view.add_text("初速 "+str(entry.muzzle_velocity_mps)+" m/s · "+str(entry.muzzle_velocity_status)+"\n")
			view.add_text("穿深曲线（米,毫米） "+JSON.stringify(entry.penetration_curve)+" · estimated\n"+str(entry.estimate_reason)+"\n"+str(entry.historical_observations)+"\n")
			for ref in entry.source_refs:
				var source: Dictionary = ammunition.sources[ref]
				view.append_text("[url="+str(source.url)+"]"+str(source.title)+"[/url]\n")
				view.add_text(str(source.location)+"\nSHA256 "+str(source.sha256)+"\n")
		view.append_text("\n[b]020 车型包原始字段记录（弹道初值已由上述021弹种目录覆盖）[/b]\n")
	for limitation in packet.limitations: view.add_text(str(limitation)+"\n")
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
	CoreUI.button(box,"关闭资料档案",overlay.queue_free)
