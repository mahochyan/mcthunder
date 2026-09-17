class_name VehicleResearchTree
extends Control
## One node per producer-selected base model. Variant references never become playable aliases.
##
## WT-UI-005 (MCT-UI-FIELDWORK-01) changes, all inside the presentation layer:
##   1. the nation and branch labels come from the localisation entry system keyed by the row's own data codes,
##      instead of "苏联" if nation == "ussr" else "德国" which silently relabelled anything else;
##   2. the display-order connectors between cards in a column are gone, because the design forbids decoration
##      that could be mistaken for a research prerequisite - only a real research graph may draw a line, and this
##      data file carries none, so graph.edges stays empty;
##   3. switching nation keeps the search query and the model filter and remembers each nation's scroll position;
##   4. each card carries at most two state layers - content availability above, ownership below - and the
##      ownership verdict is the service's, never the UI's;
##   5. a missing thumbnail says so in words instead of a bare dash.
## Eligibility is untouched: select_button is still gated by the real has_vehicle()/unlocked state, so beautification
## cannot unlock a candidate or change research cost.
const DATA := "res://assets/research/soviet_german_tree.json"
## Branch display order and the localisation key for each data code.
const BRANCHES := {"medium":"branch_medium", "heavy":"branch_heavy", "light":"branch_light", "destroyer":"branch_destroyer", "spaa":"branch_spaa", "other":"branch_other"}
class GraphCanvas extends Control:
	## Only real research prerequisites belong here. The catalogue data carries none, so this stays empty and nothing
	## is drawn between cards.
	##
	## WT-UI-011 (S02): the faint vertical grid that used to be drawn here is gone. The design's first section
	## forbids scanline decoration outright while a later section only permits non-interactive separators, and the
	## grid carried no information, so satisfying the stricter clause removes the ambiguity instead of arguing it. The
	## honest footnote below the tree still states that no research prerequisite line is drawn.
	var edges: Array=[]
	func _draw() -> void:
		for edge in edges: draw_dashed_line(edge[0],edge[1],Color("46534f"),1,5)

var garage: GarageShell
var catalog: Dictionary
var vehicles: Dictionary={}
var selected_id := ""
var country := "ussr"
var graph: GraphCanvas
var tree_nodes: Dictionary={}
var nation_buttons: Dictionary={}
var name_label: Label
var detail_label: Label
var status_label: Label
var points_label: Label
var test_button: Button
var select_button: Button
var preview_control: ResearchModelView
var search: LineEdit
var ready_filter: CheckButton
var tree_scroll: ScrollContainer
var trial: ResearchTrialDrive
var remembered: Dictionary={}
var branch_columns: Dictionary={}
var route_buttons: Dictionary={}
var variants_button: Button
var variants_label: Label
## WT-UI-005: per-nation scroll position, so a nation switch and the return trip keep the player's place.
var scroll_memory: Dictionary={}
var back_button: Button

static func branch_label(code: String) -> String:
	return LocalizationService.text(str(BRANCHES.get(code,"branch_other")))

func tag(control: Control, id: String) -> Control:
	if control != null: control.set_meta("ui_id",id)
	return control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); theme=GarageTheme.theme()
	catalog=JSON.parse_string(FileAccess.get_file_as_string(DATA))
	for row in catalog.vehicles: vehicles[row.id]=row
	# WT-UI-005: the backdrop is decoration, so it takes the background token and never the mouse.
	var bg := ColorRect.new(); bg.color=UiTokens.color("background","#10171B"); bg.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(bg); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new(); add_child(margin); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,24)
	var vertical := VBoxContainer.new(); vertical.add_theme_constant_override("separation",14); margin.add_child(vertical)
	var top := HBoxContainer.new(); vertical.add_child(top)
	var heading := GarageTheme.text(top,LocalizationService.text("research_heading"),30); heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	points_label=GarageTheme.text(top,"",14,GarageTheme.MUTED); tag(points_label,"research.counts")
	back_button=CoreUI.button(top,LocalizationService.text("research_back"),close); tag(back_button,"research.back")
	var nations := HBoxContainer.new(); nations.add_theme_constant_override("separation",12); vertical.add_child(nations)
	for entry in [["ussr","苏联  /  USSR"],["germany","德国  /  GERMANY"]]:
		var tab := CoreUI.button(nations,entry[1],func() -> void: show_country(entry[0])); tab.custom_minimum_size=Vector2(196,48); nation_buttons[entry[0]]=tag(tab,"research.nation."+entry[0])
	var spacer := Control.new(); spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL; spacer.mouse_filter=Control.MOUSE_FILTER_IGNORE; nations.add_child(spacer)
	GarageTheme.text(nations,"GROUND FORCES",12,GarageTheme.ACCENT)
	var filters := HBoxContainer.new(); filters.add_theme_constant_override("separation",16); vertical.add_child(filters)
	search=LineEdit.new(); search.placeholder_text=LocalizationService.text("research_search_hint"); search.size_flags_horizontal=Control.SIZE_EXPAND_FILL; filters.add_child(search)
	search.text_changed.connect(func(_text: String) -> void: rebuild())
	tag(search,"research.search")
	ready_filter=CheckButton.new(); ready_filter.text=LocalizationService.text("research_filter_models"); filters.add_child(ready_filter); ready_filter.toggled.connect(func(_value: bool) -> void: rebuild())
	tag(ready_filter,"research.filter.models")
	var routes := HBoxContainer.new(); routes.add_theme_constant_override("separation",8); vertical.add_child(routes)
	GarageTheme.text(routes,LocalizationService.text("research_routes"),13,GarageTheme.MUTED)
	for branch in BRANCHES:
		var route := CoreUI.button(routes,branch_label(branch),func() -> void:
			if branch_columns.has(branch): tree_scroll.scroll_horizontal=branch_columns[branch]*228)
		route.add_theme_font_size_override("font_size",13); route_buttons[branch]=tag(route,"research.route."+branch)
	var body := HBoxContainer.new(); body.add_theme_constant_override("separation",18); body.size_flags_vertical=Control.SIZE_EXPAND_FILL; vertical.add_child(body)
	var panel := PanelContainer.new(); panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL; body.add_child(panel)
	tree_scroll=ScrollContainer.new(); tree_scroll.follow_focus=true; panel.add_child(tree_scroll)
	graph=GraphCanvas.new(); tree_scroll.add_child(graph)
	tag(tree_scroll,"research.tree.scroll")
	var aside := PanelContainer.new(); aside.custom_minimum_size.x=360; body.add_child(aside)
	var right := VBoxContainer.new(); right.add_theme_constant_override("separation",10); aside.add_child(right)
	var info_scroll := ScrollContainer.new(); info_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; info_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; right.add_child(info_scroll)
	var info := VBoxContainer.new(); info.add_theme_constant_override("separation",10); info.size_flags_horizontal=Control.SIZE_EXPAND_FILL; info_scroll.add_child(info)
	GarageTheme.text(info,"BASE VEHICLE  /  基础车型",12,GarageTheme.ACCENT)
	name_label=GarageTheme.text(info,"",25); name_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	preview_control=ResearchModelView.new(); info.add_child(preview_control)
	detail_label=GarageTheme.text(info,"",14,GarageTheme.MUTED); detail_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	variants_button=CoreUI.button(info,"",func() -> void: variants_label.visible=not variants_label.visible)
	variants_button.add_theme_font_size_override("font_size",13)
	variants_label=GarageTheme.text(info,"",13,GarageTheme.MUTED); variants_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; variants_label.hide()
	status_label=GarageTheme.text(right,"",14,GarageTheme.ACCENT); status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	test_button=CoreUI.button(right,LocalizationService.text("research_trial"),_test_drive); GarageTheme.primary(test_button)
	select_button=CoreUI.button(right,LocalizationService.text("research_select"),_select_for_battle)
	GarageTheme.text(vertical,LocalizationService.text("research_tree_footnote"),12,GarageTheme.MUTED)
	# WT-UI-003: attach the modal BEFORE hiding the frontend. A hidden control loses focus immediately, so hiding
	# first left the modal with nothing recorded and Esc could not restore focus to the control that opened it.
	ModalNavigation.attach(self,close)
	garage.get_node("Frontend").hide(); show_country(country)

static func normalized(value: String) -> String:
	return value.to_lower().replace("-","").replace("_","").replace(" ","").replace("(","").replace(")","")

func matches(row: Dictionary) -> bool:
	if row.nation!=country or (ready_filter.button_pressed and not row.model is Dictionary): return false
	var query := normalized(search.text)
	if query.is_empty(): return true
	var terms: Array=[row.label,row.family,row.id]
	for variant in row.variant_refs: terms.append(variant.id); terms.append(variant.label)
	for term in terms:
		if normalized(str(term)).contains(query): return true
	return false

func show_country(id: String) -> void:
	if not nation_buttons.has(id): return
	# WT-UI-005: the work order requires the filter and the scroll position to survive nation and route jumps, so the
	# query and the model filter are left alone and each nation's own scroll offset is remembered and restored.
	scroll_memory[country]=tree_scroll.scroll_horizontal
	country=id
	for key in nation_buttons:
		nation_buttons[key].add_theme_stylebox_override("normal",GarageTheme.box(Color("30382f") if key==id else Color("171f24"),GarageTheme.ACCENT if key==id else Color("303a3e")))
	rebuild()
	tree_scroll.scroll_horizontal=int(scroll_memory.get(id,0))

func rebuild() -> void:
	for child in graph.get_children(): child.free()
	graph.edges.clear(); tree_nodes.clear(); branch_columns.clear()
	var max_rows := 1; var column := 0
	for branch in BRANCHES:
		var rows: Array=[]
		for row in vehicles.values():
			if row.branch==branch and matches(row): rows.append(row)
		if rows.is_empty(): continue
		branch_columns[branch]=column
		rows.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
			if int(a.order)!=int(b.order): return int(a.order)<int(b.order)
			return str(a.label).naturalnocasecmp_to(str(b.label))<0)
		var x := 20+column*228
		var heading := GarageTheme.text(graph,"%s  ·  %d"%[branch_label(branch),rows.size()],14,GarageTheme.MUTED); heading.position=Vector2(x,12); heading.mouse_filter=Control.MOUSE_FILTER_IGNORE
		for index in rows.size():
			var row: Dictionary=rows[index]; var id: String=row.id
			var button := CoreUI.button(graph,"",func() -> void: select_vehicle(id))
			button.position=Vector2(x,52+index*168); button.size=Vector2(208,140)
			tag(button,"research.card."+id)
			var portrait := TextureRect.new(); portrait.position=Vector2(1,1); portrait.size=Vector2(206,86); portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE; button.add_child(portrait)
			var thumbnail := "res://assets/research/thumbnails/"+id+".png"
			if FileAccess.file_exists(thumbnail): portrait.texture=ImageTexture.create_from_image(Image.load_from_file(thumbnail))
			else:
				# WT-UI-005: a missing thumbnail is stated in words and never borrowed from another vehicle.
				var pending := GarageTheme.text(button,LocalizationService.text("research_thumb_missing"),12,GarageTheme.MUTED); pending.position=Vector2(12,42); pending.size.x=184; pending.mouse_filter=Control.MOUSE_FILTER_IGNORE
			var title := GarageTheme.text(button,row.label,15); title.position=Vector2(12,91); title.size.x=184; title.clip_text=true; title.mouse_filter=Control.MOUSE_FILTER_IGNORE
			# Layer one: content availability. Layer two: ownership. Nothing else is put on the card.
			var state := GarageTheme.text(button,LocalizationService.text("research_content_ready") if row.model is Dictionary else LocalizationService.text("research_content_waiting"),12,GarageTheme.ACCENT if row.model is Dictionary else GarageTheme.MUTED); state.position=Vector2(12,112); state.size.x=184; state.clip_text=true; state.mouse_filter=Control.MOUSE_FILTER_IGNORE
			var ownership := GarageTheme.text(button,ownership_text(id),12,GarageTheme.MUTED); ownership.position=Vector2(12,126); ownership.size.x=184; ownership.clip_text=true; ownership.mouse_filter=Control.MOUSE_FILTER_IGNORE
			button.tooltip_text="%s\n%s：%s\n%s\n%s：%d"%[row.label,LocalizationService.text("research_identity"),id,ownership_text(id),LocalizationService.text("research_variants"),row.variant_refs.size()]
			tree_nodes[id]=button
			# WT-UI-005: no display-order connector. This data file carries no research prerequisite graph, and the
			# design forbids decoration that could be read as a research condition.
		max_rows=maxi(max_rows,rows.size()); column+=1
	graph.custom_minimum_size=Vector2(maxi(column,1)*228+20,max_rows*168+64); graph.queue_redraw()
	for branch in route_buttons: route_buttons[branch].disabled=not branch_columns.has(branch)
	points_label.text=LocalizationService.text("research_counts")%[int(catalog.counts[country]),int(catalog.models[country])]
	var preferred: String=remembered.get(country,"ussr_t_34_1941" if country=="ussr" else "germ_pzkpfw_V_ausf_d_panther")
	if tree_nodes.has(preferred): select_vehicle(preferred)
	elif not tree_nodes.is_empty(): select_vehicle(tree_nodes.keys()[0])
	else:
		selected_id=""; name_label.text=LocalizationService.text("research_empty_title"); preview_control.show_vehicle({}); preview_control.hide(); variants_button.hide(); variants_label.hide(); detail_label.text=LocalizationService.text("research_empty_hint"); status_label.text=""; test_button.disabled=true; select_button.disabled=true
		var empty := GarageTheme.text(graph,LocalizationService.text("research_empty_title"),20,GarageTheme.MUTED); empty.position=Vector2(28,60); empty.mouse_filter=Control.MOUSE_FILTER_IGNORE

## WT-UI-005: the ownership layer, straight from the service. has_vehicle() is the admitted packet and `unlocked` is
## the research state, so the card cannot claim ownership the business layer does not report.
func ownership_text(id: String) -> String:
	var admitted: bool = garage != null and garage.profile.service.has_vehicle(id)
	if not admitted: return LocalizationService.text("research_not_admitted")
	return LocalizationService.text("research_owned") if id in garage.profile.snapshot().unlocked else LocalizationService.text("research_locked")

func select_vehicle(id: String) -> void:
	if not vehicles.has(id): return
	selected_id=id; remembered[country]=id
	var row: Dictionary=vehicles[id]
	name_label.text=row.label
	var loaded := preview_control.show_vehicle(row); preview_control.visible=loaded
	# WT-UI-005: the nation label comes from the row's own nation code through the entry system, and an unknown code
	# shows the explicit unknown label rather than being relabelled as another country.
	detail_label.text="%s · %s\n%s：%s"%[VehicleDisplayMetadata.nation_label_for_code(str(row.nation)),branch_label(str(row.branch)),LocalizationService.text("research_family"),str(row.family).replace("_"," ").to_upper()]
	variants_label.hide(); variants_button.visible=not row.variant_refs.is_empty(); variants_label.text=LocalizationService.text("research_variant_reference")
	if not row.variant_refs.is_empty():
		variants_button.text=LocalizationService.text("research_variants_count")%row.variant_refs.size()
		for variant in row.variant_refs: variants_label.text+="\n· "+str(variant.label)
	status_label.text=LocalizationService.text("research_model_ready") if loaded else LocalizationService.text("research_model_pending")
	if row.model is Dictionary and not loaded: status_label.text=LocalizationService.text("research_model_failed")
	if variants_button != null: tag(variants_button,"research.variants")
	tag(test_button,"research.trial"); tag(select_button,"research.select")
	test_button.disabled=not loaded
	# Availability remains tied to a real, admitted packet; static models cannot bypass it.
	var admitted: bool = garage.profile.service.has_vehicle(id)
	var unlocked: bool = id in garage.profile.snapshot().unlocked
	select_button.disabled=not admitted or not unlocked
	select_button.tooltip_text=LocalizationService.text("research_select_blocked") if select_button.disabled else LocalizationService.text("research_select_open")
	for key in tree_nodes: tree_nodes[key].add_theme_stylebox_override("normal",GarageTheme.box(Color("30382f") if key==id else Color("182126"),GarageTheme.ACCENT if key==id else Color("39484c"),12))

func _test_drive() -> void:
	if test_button.disabled or selected_id.is_empty() or is_instance_valid(trial): return
	trial=ResearchTrialDrive.new(); trial.row=vehicles[selected_id]; add_child(trial)

func _select_for_battle() -> void:
	if select_button.disabled: return
	for index in garage.vehicle_choice.item_count:
		if garage.vehicle_choice.get_item_metadata(index)==selected_id:
			garage.vehicle_choice.select(index); garage._select_vehicle(index)
			garage.preparation.mode_choice.select(1); garage.preparation._mode_changed(1)
			close(); garage.frontend.show_page(0); return

func close() -> void:
	garage.get_node("Frontend").show(); garage.frontend.refresh(); queue_free()
