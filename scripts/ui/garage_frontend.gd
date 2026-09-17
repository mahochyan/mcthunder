class_name GarageFrontend
extends RefCounted
## Presentation composition of existing garage controls; their services and signals remain authoritative.
var garage: GarageShell
var pages: Array[Control]=[]
var tabs: Array[Button]=[]
var cards: Array[Button]=[]
var title: Label
var subtitle: Label
var role_label: Label
var stats: Label
var deploy: Button
var page_index := 0
var research_tree: VehicleResearchTree
var tree_button: Button
var map_survey_button: Button
var map_drive_button: Button
var river_team_button: Button
var short_names := {"player_tank":"M4A3", "us_m4a3_75w_vvss_1944":"M4A3 (75) W", "us_m24_m6_t85e1_1951":"M24 CHAFFEE", "us_m26_m3_1945":"M26 PERSHING", "us_m36_m4a1_1945":"M36 JACKSON"}
## WT-UI-004: the bottom strip is the current lineup plus a horizontally scrollable collection row.
var lineup_row: HBoxContainer
var collection_scroll: ScrollContainer
## WT-UI-006: the fixed current-configuration summary, outside the scrolling area and next to the main action.
var loadout_summary: Label

func button(parent: Node, text: String, action: Callable) -> Button:
	return CoreUI.button(parent,text,action)

func move(control: Control, parent: Node) -> void:
	control.reparent(parent); control.show()
	control.size_flags_horizontal=Control.SIZE_EXPAND_FILL

func section(parent: Node, eyebrow: String, heading: String) -> void:
	GarageTheme.text(parent,eyebrow,12,GarageTheme.ACCENT)
	GarageTheme.text(parent,heading,25)

## WT-UI-003: attach a stable semantic id to an existing control. Metadata only - no node, no signal and no
## behaviour is added, so tests and later work never have to locate a button by its visible text or by an
## @Button index, and a renamed label can never break a check.
func tag(control: Control, id: String) -> Control:
	if control != null: control.set_meta("ui_id",id)
	return control

func compose(g: GarageShell) -> void:
	garage=g
	short_names.merge({"ussr_t_80b":"T-80B","germ_leopard_2a4":"LEOPARD 2A4"})
	var old_margin: Control=g.get_node("GarageControlSource")
	# Capture existing controls before moving their containers.
	var tutorial_row: Control=g.find_child("TutorialChapters",true,false).get_parent()
	var viewport_container: SubViewportContainer=g.preview.get_parent().get_parent()
	var view_controls: Control=g.inspect_button.get_parent()
	old_margin.hide()
	g.theme=GarageTheme.theme()
	var outer := MarginContainer.new(); outer.name="Frontend"; g.add_child(outer); outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: outer.add_theme_constant_override("margin_"+side,24)
	var vertical := VBoxContainer.new(); vertical.add_theme_constant_override("separation",10); outer.add_child(vertical)
	var header := HBoxContainer.new(); header.add_theme_constant_override("separation",22); vertical.add_child(header)
	var brand := VBoxContainer.new(); brand.custom_minimum_size.x=286; header.add_child(brand)
	GarageTheme.text(brand,"MCTHUNDER",25)
	GarageTheme.text(brand,"A R M O R E D   W A R F A R E",10,GarageTheme.MUTED)
	tree_button=button(header,"科技树",open_research_tree)
	for i in 3:
		var nav := button(header,["作战","车辆配装","训练中心"][i],func() -> void: show_page(i))
		nav.custom_minimum_size.x=96; tabs.append(nav)
	var spacer := Control.new(); spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL; header.add_child(spacer)
	var settings_button := button(header,"设置",func() -> void:
		var panel := InputSettingsPanel.new(); panel.profile=g.profile
		panel.progress_reset.connect(func() -> void: g.progress_reset.emit()); g.add_child(panel))
	var quit_button := button(header,"退出",func() -> void: AppDialog.focus_cancel(AppDialog.show(g,LocalizationService.text("menu_quit"),LocalizationService.text("menu_quit_body"),LocalizationService.text("menu_quit_confirm"),func() -> void: g.quit_requested.emit())))
	var line := ColorRect.new(); line.custom_minimum_size.y=1; line.color=Color("344045"); vertical.add_child(line)
	var body := HBoxContainer.new(); body.size_flags_vertical=Control.SIZE_EXPAND_FILL; body.add_theme_constant_override("separation",24); vertical.add_child(body)
	var side := PanelContainer.new(); side.custom_minimum_size.x=310; body.add_child(side)
	var side_column := VBoxContainer.new(); side_column.add_theme_constant_override("separation",12); side.add_child(side_column)
	var scroll := ScrollContainer.new(); scroll.follow_focus=true; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; side_column.add_child(scroll)
	var page_host := VBoxContainer.new(); page_host.size_flags_horizontal=Control.SIZE_EXPAND_FILL; scroll.add_child(page_host)
	for i in 3:
		var page := VBoxContainer.new(); page.add_theme_constant_override("separation",8); page.size_flags_horizontal=Control.SIZE_EXPAND_FILL; page_host.add_child(page); pages.append(page)
	section(pages[0],"01  /  DEPLOYMENT","准备出战")
	GarageTheme.text(pages[0],"选择战场，检查阵容，然后出发。",14,GarageTheme.MUTED)
	GarageTheme.text(pages[0],"对局规则",13,GarageTheme.MUTED); move(g.preparation.mode_choice,pages[0])
	GarageTheme.text(pages[0],"行动区域",13,GarageTheme.MUTED); move(g.preparation.map_choice,pages[0]); move(g.preparation.map_note,pages[0])
	GarageTheme.text(pages[0],"对手难度",13,GarageTheme.MUTED); move(g.preparation.difficulty_choice,pages[0])
	var loadout_open := button(pages[0],"调整携弹与出战阵容   →",func() -> void: show_page(1))
	g.challenge_button=button(pages[0],"战术挑战   ↗",g._open_challenges)
	move(g.result_label,pages[0]); g.result_label.add_theme_color_override("font_color",GarageTheme.MUTED)
	move(g.error_label,side_column)
	# WT-UI-006 (S03): the current configuration summary is fixed outside the scrolling area, beside the main action.
	loadout_summary=GarageTheme.text(side_column,"",12,GarageTheme.MUTED)
	loadout_summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	deploy=button(side_column,"进入战斗   →",func() -> void: g.laboratory_requested.emit("team")); GarageTheme.primary(deploy)
	section(pages[1],"02  /  VEHICLE SYSTEMS","车辆配装")
	# WT-UI-006 (S03): the ammunition and lineup groups come first in the loadout column, so shell cards and counts
	# are visible without scrolling; the vehicle picker, dossier and research line follow below them.
	move(g.preparation.details,pages[1])
	move(g.vehicle_choice,pages[1]); move(g.dossier_button,pages[1]); move(g.preparation,pages[1])
	# WT-UI-006: the ammunition, lineup and inspection groups are visible by default, so this control collapses them
	# for compact layouts instead of being the only way to reveal them.
	g.preparation.settings_button.show()
	g.preparation.settings_button.text=LocalizationService.text("ui_1f530a0720a5")
	move(g.preview_note,pages[1]); g.preview_note.add_theme_color_override("font_color",GarageTheme.MUTED)
	section(pages[2],"03  /  FIELD TRAINING","训练中心")
	map_survey_button=button(pages[2],"河谷枢纽 · 大地图勘察",func() -> void:
		if g.get_node_or_null("RiverJunctionSurvey")==null: g.add_child(RiverJunctionSurvey.new()))
	map_drive_button=button(pages[2],"河谷枢纽 · 实地驾驶",func() -> void: g.laboratory_requested.emit("river_drive"))
	river_team_button=button(pages[2],"苏德现代河谷 · 三点争夺",func() -> void: g.laboratory_requested.emit("river_team"))
	river_team_button.tooltip_text="先选择 T-80B 或豹 2A4。内部 4v4 测试，不发放研发奖励。"
	for child in tutorial_row.get_children():
		if child is Control: move(child,pages[2])
	GarageTheme.text(pages[2],"自由靶场",18)
	move(g.case_choice,pages[2]); move(g.shell_choice,pages[2]); move(g.rounds,pages[2]); move(g.infinite,pages[2]); move(g.start_button,pages[2])
	for entry in [["duel","单车对抗"],["armor","装甲试验"],["ballistics","弹道试验"],["recovery","战损与维修"],["terrain","地形驾驶"],["ai_drive","编队驾驶"],["ai_combat","战术交战"],["shells","弹药试验"]]:
		button(pages[2],entry[1],func() -> void: g.laboratory_requested.emit(entry[0]))
	var hero := VBoxContainer.new(); hero.size_flags_horizontal=Control.SIZE_EXPAND_FILL; hero.add_theme_constant_override("separation",8); body.add_child(hero)
	var hero_header := HBoxContainer.new(); hero.add_child(hero_header)
	var name_stack := VBoxContainer.new(); name_stack.size_flags_horizontal=Control.SIZE_EXPAND_FILL; hero_header.add_child(name_stack)
	subtitle=GarageTheme.text(name_stack,"",12,GarageTheme.ACCENT)
	title=GarageTheme.text(name_stack,"",36)
	# WT-UI-004: the vehicle type is a required identity field. No service exposes a role yet, so the line is
	# rendered with the explicit unknown entry rather than being dropped or filled with a guess.
	role_label=GarageTheme.text(name_stack,"",12,GarageTheme.MUTED)
	stats=GarageTheme.text(hero_header,"",14,GarageTheme.MUTED); stats.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT; stats.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	move(viewport_container,hero); viewport_container.custom_minimum_size=Vector2(200,120); viewport_container.size_flags_vertical=Control.SIZE_EXPAND_FILL
	move(view_controls,hero); move(g.inspection_row,hero)
	# WT-UI-006 (S03): inspection is its own group and reads this vehicle's own panels, modules and crew.
	GarageTheme.text(hero,LocalizationService.text("loadout_group_check"),16)
	var collection_header := HBoxContainer.new(); vertical.add_child(collection_header)
	var roster := GarageTheme.text(collection_header,"车库   /   VEHICLE COLLECTION",12,GarageTheme.MUTED); roster.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var showroom := button(collection_header,"模型展厅",func() -> void:
		if g.get_node_or_null("ModelShowroom")==null: g.add_child(ModelShowroom.new()))
	var credits := button(collection_header,LocalizationService.text("menu_credits"),g._show_credits)
	for action in [showroom,credits]:
		action.add_theme_font_size_override("font_size",12)
		for state in ["normal","hover","pressed"]: action.add_theme_stylebox_override(state,GarageTheme.box(Color.TRANSPARENT,Color.TRANSPARENT,4))
	# WT-UI-004 (S01): the bottom strip states the CURRENT LINEUP first, and the full collection row is
	# horizontally scrollable so a narrow window never squeezes the cards or the font (token card size 216x96).
	# The collection row deliberately stays visible: four existing checks - the modern garage verifier, the modern
	# match verifier, the packaged player-flow verifier and the garage frontend suite - click frontend.cards[]
	# directly, so hiding the row would break them. That is a recorded conflict with S01's "only the lineup slots"
	# wording, handled by ADDING the lineup row instead of hiding the row those checks depend on.
	lineup_row=HBoxContainer.new(); lineup_row.add_theme_constant_override("separation",10); vertical.add_child(lineup_row)
	collection_scroll=ScrollContainer.new()
	collection_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
	collection_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	collection_scroll.custom_minimum_size.y=float(UiTokens.metric("components.vehicle_card.height",96.0))+18.0
	vertical.add_child(collection_scroll)
	var carousel := HBoxContainer.new(); carousel.add_theme_constant_override("separation",10); collection_scroll.add_child(carousel)
	for i in g.vehicle_choice.item_count:
		var id: String=g.vehicle_choice.get_item_metadata(i)
		var card := button(carousel,"%02d   %s\n%s"%[i+1,short_names.get(id,id),_country(id)],func() -> void: g.vehicle_choice.select(i); g._select_vehicle(i))
		card.tooltip_text=g.vehicle_choice.get_item_text(i)
		card.custom_minimum_size=Vector2(UiTokens.metric("components.vehicle_card.width",216.0),UiTokens.metric("components.vehicle_card.height",96.0))
		card.clip_text=false; card.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; card.alignment=HORIZONTAL_ALIGNMENT_LEFT; cards.append(card)
	var footer := HBoxContainer.new(); vertical.add_child(footer)
	var hint := GarageTheme.text(footer,"TAB  切换焦点     ENTER  确认     ·     在车辆视图拖动以旋转",11,GarageTheme.MUTED); hint.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	GarageTheme.text(footer,"MCT  /  "+BuildIdentity.describe(),11,GarageTheme.MUTED)
	viewport_container.gui_input.connect(_preview_input)
	_stage(viewport_container.get_child(0))
	show_page(0); refresh(); g._refresh_inspection()
	# WT-UI-003: stable semantic ids, tagged onto the controls that already exist. Names follow the work order's
	# suggestions (garage.deploy, garage.tab.loadout); everything else follows the same dotted scheme so the map in
	# UI_BINDING_MAP.json and this list stay in step. Hidden pages stay hidden and out of the focus chain because
	# show_page() only toggles visibility, which Godot already excludes from focus.
	tag(deploy,"garage.deploy")
	tag(tree_button,"garage.nav.research")
	tag(settings_button,"garage.nav.settings")
	tag(quit_button,"garage.nav.quit")
	for i in tabs.size(): tag(tabs[i],["garage.tab.battle","garage.tab.loadout","garage.tab.training"][i])
	for i in cards.size(): tag(cards[i],"garage.card."+str(garage.vehicle_choice.get_item_metadata(i)))
	tag(title,"garage.vehicle.title"); tag(subtitle,"garage.vehicle.nation_role"); tag(stats,"garage.vehicle.stats")
	tag(role_label,"garage.vehicle.role")
	tag(garage.vehicle_choice,"garage.vehicle.picker"); tag(garage.dossier_button,"garage.vehicle.dossier")
	tag(garage.preparation.mode_choice,"garage.preparation.mode")
	tag(garage.preparation.map_choice,"garage.preparation.map")
	tag(garage.preparation.difficulty_choice,"garage.preparation.difficulty")
	tag(garage.result_label,"garage.deploy.result"); tag(garage.error_label,"garage.error")
	tag(garage.inspect_button,"garage.preview.inspect"); tag(garage.inspection_row,"garage.preview.inspect_row")
	tag(viewport_container,"garage.preview.viewport"); tag(loadout_open,"garage.loadout.open")
	tag(loadout_summary,"garage.loadout.summary")
	tag(lineup_row,"garage.lineup.row"); tag(collection_scroll,"garage.collection.row")
	tag(garage.challenge_button,"garage.challenge.open")
	tag(river_team_button,"garage.training.river_team")
	tag(map_survey_button,"garage.training.river_survey"); tag(map_drive_button,"garage.training.river_drive")
	tag(g.start_button,"garage.training.start"); tag(g.case_choice,"garage.training.case")
	tag(g.shell_choice,"garage.training.shell"); tag(g.rounds,"garage.training.rounds")
	# Decorative separators and placeholder spacers must not intercept the mouse; interactive surfaces keep theirs.
	# WT-UI-003: the rule is applied to every ColorRect in the composed frontend, not just the two known ones, so a
	# page that moves its own separator in (GaragePreparation does) cannot silently start eating clicks.
	line.mouse_filter=Control.MOUSE_FILTER_IGNORE
	spacer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var decorative: Array[ColorRect] = []
	_decorative_rects(outer,decorative)
	for rect in decorative: rect.mouse_filter=Control.MOUSE_FILTER_IGNORE

## WT-UI-003: plain rectangles in the composed frontend are separators or placeholder fills, never click targets.
func _decorative_rects(root: Node, out: Array[ColorRect]) -> void:
	for child in root.get_children():
		if child is ColorRect: out.append(child)
		_decorative_rects(child,out)

func _stage(viewport: SubViewport) -> void:
	viewport.msaa_3d=Viewport.MSAA_2X
	for child in viewport.get_children():
		if child is WorldEnvironment:
			child.environment.background_color=Color("182126")
			child.environment.ambient_light_color=Color("9aa9b1"); child.environment.ambient_light_energy=0.35
		if child is DirectionalLight3D:
			child.light_energy=0.75; child.light_color=Color("f7e6c6"); child.shadow_enabled=true; child.directional_shadow_max_distance=30
	var stage := Node3D.new(); viewport.add_child(stage)
	CoreVehicleVisual.box(stage,Vector3(0,-0.12,0),Vector3(1000,0.15,1000),Color("11191d"))
	for x in [-3.5,3.5]: CoreVehicleVisual.box(stage,Vector3(x,-0.035,0),Vector3(0.055,0.01,14),Color("7e7559"))
	for z in [-6.0,6.0]: CoreVehicleVisual.box(stage,Vector3(0,-0.035,z),Vector3(7,0.01,0.055),Color("7e7559"))
	# Low-cost authored hangar framing, independent of the inspected vehicle.
	var wall := CoreVehicleVisual.box(stage,Vector3(0,5,12),Vector3(200,10,0.4),Color("121b20")); wall.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for x in [-12,-6,0,6,12]:
		CoreVehicleVisual.box(stage,Vector3(x,4,11.6),Vector3(0.16,8,0.25),Color("29363c"))
		var strip := CoreVehicleVisual.box(stage,Vector3(x+2.5,5,11.35),Vector3(3,0.035,0.03),Color("788988"))
		var material := strip.mesh.material as StandardMaterial3D; material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	var rim := DirectionalLight3D.new(); rim.rotation_degrees=Vector3(-25,145,0); rim.light_color=Color("b9d6e0"); rim.light_energy=0.45; stage.add_child(rim)

func _preview_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_LEFT:
		garage.preview.rotation.y+=event.relative.x*0.009
		garage.preview.get_viewport().set_input_as_handled()

func show_page(index: int) -> void:
	page_index=index
	for i in pages.size():
		pages[i].visible=i==index
		tabs[i].add_theme_stylebox_override("normal",GarageTheme.box(Color("30382f") if i==index else Color.TRANSPARENT,GarageTheme.ACCENT if i==index else Color.TRANSPARENT))
	garage.preparation.details.visible=index==1 and garage.profile.service.has_vehicle(garage.selected_vehicle_id())

func refresh() -> void:
	if title==null: return
	var id := garage.selected_vehicle_id()
	title.text=short_names.get(id,garage.vehicle_choice.get_item_text(garage.vehicle_choice.selected))
	subtitle.text=VehicleDisplayMetadata.identity_line(id)
	if role_label != null: role_label.text=LocalizationService.text("vehicle_role_unknown")
	deploy.text="现代河谷 · 内部测试   →" if VehicleCatalog.is_engineering(id) else "进入战斗   →"
	stats.text="部位毁伤\n装甲 · 乘员 · 模块"
	if garage.catalog.packages.has(id):
		var packet: Dictionary=garage.catalog.packages[id].packet
		stats.text="%s mm  主炮\n%d  发携弹上限"%[str(packet.assembly.caliber_mm),int(packet.runtime.rounds)]
	for i in cards.size():
		cards[i].add_theme_stylebox_override("normal",GarageTheme.box(Color("30382f") if i==garage.vehicle_choice.selected else Color("171f24"),GarageTheme.ACCENT if i==garage.vehicle_choice.selected else Color("303a3e")))
	# WT-UI-004: the collection row scrolls horizontally, so the selected card is scrolled into view instead of being
	# left off-screen; the row still keeps every card reachable.
	if collection_scroll != null and cards.size() > garage.vehicle_choice.selected:
		collection_scroll.ensure_control_visible(cards[garage.vehicle_choice.selected])
	# WT-UI-006: the three groups stay visible on the loadout page; a vehicle with no admitted packet shows an
	# explicit empty state inside the ammunition group instead of the whole page disappearing.
	garage.preparation.details.visible=page_index==1
	refresh_lineup_row()
	# WT-UI-006: the fixed summary shows the real MatchConfig this selection would produce, or the service's own
	# reason when it is not valid yet. It never invents a configuration.
	if loadout_summary != null:
		var built: Dictionary = garage.preparation.build_match()
		if built.ok:
			var config := built.config as MatchConfig
			var total := 0
			for lineup_id in config.vehicle_ids():
				for amount in config.loadout(str(lineup_id)).get("counts",{}).values(): total += int(amount)
			loadout_summary.text=LocalizationService.text("loadout_config_summary")%[config.mode(),config.map_id(),total]
		else:
			loadout_summary.text=str(built.get("reason",""))

## WT-UI-004 (S01): the vehicles this match will actually field, read from the existing lineup state. Informational
## labels only - the selection itself stays in GaragePreparation, and an empty lineup says so instead of guessing.
func refresh_lineup_row() -> void:
	if lineup_row == null or garage == null or garage.preparation == null: return
	for child in lineup_row.get_children(): child.free()
	tag(GarageTheme.text(lineup_row,LocalizationService.text("garage_lineup_title"),12,GarageTheme.MUTED),"garage.lineup.title")
	var ids: Array = garage.preparation.lineup_ids
	if ids.is_empty():
		tag(GarageTheme.text(lineup_row,LocalizationService.text("garage_lineup_empty"),13,GarageTheme.MUTED),"garage.lineup.empty")
		return
	for i in ids.size():
		var id := str(ids[i])
		var chip := GarageTheme.text(lineup_row,"%s · %s"%[short_names.get(id,id),VehicleDisplayMetadata.state_label(id)],13,GarageTheme.PAPER)
		chip.custom_minimum_size.x=UiTokens.metric("components.vehicle_card.compact_width",188.0)
		tag(chip,"garage.lineup.slot.%d"%i)

func open_research_tree() -> void:
	if is_instance_valid(research_tree): return
	research_tree=VehicleResearchTree.new(); research_tree.garage=garage; garage.add_child(research_tree)

func _country(id: String) -> String:
	# WT-UI-004: one presenter, no default country. An id whose nation the data does not state shows the unknown
	# entry instead of the old unconditional "美国 · 陆战载具" fallback.
	return VehicleDisplayMetadata.identity_line(id)
