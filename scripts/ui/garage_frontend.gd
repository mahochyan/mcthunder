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
## WT-UI-004/S01: the vehicle's condition, in the design's own seven-term vocabulary.
var state_label: Label
var stats: Label
var deploy: Button
var page_index := 0
## UI-BIZ-01 stage 4: the scale-dependent containers, kept so the layout can be re-applied when the text scale changes.
var outer_box: MarginContainer
var main_column: VBoxContainer
var body_row: HBoxContainer
## The text scale the current layout was built for, so a change can be noticed and re-applied.
var _last_scale := 1.0

## UI-BIZ-01 stage 4: the parts of the layout that depend on the text scale, in one place. The garage builds its layout
## once, so without this a player who raises the text scale in the settings panel would keep the standard margins until a
## restart, and the matrix shows why that matters: at 1280x720 with a 125 percent scale the vehicle cards land five
## pixels below the bottom edge. The garage suite's mid-run scale change is the witness for that path.
func apply_scale_layout() -> void:
	if outer_box == null or main_column == null or body_row == null: return
	var compact_layout: bool = AccessibilitySettings.ui_scale > 1.0
	var layout_prefix := "compact" if compact_layout else "standard"
	var outer_margin := int(UiTokens.metric("layouts."+layout_prefix+".outer_margin",16.0 if compact_layout else 24.0))
	var block_gap := int(UiTokens.metric("layouts."+layout_prefix+".gap",12.0 if compact_layout else 16.0))
	for side in ["left","right","top","bottom"]: outer_box.add_theme_constant_override("margin_"+side,outer_margin)
	main_column.add_theme_constant_override("separation",maxi(6,block_gap - 4))
	body_row.add_theme_constant_override("separation",block_gap)

## A theme change is how the settings panel rebuilds a scale, so the scale-aware layout is refreshed with it too. It is
## not enough on its own: setting a parent's theme does not deliver this notification to children, which a suite run
## measured by leaving every rectangle identical after the scale changed.
func _notification(what: int) -> void:
	if what == Control.NOTIFICATION_THEME_CHANGED: apply_scale_layout()

## The text scale is a static value with no signal of its own, so it is watched here rather than only at build time.
## One float comparison per frame is cheaper than a stale layout: without this, raising the scale in the settings panel
## keeps the standard margins until the garage is rebuilt, and the matrix measured the consequence at five pixels of
## overflow on a 720 pixel window.
func _process(_delta: float) -> void:
	if is_equal_approx(_last_scale,AccessibilitySettings.ui_scale): return
	_last_scale = AccessibilitySettings.ui_scale
	apply_scale_layout()
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
	# UI-BIZ-01 stage 3: the atmosphere goes in first so it sits behind every later sibling - base colour, procedural
	# vignette and a faint accent wash along the top edge. It is full-bleed and ignores the mouse.
	BizTheme.atmosphere(g)
	# UI-BIZ-01 stage 4: the design says a 125% text scale triggers the compact layout on content demand, and the matrix
	# audit measured exactly why - at 125% the footer sat twenty-seven pixels below the bottom edge, because the standard
	# margins and gaps leave no vertical room once the type grows. The layout row is therefore chosen from the tokens with
	# the scale taken into account, instead of the literals this file used before.
	var compact_layout: bool = AccessibilitySettings.ui_scale > 1.0
	var layout_prefix := "compact" if compact_layout else "standard"
	var outer_margin := int(UiTokens.metric("layouts."+layout_prefix+".outer_margin",16.0 if compact_layout else 24.0))
	var block_gap := int(UiTokens.metric("layouts."+layout_prefix+".gap",12.0 if compact_layout else 16.0))
	var sidebar_width := UiTokens.metric("layouts."+layout_prefix+".sidebar",296.0 if compact_layout else 320.0)
	var outer := MarginContainer.new(); outer.name="Frontend"; g.add_child(outer); outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer_box = outer
	for side in ["left","right","top","bottom"]: outer.add_theme_constant_override("margin_"+side,outer_margin)
	var vertical := VBoxContainer.new(); vertical.add_theme_constant_override("separation",maxi(6,block_gap - 4)); outer.add_child(vertical)
	main_column = vertical
	var header := HBoxContainer.new(); header.add_theme_constant_override("separation",22); vertical.add_child(header)
	var brand := VBoxContainer.new(); brand.custom_minimum_size.x=286; header.add_child(brand)
	# UI-BIZ-01 stage 3 (screen 1): the logotype takes the added OFL latin display face at the overlay's logotype
	# size, and the strapline keeps its latin face at caption size. Chinese text elsewhere keeps the project font.
	BizTheme.logotype(brand,"MCTHUNDER")
	var brand_sub := GarageTheme.text(brand,"A R M O R E D   W A R F A R E",10,BizTheme.text_tertiary())
	brand_sub.add_theme_font_override("font",BizTheme.FONT_LATIN)
	tree_button=button(header,"科技树",open_research_tree); BizTheme.apply_button(tree_button,"ghost","research")
	var tab_icons := ["battle","ammo","training"]
	for i in 3:
		var nav := button(header,["作战","车辆配装","训练中心"][i],func() -> void: show_page(i))
		nav.custom_minimum_size.x=118; tabs.append(nav)
		# UI-BIZ-01 stage 3: the shared icon set reaches the tab row too, so the header reads as one system.
		var tex := BizTheme.icon_texture(tab_icons[i],18)
		if tex != null:
			nav.icon=tex
			nav.add_theme_constant_override("h_separation",8)
	_refresh_tabs()
	var spacer := Control.new(); spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL; header.add_child(spacer)
	var settings_button := button(header,"设置",func() -> void:
		var panel := InputSettingsPanel.new(); panel.profile=g.profile
		panel.progress_reset.connect(func() -> void: g.progress_reset.emit()); g.add_child(panel))
	var quit_button := button(header,"退出",func() -> void: AppDialog.focus_cancel(AppDialog.show(g,LocalizationService.text("menu_quit"),LocalizationService.text("menu_quit_body"),LocalizationService.text("menu_quit_confirm"),func() -> void: g.quit_requested.emit())))
	var line := ColorRect.new(); line.custom_minimum_size.y=1; line.color=BizTheme.hairline(); vertical.add_child(line)
	var body := HBoxContainer.new(); body.size_flags_vertical=Control.SIZE_EXPAND_FILL; body.add_theme_constant_override("separation",block_gap); vertical.add_child(body)
	body_row = body
	# Measured: narrowing the sidebar at 125% made the vertical overflow worse, not better, because the summary and
	# error text wrapped into more lines. The sidebar width therefore stays where it was; only the outer margin, the
	# block gap and the strip padding respond to the scale.
	var side := PanelContainer.new(); side.custom_minimum_size.x=310; body.add_child(side)
	# UI-BIZ-01 stage 3: the action column is the raised surface of a two-level layout, so the deploy decision sits
	# on a visibly different plane from the scrolling page beside it.
	side.add_theme_stylebox_override("panel",BizTheme.panel_box("raised"))
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
	var loadout_open := button(pages[0],"调整携弹与出战阵容   →",func() -> void: show_page(1)); BizTheme.apply_button(loadout_open,"secondary","ammo")
	g.challenge_button=button(pages[0],"战术挑战   ↗",g._open_challenges); BizTheme.apply_button(g.challenge_button,"secondary","challenge")
	move(g.result_label,pages[0]); g.result_label.add_theme_color_override("font_color",GarageTheme.MUTED)
	move(g.error_label,side_column)
	# WT-UI-006 (S03): the current configuration summary is fixed outside the scrolling area, beside the main action.
	loadout_summary=GarageTheme.text(side_column,"",12,GarageTheme.MUTED)
	loadout_summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	deploy=button(side_column,"进入战斗   →",func() -> void: g.laboratory_requested.emit("team")); BizTheme.apply_button(deploy,"primary","battle")
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
	# WT-UI-011 (S08): the lesson cards live in the shell's control column, which stays hidden, so they are moved into
	# the training page explicitly like the other real controls.
	if g.training_cards != null: move(g.training_cards,pages[2])
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
	# WT-UI-004/S01: the condition is spelled out with the design's terms instead of collapsing every state into one
	# grey card; each term is chosen from a source the garage already has.
	state_label=GarageTheme.text(name_stack,"",13,GarageTheme.ACCENT)
	stats=GarageTheme.text(hero_header,"",14,GarageTheme.MUTED); stats.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT; stats.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	move(viewport_container,hero); viewport_container.custom_minimum_size=Vector2(200,120); viewport_container.size_flags_vertical=Control.SIZE_EXPAND_FILL
	# UI-BIZ-01 stage 3: a one-pixel accent bezel above the model view. It reads as an instrument screen rather than a
	# hole in the panel, and it costs a single pixel of layout height in a column that expands anyway.
	var bezel := ColorRect.new()
	bezel.custom_minimum_size.y=1
	bezel.color=BizTheme.accent_line()
	bezel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hero.add_child(bezel)
	hero.move_child(bezel,viewport_container.get_index())
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
	# The design's own range for the bottom strip is 80-112 px, so the row asks for the token card height plus the
	# strip's own padding and lands at 112 rather than 114. At a raised text scale the CARD itself needs about 120 px
	# because its two text lines wrap further, so tightening the padding to 104 clipped the card and broke the garage
	# suite's scroll-into-view check - measured, then reverted. The strip keeps its full padding; the raised-scale
	# savings come from the compact outer margin and block gap instead.
	collection_scroll.custom_minimum_size.y=float(UiTokens.metric("components.vehicle_card.height",96.0))+16.0
	vertical.add_child(collection_scroll)
	var carousel := HBoxContainer.new(); carousel.add_theme_constant_override("separation",10); collection_scroll.add_child(carousel)
	for i in g.vehicle_choice.item_count:
		var id: String=g.vehicle_choice.get_item_metadata(i)
		var card := button(carousel,"%02d   %s\n%s"%[i+1,short_names.get(id,id),_country(id)],func() -> void: g.vehicle_choice.select(i); g._select_vehicle(i))
		card.tooltip_text=g.vehicle_choice.get_item_text(i)
		BizTheme.apply_button(card,"secondary")
		# UI-BIZ-01 stage 3: measured, not assumed - a thumbnail inside the 216x96 token card squeezed the two text
		# lines into three or four at 125%, which pushed the strip to 128 px (bound 80-112) and stopped the selected
		# card scrolling fully into view. The card therefore stays text-only and the real render plate belongs in the
		# hero, where there is room; a vehicle without a render says so instead of borrowing another vehicle's image.
		card.custom_minimum_size=Vector2(UiTokens.metric("components.vehicle_card.width",216.0),UiTokens.metric("components.vehicle_card.height",96.0))
		card.clip_text=false; card.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; card.alignment=HORIZONTAL_ALIGNMENT_LEFT; cards.append(card)
	# UI-BIZ-01 stage 4: a flowing footer. At 125% text scale the hint and the build identity together are wider than
	# the window, and the layout audit caught both labels being drawn outside the viewport. Shrinking the type is
	# forbidden by the design, so the footer wraps instead of running off the edge.
	var footer := HFlowContainer.new()
	footer.add_theme_constant_override("h_separation",18)
	footer.add_theme_constant_override("v_separation",2)
	vertical.add_child(footer)
	var hint := GarageTheme.text(footer,"TAB  切换焦点     ENTER  确认     ·     在车辆视图拖动以旋转",11,BizTheme.text_tertiary())
	var identity := GarageTheme.text(footer,"MCT  /  "+BuildIdentity.describe(),11,BizTheme.text_tertiary())
	identity.add_theme_font_override("font",BizTheme.FONT_LATIN)
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
	tag(state_label,"garage.vehicle.state")
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
	_refresh_tabs()
	# UI-BIZ-01 stage 3: a fade-only transition on the page that just became visible. Modulate alone, so nothing a
	# verifier measures mid-transition changes.
	BizTheme.fade_in(pages[index])
	garage.preparation.details.visible=index==1 and garage.profile.service.has_vehicle(garage.selected_vehicle_id())

func refresh() -> void:
	if title==null: return
	var id := garage.selected_vehicle_id()
	title.text=short_names.get(id,garage.vehicle_choice.get_item_text(garage.vehicle_choice.selected))
	# UI-BIZ-01 stage 3: a latin vehicle name takes the added display face at the overlay's display size; a Chinese
	# name keeps the project's CJK face, so neither language can end up on a missing glyph.
	title.add_theme_font_size_override("font_size",roundi(float(UiTokens.biz_type_size("display_l",34)) * AccessibilitySettings.ui_scale))
	if BizTheme.is_latin(title.text):
		title.add_theme_font_override("font",BizTheme.FONT_LATIN)
	else:
		title.remove_theme_font_override("font")
	subtitle.text=VehicleDisplayMetadata.identity_line(id)
	if state_label != null:
		var admitted: bool = garage.profile.service.has_vehicle(id)
		var unlocked: bool = id in garage.profile.snapshot().unlocked
		var packet: Dictionary = garage.catalog.packages[id].packet if garage.catalog.packages.has(id) else {}
		var has_model: bool = packet.has("model_binding") or packet.get("model") is Dictionary
		var config_ok: bool = garage.preparation.build_match().ok
		state_label.text=VehicleDisplayMetadata.state_term(id,admitted,unlocked,has_model,config_ok)
	if role_label != null: role_label.text=LocalizationService.text("vehicle_role_unknown")
	deploy.text="现代河谷 · 内部测试   →" if VehicleCatalog.is_engineering(id) else "进入战斗   →"
	stats.text="部位毁伤\n装甲 · 乘员 · 模块"
	if garage.catalog.packages.has(id):
		var packet: Dictionary=garage.catalog.packages[id].packet
		stats.text="%s mm  主炮\n%d  发携弹上限"%[str(packet.assembly.caliber_mm),int(packet.runtime.rounds)]
	for i in cards.size():
		cards[i].add_theme_stylebox_override("normal",BizTheme.row_box(i==garage.vehicle_choice.selected,false))
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

## UI-BIZ-01 stage 3: the tab row reads the shared component layer, so the current page is marked by the one
## accent-coloured element in the header rather than by a per-file literal colour.
func _refresh_tabs() -> void:
	for i in tabs.size():
		var active := i == page_index
		BizTheme.apply_tab(tabs[i],active)
		tabs[i].add_theme_color_override("font_color",BizTheme.accent() if active else BizTheme.text_secondary())

## UI-BIZ-01 stage 3: a vehicle's OWN checked-in thumbnail, or null. The set is the research render set, whose
## manifest records its sources; a vehicle without one says the picture is missing and keeps its name, and another
## vehicle's image is never substituted.
## UI-BIZ-01 stage 3: a vehicle's OWN checked-in render, or null. Kept for the hero render plate; the collection card
## deliberately does not use it (see the measurement note there). Another vehicle's image is never substituted.
static func thumbnail_for(id: String) -> Texture2D:
	var path := "res://assets/research/thumbnails/%s.png" % id
	if not ResourceLoader.exists(path): return null
	var loaded: Variant = load(path)
	return loaded if loaded is Texture2D else null
