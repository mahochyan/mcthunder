class_name VehicleResearchTree
extends Control
## One node per producer-selected base model. Variant references never become playable aliases.
const DATA := "res://assets/research/soviet_german_tree.json"
const BRANCHES := {"medium":"中型 / 主战", "heavy":"重型坦克", "light":"轻型 / 侦察", "destroyer":"歼击 / 自行火炮", "spaa":"自行防空", "other":"其他载具"}
class GraphCanvas extends Control:
	var edges: Array=[]
	func _draw() -> void:
		for x in range(0,int(size.x),32): draw_line(Vector2(x,0),Vector2(x,size.y),Color(0.35,0.45,0.48,0.06))
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

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); theme=GarageTheme.theme()
	catalog=JSON.parse_string(FileAccess.get_file_as_string(DATA))
	for row in catalog.vehicles: vehicles[row.id]=row
	var bg := ColorRect.new(); bg.color=GarageTheme.INK; add_child(bg); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new(); add_child(margin); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,24)
	var vertical := VBoxContainer.new(); vertical.add_theme_constant_override("separation",14); margin.add_child(vertical)
	var top := HBoxContainer.new(); vertical.add_child(top)
	var heading := GarageTheme.text(top,"陆军科技树",30); heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	points_label=GarageTheme.text(top,"",14,GarageTheme.MUTED)
	CoreUI.button(top,"返回车库   ×",close)
	var nations := HBoxContainer.new(); nations.add_theme_constant_override("separation",12); vertical.add_child(nations)
	for entry in [["ussr","苏联  /  USSR"],["germany","德国  /  GERMANY"]]:
		var tab := CoreUI.button(nations,entry[1],func() -> void: show_country(entry[0])); tab.custom_minimum_size=Vector2(196,48); nation_buttons[entry[0]]=tab
	var spacer := Control.new(); spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL; nations.add_child(spacer)
	GarageTheme.text(nations,"GROUND FORCES",12,GarageTheme.ACCENT)
	var filters := HBoxContainer.new(); filters.add_theme_constant_override("separation",16); vertical.add_child(filters)
	search=LineEdit.new(); search.placeholder_text="搜索车型或改型，例如 T-80 / Leopard"; search.size_flags_horizontal=Control.SIZE_EXPAND_FILL; filters.add_child(search)
	search.text_changed.connect(func(_text: String) -> void: rebuild())
	ready_filter=CheckButton.new(); ready_filter.text="仅显示已有模型"; filters.add_child(ready_filter); ready_filter.toggled.connect(func(_value: bool) -> void: rebuild())
	var routes := HBoxContainer.new(); routes.add_theme_constant_override("separation",8); vertical.add_child(routes)
	GarageTheme.text(routes,"路线",13,GarageTheme.MUTED)
	for branch in BRANCHES:
		var route := CoreUI.button(routes,BRANCHES[branch],func() -> void:
			if branch_columns.has(branch): tree_scroll.scroll_horizontal=branch_columns[branch]*228)
		route.add_theme_font_size_override("font_size",13); route_buttons[branch]=route
	var body := HBoxContainer.new(); body.add_theme_constant_override("separation",18); body.size_flags_vertical=Control.SIZE_EXPAND_FILL; vertical.add_child(body)
	var panel := PanelContainer.new(); panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL; body.add_child(panel)
	tree_scroll=ScrollContainer.new(); tree_scroll.follow_focus=true; panel.add_child(tree_scroll)
	graph=GraphCanvas.new(); tree_scroll.add_child(graph)
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
	test_button=CoreUI.button(right,"外观试驾   ↗",_test_drive); GarageTheme.primary(test_button)
	select_button=CoreUI.button(right,"选择出战   →",_select_for_battle)
	GarageTheme.text(vertical,"每个车族一个基础型 · 改型收录于车辆档案 · 虚线仅连接分类展示顺序",12,GarageTheme.MUTED)
	garage.get_node("Frontend").hide(); show_country(country); ModalNavigation.attach(self,close)

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
	country=id; search.text=""; tree_scroll.scroll_horizontal=0; tree_scroll.scroll_vertical=0
	for key in nation_buttons:
		nation_buttons[key].add_theme_stylebox_override("normal",GarageTheme.box(Color("30382f") if key==id else Color("171f24"),GarageTheme.ACCENT if key==id else Color("303a3e")))
	rebuild()

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
		var heading := GarageTheme.text(graph,BRANCHES[branch]+"  ·  %d"%rows.size(),14,GarageTheme.MUTED); heading.position=Vector2(x,12)
		for index in rows.size():
			var row: Dictionary=rows[index]; var id: String=row.id
			var button := CoreUI.button(graph,"",func() -> void: select_vehicle(id))
			button.position=Vector2(x,52+index*168); button.size=Vector2(208,140); button.clip_text=true; button.alignment=HORIZONTAL_ALIGNMENT_LEFT
			var portrait := TextureRect.new(); portrait.position=Vector2(1,1); portrait.size=Vector2(206,86); portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE; button.add_child(portrait)
			var thumbnail := "res://assets/research/thumbnails/"+id+".png"
			if FileAccess.file_exists(thumbnail): portrait.texture=ImageTexture.create_from_image(Image.load_from_file(thumbnail))
			else:
				var pending := GarageTheme.text(button,"—",30,Color("425158")); pending.position=Vector2(91,15); pending.mouse_filter=Control.MOUSE_FILTER_IGNORE
			var title := GarageTheme.text(button,row.label,15); title.position=Vector2(12,91); title.size.x=184; title.clip_text=true; title.mouse_filter=Control.MOUSE_FILTER_IGNORE
			var state_text := "等待模型"
			if row.get("combat_package") is Dictionary: state_text="可出战  ✓"
			elif row.model is Dictionary: state_text="外观试驾  ↗"
			var state := GarageTheme.text(button,state_text,12,GarageTheme.ACCENT if row.model is Dictionary else GarageTheme.MUTED); state.position=Vector2(12,115); state.mouse_filter=Control.MOUSE_FILTER_IGNORE
			button.tooltip_text="%s\n基础型：%s\n改型参考：%d 项"%[row.label,id,row.variant_refs.size()]
			tree_nodes[id]=button
			if index>0: graph.edges.append([Vector2(x+104,52+(index-1)*168+140),Vector2(x+104,52+index*168)])
		max_rows=maxi(max_rows,rows.size()); column+=1
	graph.custom_minimum_size=Vector2(maxi(column,1)*228+20,max_rows*168+64); graph.queue_redraw()
	for branch in route_buttons: route_buttons[branch].disabled=not branch_columns.has(branch)
	points_label.text="%d 个基础型  /  %d 个已有模型"%[int(catalog.counts[country]),int(catalog.models[country])]
	var preferred: String=remembered.get(country,"ussr_t_34_1941" if country=="ussr" else "germ_pzkpfw_V_ausf_d_panther")
	if tree_nodes.has(preferred): select_vehicle(preferred)
	elif not tree_nodes.is_empty(): select_vehicle(tree_nodes.keys()[0])
	else:
		selected_id=""; name_label.text="没有匹配的车辆"; preview_control.show_vehicle({}); preview_control.hide(); variants_button.hide(); variants_label.hide(); detail_label.text="试试其他车型名称，或关闭模型筛选。"; status_label.text=""; test_button.disabled=true; select_button.disabled=true
		var empty := GarageTheme.text(graph,"没有匹配的基础车型",20,GarageTheme.MUTED); empty.position=Vector2(28,60)

func select_vehicle(id: String) -> void:
	if not vehicles.has(id): return
	selected_id=id; remembered[country]=id
	var row: Dictionary=vehicles[id]
	name_label.text=row.label
	var loaded := preview_control.show_vehicle(row); preview_control.visible=loaded
	detail_label.text="%s · %s\n车族：%s"%["苏联" if row.nation=="ussr" else "德国",BRANCHES[row.branch],str(row.family).replace("_"," ").to_upper()]
	variants_label.hide(); variants_button.visible=not row.variant_refs.is_empty(); variants_label.text="改型仅作资料参考，当前模型为上述基础型。"
	if not row.variant_refs.is_empty():
		variants_button.text="改型参考  ·  %d 项   ▾"%row.variant_refs.size()
		for variant in row.variant_refs: variants_label.text+="\n· "+str(variant.label)
	status_label.text="模型已就绪 · 战斗配置待完成" if loaded else "模型制作中 · 暂未开放试驾"
	if loaded and row.get("combat_package") is Dictionary: status_label.text="缓存数据 · 运行模型 · 战斗配置已按车型 ID 对齐"
	if row.model is Dictionary and not loaded: status_label.text="模型加载失败 · 暂不可用"
	test_button.disabled=not loaded
	# Availability remains tied to a real, admitted packet; static models cannot bypass it.
	var accessible: bool=VehicleCatalog.is_engineering(id) or id in garage.profile.snapshot().unlocked
	select_button.disabled=not garage.profile.service.has_vehicle(id) or not accessible
	select_button.tooltip_text="该车型的武器、装甲与战损接入完成后开放。" if select_button.disabled else "进入车辆配装"
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
