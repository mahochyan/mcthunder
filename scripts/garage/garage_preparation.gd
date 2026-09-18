class_name GaragePreparation
extends VBoxContainer
var garage: GarageShell
var store: ProfileStore
var mode_choice: OptionButton
var difficulty_choice: OptionButton
var map_choice: OptionButton
var map_note: Label
var research_label: Label
var research_button: Button
var settings_button: Button
var details: VBoxContainer
var ammo_box: VBoxContainer
var rack_label: Label
var first_choice: OptionButton
var shell_spins: Dictionary = {}
var lineup_checks: Dictionary = {}
var loadouts: Dictionary = {}
var lineup_ids: Array = []
var current_id := ""
var _refreshing := false
var _ammo_error := ""

func setup(owner_garage: GarageShell, profile: ProfileStore) -> void:
	garage = owner_garage; store = profile
	var saved: Dictionary = store.snapshot().garage
	loadouts = saved.loadouts.duplicate(true); lineup_ids = saved.lineup.duplicate()
	mode_choice = OptionButton.new()
	mode_choice.add_item(LocalizationService.text("ui_c02718ef8959"))
	mode_choice.add_item(LocalizationService.text("ui_823559734937"))
	mode_choice.select(1 if saved.mode == "normal" else 0)
	add_child(mode_choice)
	mode_choice.item_selected.connect(_mode_changed)
	research_label = CoreUI.label(self,"",14)
	research_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	research_button = CoreUI.button(self,LocalizationService.text("ui_a1bc6af3e4cd"),_research)
	settings_button = CoreUI.button(self,LocalizationService.text("ui_e65fa5e6071a"),func() -> void:
		details.visible = not details.visible
		settings_button.text = LocalizationService.text("ui_1f530a0720a5") if details.visible else LocalizationService.text("ui_e65fa5e6071a"))
	details = VBoxContainer.new(); details.visible = false; add_child(details)
	ammo_box = VBoxContainer.new(); details.add_child(ammo_box)
	rack_label = CoreUI.label(details,"",14)
	rack_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	CoreUI.label(details,LocalizationService.text("ui_e183b39e4637"),16)
	for id in store.service.vehicle_ids():
		var check := CheckBox.new()
		check.text = store.service.vehicle_label(id)
		details.add_child(check); lineup_checks[id] = check
		check.toggled.connect(func(on: bool) -> void: _lineup_changed(id,on))
	CoreUI.label(details,LocalizationService.text("ui_61b938d8df0b"),15)
	map_choice = OptionButton.new(); details.add_child(map_choice)
	for id in MapRegistry.IDS: map_choice.add_item(MapRegistry.ENTRIES[id].title)
	map_choice.select(maxi(0,MapRegistry.IDS.find(saved.map)))
	map_note = CoreUI.label(details,MapRegistry.ENTRIES[saved.map].description,13)
	map_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_choice.item_selected.connect(func(index: int) -> void: map_note.text = MapRegistry.ENTRIES[MapRegistry.IDS[index]].description)
	difficulty_choice = OptionButton.new()
	for title in [LocalizationService.text("ui_10d412baf68d"),LocalizationService.text("ui_a7703f5f294c"),LocalizationService.text("ui_6a2316e1b031")]: difficulty_choice.add_item(title)
	difficulty_choice.select(["easy","normal","hard"].find(saved.difficulty))
	details.add_child(difficulty_choice)
	CoreUI.button(details,LocalizationService.text("ui_bb57985a9b4d"),save_settings)
	CoreUI.label(details,LocalizationService.text("ui_9fc6354946e0"),13)

func mode() -> String:
	if VehicleCatalog.is_engineering(current_id): return "engineering"
	return "normal" if mode_choice.selected == 1 else "training"

func select_vehicle(id: String) -> void:
	current_id = id
	var engineering := VehicleCatalog.is_engineering(id)
	mode_choice.disabled = engineering
	map_choice.disabled = engineering
	mode_choice.set_item_text(0,LocalizationService.text("ui_c02718ef8959"))
	mode_choice.set_item_text(1,LocalizationService.text("ui_823559734937"))
	for index in MapRegistry.IDS.size(): map_choice.set_item_text(index,MapRegistry.ENTRIES[MapRegistry.IDS[index]].title)
	if engineering:
		mode_choice.set_item_text(mode_choice.selected,"现代测试（无研发奖励）")
		map_choice.set_item_text(map_choice.selected,"河谷枢纽 · 三点争夺")
	map_note.text = "河谷枢纽 · 苏德现代测试\n4v4 · A / B / C 三点争夺\n不发放研发奖励；10v10 / 16v16 尚待验证。" if engineering else MapRegistry.ENTRIES[MapRegistry.IDS[map_choice.selected]].description
	lineup_ids = lineup_ids.filter(func(vehicle_id: String) -> bool: return VehicleCatalog.is_engineering(vehicle_id)==engineering)
	if store.service.has_vehicle(id) and not lineup_ids.has(id):
		if lineup_ids.size()>=3: lineup_ids.pop_back()
		lineup_ids.append(id)
	_refreshing = true
	for child in ammo_box.get_children(): child.free()
	shell_spins.clear()
	first_choice = null
	settings_button.disabled = not store.service.has_vehicle(id)
	if store.service.has_vehicle(id):
		if not loadouts.has(id): loadouts[id] = store.service.default_loadout(id)
		# Editing may leave a temporarily invalid total; UI metadata still comes from the admitted catalog.
		var prepared := store.service.build_loadout(store.service.default_loadout(id))
		CoreUI.label(ammo_box,LocalizationService.text("ui_ddaff5a533fe"),14)
		for shell in prepared.options:
			var row := HBoxContainer.new(); ammo_box.add_child(row)
			var label := CoreUI.label(row,shell.display_name,14); label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var spin := SpinBox.new(); spin.min_value = 0; spin.max_value = prepared.inventory.capacity; spin.value = loadouts[id].counts[shell.id]
			row.add_child(spin); shell_spins[shell.id] = spin
			spin.value_changed.connect(func(_value: float) -> void: _ammo_changed())
		CoreUI.label(ammo_box,LocalizationService.text("ui_d7fc6412941b"),14)
		first_choice = OptionButton.new(); ammo_box.add_child(first_choice)
		for shell in prepared.options:
			first_choice.add_item(shell.display_name)
			first_choice.set_item_metadata(first_choice.item_count-1,shell.id)
			if shell.id == loadouts[id].first_shell: first_choice.select(first_choice.item_count-1)
		first_choice.item_selected.connect(func(_index: int) -> void: _ammo_changed())
		if not lineup_ids.has(id) and (mode() == "training" or id in store.snapshot().unlocked):
			if lineup_ids.size() == 3: lineup_ids.pop_back()
			lineup_ids.append(id)
	else: details.visible = false
	_refreshing = false
	_refresh_research()
	_refresh_lineup()
	_refresh_racks()

func _mode_changed(_index: int) -> void:
	if mode() == "normal":
		var unlocked: Array = store.snapshot().unlocked
		lineup_ids = lineup_ids.filter(func(id: String) -> bool: return id in unlocked)
		if lineup_ids.is_empty(): lineup_ids = [ResearchGraph.STARTER]
		if not store.service.has_vehicle(current_id):
			garage.vehicle_choice.select(1); garage._select_vehicle(1)
	_refresh_research(); _refresh_lineup()

func _refresh_research() -> void:
	var profile := store.snapshot()
	if VehicleCatalog.is_engineering(current_id):
		research_label.text = "现代工程车已解锁 · 可加入编队\n配弹可保存；对局不发放研发点。"
		research_button.visible = false
		return
	if not store.service.has_vehicle(current_id):
		research_label.text = LocalizationService.text("ui_741319de5a0c")%profile.research_points
		research_button.visible = false
		return
	research_label.text = "全科技树已解锁 · 最多选择 3 辆加入编队"
	if mode() == "training": research_label.text += LocalizationService.text("ui_b95c8942557e")
	research_button.visible = false
	research_button.disabled = true

func _research() -> void:
	var result := ResearchGraph.unlock(store,current_id)
	garage.error_label.text = result.reason
	if result.ok and current_id not in lineup_ids and lineup_ids.size() < 3: lineup_ids.append(current_id)
	_refresh_research(); _refresh_lineup()

func _refresh_lineup() -> void:
	for id in lineup_checks:
		lineup_checks[id].set_pressed_no_signal(id in lineup_ids)
		lineup_checks[id].disabled = VehicleCatalog.is_engineering(id)!=(mode()=="engineering")

func _lineup_changed(id: String, on: bool) -> void:
	if on and id not in lineup_ids:
		if lineup_ids.size() == 3: garage.error_label.text = LocalizationService.text("ui_ad0d14869953")
		else: lineup_ids.append(id)
	elif not on:
		if id == current_id: garage.error_label.text = LocalizationService.text("ui_fb4711be92be")
		else: lineup_ids.erase(id)
	_refresh_lineup()

func _ammo_changed() -> void:
	if _refreshing or first_choice == null: return
	for id in shell_spins: loadouts[current_id].counts[id] = int(shell_spins[id].value)
	loadouts[current_id].first_shell = first_choice.get_item_metadata(first_choice.selected)
	_refresh_racks()

func _refresh_racks() -> void:
	if not store.service.has_vehicle(current_id): rack_label.text = ""; return
	var checked := store.service.build_loadout(loadouts[current_id])
	if not checked.ok:
		rack_label.text = checked.reason
		garage.error_label.text = checked.reason
		_ammo_error = checked.reason
		return
	if garage.error_label.text == _ammo_error: garage.error_label.text = ""
	_ammo_error = ""
	var inventory: Dictionary = checked.inventory
	garage.rounds.value = inventory.available
	var packet: Dictionary = store.service.catalog.packages[current_id].packet
	garage.preview_note.text = LocalizationService.text("ui_f18548e09801")%[packet.display_name,inventory.available,inventory.capacity,packet.assembly.caliber_mm,packet.runtime.forward_max_speed*3.6,packet.runtime.reload_time]
	if packet.get("evidence_profile","historical_verified")=="game_reference": garage.preview_note.text = "%s · %d / %d 发\n%.0f mm · 街机参考／设计速度 %.1f km/h · 装填 %.1f秒（估算）\n街机游戏参考与工程估计，未做历史核验。"%[packet.display_name,inventory.available,inventory.capacity,packet.assembly.caliber_mm,packet.runtime.forward_max_speed*3.6,packet.runtime.reload_time]
	elif current_id.begins_with("us_m24"): garage.preview_note.text += LocalizationService.text("ui_7ec5dcfbc36a")
	rack_label.text = LocalizationService.text("ui_7c2a6d68853f")%[inventory.available,inventory.capacity]
	for id in inventory.racks: rack_label.text += "%s：%d\n"%[CoreUI.word(id),inventory.racks[id]]
	apply_rack_preview()
	if garage.inspection_choice != null and garage._view_mode == 2: garage._select_inspection(garage.inspection_choice.selected)

func apply_rack_preview() -> void:
	if not store.service.has_vehicle(current_id) or garage.preview == null: return
	var checked := store.service.build_loadout(loadouts[current_id])
	if not checked.ok: return
	for id in checked.inventory.racks:
		if garage.preview._module_nodes.has(id): garage.preview._module_nodes[id].visible = garage._view_mode == 2 and checked.inventory.racks[id] > 0

func build_match() -> Dictionary:
	var map_id := "river_junction_team" if mode() == "engineering" else str(MapRegistry.IDS[map_choice.selected])
	return MatchConfig.build({"mode":mode(),"selected_vehicle_id":current_id,"map":map_id,"difficulty":["easy","normal","hard"][difficulty_choice.selected],"lineup":lineup_ids,"loadouts":loadouts},store.service,store.snapshot().unlocked)

func save_settings() -> Dictionary:
	var checked := build_match()
	if not checked.ok: garage.error_label.text = checked.reason; return checked
	var next := store.snapshot()
	next.garage = checked.config.snapshot()
	next.garage.loadouts = loadouts.duplicate(true)
	var saved := store.commit(next)
	garage.error_label.text = LocalizationService.text("ui_9eb0372c01dd") if saved.ok else saved.reason
	return saved
