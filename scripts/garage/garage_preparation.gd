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
	mode_choice.add_item("训练 / 自由对战（全车开放）")
	mode_choice.add_item("正式对战（研发与完赛收益）")
	mode_choice.select(1 if saved.mode == "normal" else 0)
	add_child(mode_choice)
	mode_choice.item_selected.connect(_mode_changed)
	research_label = CoreUI.label(self,"",14)
	research_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	research_button = CoreUI.button(self,"研发当前车辆",_research)
	settings_button = CoreUI.button(self,"展开配弹与编成",func() -> void:
		details.visible = not details.visible
		settings_button.text = "收起配弹与编成" if details.visible else "展开配弹与编成")
	details = VBoxContainer.new(); details.visible = false; add_child(details)
	ammo_box = VBoxContainer.new(); details.add_child(ammo_box)
	rack_label = CoreUI.label(details,"",14)
	rack_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	CoreUI.label(details,"再出击编成（最多3辆）",16)
	for i in VehicleCatalog.IDS.size():
		var id: String = VehicleCatalog.IDS[i]
		var check := CheckBox.new()
		check.text = ["M4A3 · 中型","M24 · 轻型","M26 · 重型 / 中型","M36 · 坦克歼击车"][i]
		details.add_child(check); lineup_checks[id] = check
		check.toggled.connect(func(on: bool) -> void: _lineup_changed(id,on))
	CoreUI.label(details,"地图 · 4对4占点",15)
	map_choice = OptionButton.new(); details.add_child(map_choice)
	for id in MapRegistry.IDS: map_choice.add_item(MapRegistry.ENTRIES[id].title)
	map_choice.select(MapRegistry.IDS.find(saved.map))
	map_note = CoreUI.label(details,MapRegistry.ENTRIES[saved.map].description,13)
	map_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_choice.item_selected.connect(func(index: int) -> void: map_note.text = MapRegistry.ENTRIES[MapRegistry.IDS[index]].description)
	difficulty_choice = OptionButton.new()
	for title in ["简单 AI","普通 AI","困难 AI"]: difficulty_choice.add_item(title)
	difficulty_choice.select(["easy","normal","hard"].find(saved.difficulty))
	details.add_child(difficulty_choice)
	CoreUI.button(details,"保存战前设置",save_settings)
	CoreUI.label(details,"初始100点；胜60 / 负30 / 平40 / 退出0。\n研发只开放车型，不改变历史核心性能。",13)

func mode() -> String: return "normal" if mode_choice.selected == 1 else "training"

func select_vehicle(id: String) -> void:
	current_id = id
	_refreshing = true
	for child in ammo_box.get_children(): child.free()
	shell_spins.clear()
	first_choice = null
	settings_button.disabled = id not in VehicleCatalog.IDS
	if id in VehicleCatalog.IDS:
		# Editing may leave a temporarily invalid total; UI metadata still comes from the admitted catalog.
		var prepared := store.service.build_loadout(store.service.default_loadout(id))
		CoreUI.label(ammo_box,"两种炮弹数量（首发已计入总数）",14)
		for shell in prepared.options:
			var row := HBoxContainer.new(); ammo_box.add_child(row)
			var label := CoreUI.label(row,shell.display_name,14); label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var spin := SpinBox.new(); spin.min_value = 0; spin.max_value = prepared.inventory.capacity; spin.value = loadouts[id].counts[shell.id]
			row.add_child(spin); shell_spins[shell.id] = spin
			spin.value_changed.connect(func(_value: float) -> void: _ammo_changed())
		CoreUI.label(ammo_box,"首发 / 初始待装弹种",14)
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
		if current_id not in VehicleCatalog.IDS:
			garage.vehicle_choice.select(1); garage._select_vehicle(1)
	_refresh_research(); _refresh_lineup()

func _refresh_research() -> void:
	var profile := store.snapshot()
	if current_id not in VehicleCatalog.IDS:
		research_label.text = "工程样车只供训练。研发点：%d"%profile.research_points
		research_button.visible = false
		return
	var availability := ResearchGraph.availability(current_id,profile)
	research_label.text = "研发点：%d · %s\nM4 → M24(80) / M36(120) → M26(180)"%[profile.research_points,availability.reason]
	if mode() == "training": research_label.text += "\n训练可试所有车型；正式对战执行研发限制。"
	research_button.visible = not availability.get("unlocked",false)
	research_button.disabled = not availability.ok or not store.writable
	research_button.text = "研发当前车辆 · %d点"%ResearchGraph.NODES[current_id].cost

func _research() -> void:
	var result := ResearchGraph.unlock(store,current_id)
	garage.error_label.text = result.reason
	if result.ok and current_id not in lineup_ids and lineup_ids.size() < 3: lineup_ids.append(current_id)
	_refresh_research(); _refresh_lineup()

func _refresh_lineup() -> void:
	for id in lineup_checks:
		lineup_checks[id].set_pressed_no_signal(id in lineup_ids)
		lineup_checks[id].disabled = mode() == "normal" and id not in store.snapshot().unlocked

func _lineup_changed(id: String, on: bool) -> void:
	if on and id not in lineup_ids:
		if lineup_ids.size() == 3: garage.error_label.text = "最多编入3辆车，请先移除一辆。"
		else: lineup_ids.append(id)
	elif not on:
		if id == current_id: garage.error_label.text = "首发车辆必须保留在编成中。"
		else: lineup_ids.erase(id)
	_refresh_lineup()

func _ammo_changed() -> void:
	if _refreshing or first_choice == null: return
	for id in shell_spins: loadouts[current_id].counts[id] = int(shell_spins[id].value)
	loadouts[current_id].first_shell = first_choice.get_item_metadata(first_choice.selected)
	_refresh_racks()

func _refresh_racks() -> void:
	if current_id not in VehicleCatalog.IDS: rack_label.text = ""; return
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
	garage.preview_note.text = "%s · %d / %d 发\n%.0f mm · 文献道路速度 %.1f km/h · 装填 %.1f秒（估算）\n几何、内构与穿深模拟为估算；空架隐藏，首发计入总数。"%[packet.display_name,inventory.available,inventory.capacity,packet.assembly.caliber_mm,packet.runtime.forward_max_speed*3.6,packet.runtime.reload_time]
	if current_id.begins_with("us_m24"): garage.preview_note.text += "\nM72适配来自手册瞄准图，1951实际配发未核实。"
	rack_label.text = "携弹 %d / %d · 炮膛1发\n"%[inventory.available,inventory.capacity]
	for id in inventory.racks: rack_label.text += "%s：%d\n"%[CoreUI.word(id),inventory.racks[id]]
	apply_rack_preview()
	if garage.inspection_choice != null and garage._view_mode == 2: garage._select_inspection(garage.inspection_choice.selected)

func apply_rack_preview() -> void:
	if current_id not in VehicleCatalog.IDS or garage.preview == null: return
	var checked := store.service.build_loadout(loadouts[current_id])
	if not checked.ok: return
	for id in checked.inventory.racks:
		if garage.preview._module_nodes.has(id): garage.preview._module_nodes[id].visible = garage._view_mode == 2 and checked.inventory.racks[id] > 0

func build_match() -> Dictionary:
	return MatchConfig.build({"mode":mode(),"selected_vehicle_id":current_id,"map":MapRegistry.IDS[map_choice.selected],"difficulty":["easy","normal","hard"][difficulty_choice.selected],"lineup":lineup_ids,"loadouts":loadouts},store.service,store.snapshot().unlocked)

func save_settings() -> Dictionary:
	var checked := build_match()
	if not checked.ok: garage.error_label.text = checked.reason; return checked
	var next := store.snapshot()
	next.garage = checked.config.snapshot()
	next.garage.loadouts = loadouts.duplicate(true)
	var saved := store.commit(next)
	garage.error_label.text = "战前设置已保存。" if saved.ok else saved.reason
	return saved
