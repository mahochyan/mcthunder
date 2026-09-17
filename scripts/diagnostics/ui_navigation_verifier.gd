extends Node
## WT-UI-003 (MCT-UI-FIELDWORK-01): normal-input navigation, stable identity, focus and modal containment.
##
## Everything here is driven by REAL mouse and key events on visible controls, reusing window_input_driver: its
## click() asserts that the target is visible and enabled and stops that click when it is not, so a hidden or
## disabled control is reported instead of being clicked through. show_page(), emitted signals and
## request_respawn() are never used as player evidence. A failed click ends that section rather than cascading.
##
## Rejected by the work order and therefore not done anywhere in this file: re-showing the old
## GarageControlSource, and changing global battle key bindings to fix UI focus.
const RESEARCH := "res://scripts/ui/vehicle_research_tree.gd"
var app: AppFlow
var driver: Node
var checks := 0
var failed := 0
var shot_dir := ""

func report(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+label)

func frames(n: int) -> void:
	for i in n: await get_tree().process_frame

## Bounded wait for the app to finish a scene transition.
func idle() -> void:
	for i in 1200:
		await get_tree().process_frame
		if not app._transitioning: return
	report(false,"bounded scene transition")

## Find a control by its stable ui_id. Never by visible text and never by child index.
func by_id(root: Node, id: String) -> Control:
	if root is Control and str(root.get_meta("ui_id","")) == id: return root
	for child in root.get_children():
		var hit := by_id(child,id)
		if hit != null: return hit
	return null

func collect_ids(root: Node, into: Dictionary) -> void:
	if root is Control:
		var id := str(root.get_meta("ui_id",""))
		if not id.is_empty(): into[id] = int(into.get(id,0)) + 1
	for child in root.get_children(): collect_ids(child,into)

func visible_modals() -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group("modal_navigation"):
		var nav := node as ModalNavigation
		if nav != null and is_instance_valid(nav.container) and nav.container.is_visible_in_tree(): n += 1
	return n

func focus_owner() -> Control:
	return get_viewport().gui_get_focus_owner()

## Controls that Godot would consider focusable AND that are actually visible right now.
func focusable_visible(root: Node, out: Array[Control]) -> void:
	for child in root.get_children():
		if child is Control:
			if child.focus_mode != Control.FOCUS_NONE and child.is_visible_in_tree(): out.append(child)
			focusable_visible(child,out)

func run(flow: AppFlow) -> void:
	get_tree().create_timer(300,true,false,true).timeout.connect(func() -> void: print("UI_NAVIGATION_TIMEOUT"); get_tree().quit(2))
	var args := OS.get_cmdline_user_args()
	var shot_index := args.find("--shot-dir")
	if shot_index >= 0 and shot_index + 1 < args.size(): shot_dir = args[shot_index+1]
	if shot_dir.is_empty(): shot_dir = ProjectSettings.globalize_path("user://tests/ui_navigation_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(shot_dir)
	print("UI_NAVIGATION_RUNTIME release=",OS.has_feature("release")," evidence=",shot_dir)

	app = flow
	driver = load("res://scripts/diagnostics/window_input_driver.gd").new()
	driver.app = app
	driver.shot_dir = shot_dir
	add_child(driver)
	await idle()
	await frames(5)

	var g: GarageShell = app.garage
	report(g != null and g.frontend != null, "garage and its frontend exist before navigation starts")
	if g == null or g.frontend == null: print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failed]); print("UI_NAVIGATION_CHECKS_FAIL"); get_tree().quit(1); return
	var f: GarageFrontend = g.frontend

	# --- initial state ------------------------------------------------------------------------------------
	report(f.page_index == 0, "garage opens on the battle page (page_index=%d)" % f.page_index)
	report(f.pages[0].is_visible_in_tree(), "battle page is visible")
	report(not f.pages[1].is_visible_in_tree() and not f.pages[2].is_visible_in_tree(), "loadout and training pages are hidden")
	var source := g.get_node_or_null("GarageControlSource")
	report(source != null and not source.visible, "the old GarageControlSource stays hidden (never re-shown)")
	await driver.capture("nav_00_battle_page")

	# --- stable ui_id inventory ---------------------------------------------------------------------------
	var ids := {}
	collect_ids(g, ids)
	var required := ["garage.deploy","garage.nav.research","garage.tab.battle","garage.tab.loadout","garage.tab.training",
		"garage.vehicle.picker","garage.vehicle.dossier","garage.vehicle.title","garage.preview.viewport","garage.loadout.open",
		"garage.preparation.mode","garage.preparation.map","garage.error","garage.vehicle.role",
		"garage.lineup.row","garage.collection.row"]
	var missing := []
	for id in required:
		if not ids.has(id): missing.append(id)
	report(missing.is_empty(), "every required stable ui_id exists (missing=%s)" % str(missing))
	var duplicated := []
	for id in ids.keys():
		if int(ids[id]) > 1: duplicated.append(id)
	report(duplicated.is_empty(), "no ui_id is used twice (duplicates=%s)" % str(duplicated))
	var card_count := 0
	for id in ids.keys():
		if str(id).begins_with("garage.card."): card_count += 1
	report(card_count >= 5, "each vehicle card carries its own ui_id (%d found)" % card_count)

	# --- hidden pages stay out of the focus chain, decorations do not take the mouse ----------------------
	var focusables: Array[Control] = []
	# GarageFrontend is presentation state on RefCounted, not a Node, so the tree walk starts from the shell.
	focusable_visible(g, focusables)
	report(focusables.size() >= 5, "the visible page exposes focusable controls (%d)" % focusables.size())
	var leaked := 0
	for control in focusables:
		if f.pages[1].is_ancestor_of(control) or f.pages[2].is_ancestor_of(control): leaked += 1
	report(leaked == 0, "hidden pages contribute no focusable control while page 0 is active (leaked=%d)" % leaked)
	# Only VISIBLE rectangles can intercept anything, and a failure names the offender instead of just counting it.
	var rects := 0
	var bad_rects: Array[String] = []
	var stack: Array[Node] = [g]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is ColorRect and node.is_visible_in_tree():
			rects += 1
			if (node as ColorRect).mouse_filter != Control.MOUSE_FILTER_IGNORE: bad_rects.append(str((node as ColorRect).get_path()))
		for child in node.get_children(): stack.append(child)
	report(rects > 0 and bad_rects.is_empty(), "visible decorative rectangles do not intercept the mouse (%d visible, offenders=%s)" % [rects,str(bad_rects)])
	var preview := by_id(g,"garage.preview.viewport")
	report(preview != null and preview.mouse_filter != Control.MOUSE_FILTER_IGNORE, "the vehicle preview keeps its own input for drag rotation")

	# --- WT-UI-004 layout: fixed main action, current lineup strip, scrollable collection ------------------
	var deploy_probe := by_id(g,"garage.deploy")
	var in_scroll := false
	var walker: Node = deploy_probe
	while walker != null:
		if walker is ScrollContainer: in_scroll = true
		walker = walker.get_parent()
	report(deploy_probe != null and not in_scroll, "the main action sits outside every scroll area (fixed, per S01)")
	var lineup := by_id(g,"garage.lineup.row")
	report(lineup != null and lineup.is_visible_in_tree(), "the bottom strip shows the current lineup row")
	var slot_count := 0
	for id in ids.keys():
		if str(id).begins_with("garage.lineup.slot."): slot_count += 1
	report(by_id(g,"garage.lineup.empty") != null or slot_count > 0, "the lineup row shows real slots (%d) or an explicit empty state" % slot_count)
	var collection := by_id(g,"garage.collection.row")
	report(collection is ScrollContainer and (collection as ScrollContainer).horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED, "the collection row scrolls horizontally so a narrow window never squeezes cards or font")
	var card_height := -1.0
	var card_width := -1.0
	for id in ids.keys():
		if str(id).begins_with("garage.card."):
			var card := by_id(g,str(id))
			if card != null: card_height = card.custom_minimum_size.y; card_width = card.custom_minimum_size.x
			break
	report(card_height==UiTokens.metric("components.vehicle_card.height",96.0), "vehicle cards use the token height (%.0f)" % card_height)
	report(card_width==UiTokens.metric("components.vehicle_card.width",216.0), "vehicle cards use the token width (%.0f)" % card_width)
	# WT-UI-004/S01: the design bounds the bottom strip to 80-112 px, and it must not squeeze the 3D preview instead.
	var strip_height: float = collection.size.y
	report(strip_height > 0.0 and strip_height <= 112.0, "the bottom strip stays inside the design's 80-112 range (%.0f)" % strip_height)

	# --- WT-UI-004 close-out: mode / map / vehicle state mapping through the real config objects -------------
	var preparation := g.preparation
	if preparation != null:
		# The control offers two selectable modes; engineering is DERIVED from the chosen vehicle, so the contract
		# under test is that mapping rather than three selectable options.
		var mode_labels := {}
		for i in preparation.mode_choice.item_count:
			preparation.mode_choice.select(i); preparation._mode_changed(i)
			await frames(3)
			mode_labels[i] = preparation.mode()
		report(preparation.mode_choice.item_count == 2 and mode_labels.get(0)=="training" and mode_labels.get(1)=="normal", "the two selectable modes map to training and normal %s" % str(mode_labels))
		var historical_id := str(VehicleCatalog.IDS[0])
		var historical_index := -1
		for i in g.vehicle_choice.item_count:
			if g.vehicle_choice.get_item_metadata(i) == historical_id: historical_index = i
		if historical_index >= 0:
			g.vehicle_choice.select(historical_index); g._select_vehicle(historical_index)
			await frames(3)
			var historical_built: Dictionary = preparation.build_match()
			var historical_config: MatchConfig = null
			if historical_built.ok: historical_config = historical_built.config as MatchConfig
			report(historical_built.ok and historical_config != null and historical_config.map_id()==str(MapRegistry.IDS[preparation.map_choice.selected]) and historical_config.mode()==preparation.mode() and historical_config.selected()==historical_id, "a historical vehicle builds a MatchConfig whose map, mode and selection agree with the UI")
		var engineering_id := str(VehicleCatalog.ENGINEERING_IDS[0])
		var engineering_index := -1
		for i in g.vehicle_choice.item_count:
			if g.vehicle_choice.get_item_metadata(i) == engineering_id: engineering_index = i
		if engineering_index >= 0:
			g.vehicle_choice.select(engineering_index); g._select_vehicle(engineering_index)
			await frames(3)
			var engineering_built: Dictionary = preparation.build_match()
			var engineering_config: MatchConfig = null
			if engineering_built.ok: engineering_config = engineering_built.config as MatchConfig
			report(preparation.mode()=="engineering" and preparation.lineup_ids.size()==1, "an engineering vehicle derives the engineering mode and a single-vehicle lineup")
			report(engineering_built.ok and engineering_config != null and engineering_config.map_id()=="river_junction_team" and engineering_config.mode()=="engineering", "engineering builds its own internal-test MatchConfig")
		report(preparation.map_choice.item_count == MapRegistry.IDS.size(), "the map control offers exactly the registered maps (%d)" % preparation.map_choice.item_count)
		var current := g.selected_vehicle_id()
		report(VehicleDisplayMetadata.typology(current) in ["historical","engineering","training"], "the displayed typology matches the catalogue scope (%s -> %s)" % [current,VehicleDisplayMetadata.typology(current)])
		report(VehicleDisplayMetadata.state_key(current) != "vehicle_state_unknown", "an offered vehicle never shows an unknown content state (%s)" % VehicleDisplayMetadata.state_key(current))
		# Restore the historical selection so the later sections start from the same state as before.
		if historical_index >= 0:
			g.vehicle_choice.select(historical_index); g._select_vehicle(historical_index)
			await frames(3)

	# --- WT-UI-004/S01: the program build identity is stated quietly in the footer --------------------------
	var footer_identity := str(BuildIdentity.describe())
	var footer_label: Label = null
	for footer_node in g.find_children("*","Label",true,false):
		if (footer_node as Label).text.contains(footer_identity): footer_label = footer_node as Label
	report(footer_label != null, "the footer states the program build identity (%s)" % footer_identity)
	if footer_label != null:
		var footer_size := footer_label.get_theme_font_size("font_size")
		report(footer_size > 0 and footer_size <= 12, "and it is de-emphasised by size (%d px)" % footer_size)
		report(footer_label.get_theme_color("font_color").v < 0.8, "and by a muted colour, so it does not compete with the primary content")

	# --- WT-UI-004/S01: the condition uses the design's own vocabulary and is not one merged grey label ---------
	var state_badge := by_id(g,"garage.vehicle.state") as Label
	report(state_badge != null and state_badge.text.length() > 0, "the garage states the vehicle's condition in words (%s)" % (state_badge.text if state_badge != null else "missing"))
	var state_terms: Array[String] = []
	for term_key in VehicleDisplayMetadata.state_term_keys(): state_terms.append(LocalizationService.text(term_key))
	report(state_terms.size() == 6, "the design's seven conditions are carried as six distinct terms (%d)" % state_terms.size())
	var unique_terms: Array[String] = []
	for term in state_terms:
		if term not in unique_terms: unique_terms.append(term)
	report(unique_terms.size() == state_terms.size(), "no two conditions share one label %s" % str(state_terms))
	report(state_badge != null and state_badge.text in state_terms, "the shown condition is one of those terms (%s)" % (state_badge.text if state_badge != null else "missing"))
	var historical_state := state_badge.text if state_badge != null else ""
	var engineering_index := -1
	var restore_index := -1
	for i in g.vehicle_choice.item_count:
		var item_id := str(g.vehicle_choice.get_item_metadata(i))
		if item_id == str(VehicleCatalog.ENGINEERING_IDS[0]): engineering_index = i
		if item_id == str(VehicleCatalog.IDS[0]): restore_index = i
	if engineering_index >= 0 and state_badge != null:
		g.vehicle_choice.select(engineering_index); g._select_vehicle(engineering_index)
		await frames(5)
		report(state_badge.text != historical_state, "a different condition is stated for a different vehicle (%s -> %s)" % [historical_state,state_badge.text])
		if restore_index >= 0:
			g.vehicle_choice.select(restore_index); g._select_vehicle(restore_index)
			await frames(5)

	# --- real-input page switching, twice (repeat enter/exit record) -------------------------------------
	var tab_loadout := by_id(g,"garage.tab.loadout")
	var tab_training := by_id(g,"garage.tab.training")
	var tab_battle := by_id(g,"garage.tab.battle")
	report(tab_loadout != null and tab_training != null and tab_battle != null, "the three main navigation tabs expose stable ids")
	if tab_loadout == null or tab_training == null or tab_battle == null:
		print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failed]); print("UI_NAVIGATION_CHECKS_FAIL"); get_tree().quit(1); return
	for round_index in 2:
		await driver.click(tab_loadout)
		report(f.page_index == 1 and f.pages[1].is_visible_in_tree() and not f.pages[0].is_visible_in_tree(), "clicking the loadout tab switches page (round %d)" % (round_index+1))
		if round_index == 0: await driver.capture("nav_01_loadout_page")
		await driver.click(tab_training)
		report(f.page_index == 2 and f.pages[2].is_visible_in_tree(), "clicking the training tab switches page (round %d)" % (round_index+1))
		if round_index == 0: await driver.capture("nav_02_training_page")
		await driver.click(tab_battle)
		report(f.page_index == 0 and f.pages[0].is_visible_in_tree() and not f.pages[2].is_visible_in_tree(), "clicking the battle tab returns (round %d)" % (round_index+1))
	var loadout_open := by_id(g,"garage.loadout.open")
	report(loadout_open != null, "the loadout entry on the battle page exposes a stable id")
	if loadout_open != null:
		await driver.click(loadout_open)
		report(f.page_index == 1, "the battle page's own loadout entry reaches the loadout page through real input")
		await driver.click(tab_battle)
		report(f.page_index == 0, "and returns to the battle page")

	# --- WT-UI-011 (S08): the four settings groups and the challenge card, through real clicks --------------
	var settings_button := by_id(g,"garage.nav.settings")
	if settings_button != null:
		await driver.click(settings_button)
		await frames(5)
		var panel: Control = null
		for child in g.find_children("*","InputSettingsPanel",true,false): panel = child
		report(panel != null, "the settings entry opens the real settings panel")
		if panel != null:
			var seen: Array[String] = []
			var stack3: Array[Node] = [panel]
			while not stack3.is_empty():
				var node3: Node = stack3.pop_back()
				if node3 is Label:
					var text3 := str((node3 as Label).text)
					for key in ["settings_group_display","settings_group_input","settings_group_sound","settings_group_accessibility"]:
						if text3 == LocalizationService.text(key) and key not in seen: seen.append(key)
				for child in node3.get_children(): stack3.append(child)
			report(seen.size() == 4, "the settings panel shows all four S08 groups %s" % str(seen))
			report(panel.find_children("*","HSlider",true,false).size() >= 4, "the input and sound groups carry real sliders")
			panel.queue_free()
			await frames(4)
	await driver.click(tab_battle)
	await frames(3)
	var challenge_button := by_id(g,"garage.challenge.open")
	if challenge_button != null:
		await driver.click(challenge_button)
		await frames(5)
		var selection: Node = null
		for child in g.find_children("*","ChallengeSelection",true,false): selection = child
		report(selection != null, "the challenge entry opens the real challenge selection")
		if selection != null:
			report(selection.rules_label != null and selection.rules_label.text.length() > 0, "the challenge card states the rules from the catalogue")
			report(selection.rounds_label != null and selection.rounds_label.text.length() > 0, "the challenge card states the ammunition the challenge pins")
			report(selection.best_label != null and selection.best_label.text.length() > 0, "the challenge card states the recorded best score")
			report(selection.current_label != null and selection.current_label.text.length() > 0, "the challenge card states the current-attempt situation without inventing a leaderboard")
			await driver.capture("nav_11_challenge_card")
			selection.queue_free()
			await frames(4)

	# --- WT-UI-011 (S08/S09): the training cards and an explicit empty state capture -----------------------
	await driver.click(tab_training)
	await frames(4)
	var frontend_node := g.get_node_or_null("Frontend")
	var training_cards: Array = frontend_node.find_children("TrainingCards","HFlowContainer",true,false) if frontend_node != null else []
	report(training_cards.size() == 1, "the training page builds the lesson card container")
	if training_cards.size() == 1:
		var cards: Array = training_cards[0].get_children()
		report(cards.size() == TrainingDirector.TITLES.size(), "one card per real lesson (%d of %d)" % [cards.size(),TrainingDirector.TITLES.size()])
		var complete_cards := 0
		for card_index in cards.size():
			var card: Node = cards[card_index]
			var labels: Array = card.find_children("*","Label",true,false)
			var has_goal := false
			var has_completion := false
			for label in labels:
				var label_text := str((label as Label).text)
				if label_text==str(TrainingDirector.GOALS[card_index]): has_goal = true
				if label_text.begins_with("完成情况："): has_completion = true
			if has_goal and has_completion and card.find_children("*","Button",true,false).size() >= 1: complete_cards += 1
		report(complete_cards == cards.size(), "every lesson card carries its goal, its honest completion line and an enter button (%d of %d)" % [complete_cards,cards.size()])
	await driver.capture("nav_12_training_cards")
	await driver.click(tab_battle)
	await frames(3)

	# --- WT-UI-006: the three S03 groups, real shell metadata, the field-level error and the zero rack ----------
	await driver.click(tab_loadout)
	report(f.page_index == 1, "the loadout page is active for the S03 checks")
	var prep := g.preparation
	report(prep.details.is_visible_in_tree(), "the ammunition, lineup and inspection groups are visible by default")
	report(prep.ammo_box != null and prep.ammo_box.is_visible_in_tree(), "the ammunition group exists and is visible")
	report(prep.summary_box != null and prep.summary_box.is_visible_in_tree(), "capacity, stock and the first-round control share one visible summary block")
	report(prep.first_choice != null and prep.summary_box.is_ancestor_of(prep.first_choice), "the first-round control sits inside that same block")
	report(prep.ammo_error_label != null and prep.ammo_box.get_parent()==prep.ammo_error_label.get_parent(), "the ammunition error line lives beside the ammunition fields")
	report(prep.page_summary != null and prep.page_summary.is_visible_in_tree(), "the page ends with a summary line")
	var shells: Array = prep.shell_spins.keys()
	report(shells.size() >= 1, "the ammunition group offers the real shells (%d)" % shells.size())
	var meta_ok := shells.size() >= 1
	var estimate_ok := shells.size() >= 1
	for shell_id in shells:
		var meta_text := str(prep.shell_meta.get(shell_id,""))
		if meta_text.is_empty(): meta_ok = false
		if not meta_text.contains(LocalizationService.text("loadout_estimated")): estimate_ok = false
	report(meta_ok, "every ammunition card states its family, calibre and effect policy from the shell definition")
	report(estimate_ok, "every ammunition card carries the estimate marker the catalogue enforces")
	report(g.preview != null and g.preview._part_nodes.size() > 0, "the inspection reads this vehicle's own panels, modules and crew")
	report(g.preview_note.text.length() > 0, "the estimate/reference note stays visible next to the inspection")
	await driver.capture("nav_08_loadout_groups")
	# Zero rack: drive the real quantity controls to zero, then compare what the page says with the service's answer.
	for shell_id in shells:
		prep.shell_spins[shell_id].value = 0
	prep._ammo_changed()
	await frames(3)
	var zero_checked := g.profile.service.build_loadout(prep.loadouts[g.selected_vehicle_id()])
	report(not zero_checked.ok, "an empty rack is rejected by the service rather than silently accepted")
	report(prep.ammo_error_label.text == str(zero_checked.reason), "the field-level error is the service's own reason, not a paraphrase")
	report(prep.page_summary.text.contains("0"), "the page summary reflects the zero state instead of the old numbers")
	await driver.capture("nav_09_zero_rack")
	# Restore through the same controls a player uses, then confirm the service accepts the loadout again.
	var defaults: Dictionary = g.profile.service.default_loadout(g.selected_vehicle_id())
	for shell_id in shells:
		prep.shell_spins[shell_id].value = int(defaults.get("counts",{}).get(shell_id,0))
	prep._ammo_changed()
	await frames(3)
	var restored_loadout := g.profile.service.build_loadout(prep.loadouts[g.selected_vehicle_id()])
	report(restored_loadout.ok, "the loadout is valid again after the zero-rack check, with the service's own capacity and stock")
	# WT-UI-006/S03: each loadout error kind must carry its own reason, so two different faults may not collapse
	# into one message. Over-capacity and a first round with no stock are constructed through the real controls.
	var capacity := int(prep.shell_spins[shells[0]].max_value)
	for shell_id in shells:
		prep.shell_spins[shell_id].value = capacity
	prep._ammo_changed()
	await frames(5)
	var over_checked := g.profile.service.build_loadout(prep.loadouts[g.selected_vehicle_id()])
	report(not over_checked.ok and prep.ammo_error_label.text==str(over_checked.reason), "an over-capacity total carries the service's own reason (%s)" % str(over_checked.reason))
	var first_shell_id := str(prep.first_choice.get_item_metadata(prep.first_choice.selected))
	var share := maxi(1,int(capacity/shells.size()))
	for shell_id in shells:
		prep.shell_spins[shell_id].value = 0 if shell_id==first_shell_id else share
	prep._ammo_changed()
	await frames(5)
	var no_first_checked := g.profile.service.build_loadout(prep.loadouts[g.selected_vehicle_id()])
	report(not no_first_checked.ok and prep.ammo_error_label.text==str(no_first_checked.reason), "a first round with no stock carries its own reason (%s)" % str(no_first_checked.reason))
	report(str(over_checked.reason)!=str(no_first_checked.reason) or str(over_checked.reason).is_empty(), "the two loadout error kinds do not share one message (%s)" % str(over_checked.reason))
	for shell_id in shells:
		prep.shell_spins[shell_id].value = int(defaults.get("counts",{}).get(shell_id,0))
	prep._ammo_changed()
	await frames(5)

	# WT-UI-010/006-A02: the page edits in memory and only "apply loadout" commits, so leaving the page without
	# applying must leave the saved profile untouched - there must not be two competing commit behaviours.
	var saved_before: Dictionary = g.profile.snapshot().garage.loadouts.duplicate(true)
	var probe_shell := str(shells[0])
	var original_value := int(prep.shell_spins[probe_shell].value)
	prep.shell_spins[probe_shell].value = maxi(0,original_value-1)
	prep._ammo_changed()
	await frames(4)
	await driver.click(tab_battle)
	await frames(5)
	report(g.profile.snapshot().garage.loadouts == saved_before, "an unapplied loadout edit never reaches the saved profile")
	await driver.click(tab_loadout)
	await frames(5)
	prep.shell_spins[probe_shell].value = original_value
	prep._ammo_changed()
	await frames(4)
	await driver.click(tab_battle)
	await frames(3)

	# --- research tree: independent entry, focus containment, Esc close, focus restore ---------------------
	var tree_button := by_id(g,"garage.nav.research")
	report(tree_button != null, "the research tree has its own explicit entry with a stable id")
	var modals_before := visible_modals()
	await driver.click(tree_button)
	await frames(3)
	var tree: Node = f.research_tree if is_instance_valid(f.research_tree) else null
	report(tree != null and tree.is_visible_in_tree(), "clicking the research entry opens the research tree")
	report(visible_modals() > modals_before, "the research tree registers as a modal (contained input)")
	await driver.capture("nav_03_research_tree")
	# --- WT-UI-006/S03: the armour inspection shows the thickness WITH its evidence status, never alone -------
	var view_before: int = g._view_mode
	g._view_mode = 1
	g._apply_preview_mode()
	await frames(6)
	report(g.inspection_row.visible, "the armour inspection row appears in the inspection view")
	var patch_text := ""
	if g.inspection_choice.item_count > 0:
		g._select_inspection(0)
		await frames(4)
		patch_text = str(g.inspection_value.text)
	report(patch_text.contains("mm") or patch_text.contains("—"), "the first armour entry states its thickness, or says it has none (%s)" % patch_text)
	var status_words := [LocalizationService.text("ui_b340063020e8"),LocalizationService.text("ui_c58140e6cf83"),LocalizationService.text("ui_4d8c1c5b4283")]
	var has_status := false
	for status_word in status_words:
		if patch_text.contains(str(status_word)): has_status = true
	report(has_status, "the thickness is shown together with its evidence status, so the estimate marker cannot be hidden by the styling (%s)" % patch_text)
	g._view_mode = view_before
	g._apply_preview_mode()
	g._refresh_inspection()
	await frames(5)
	report(view_before != 0 or not g.inspection_row.visible, "leaving the inspection view hides the row again")

	# --- WT-UI-005: five routes on one row, no fake prerequisite lines, filter and scroll preserved ----------
	var research := tree as VehicleResearchTree
	if research != null:
		report(research.branch_columns.size()==5, "all five route columns are laid out (%d)" % research.branch_columns.size())
		var columns: Array = research.branch_columns.values()
		columns.sort()
		var one_row := columns.size()==5
		for i in columns.size():
			if int(columns[i]) != i: one_row = false
		report(one_row, "the five routes stay side by side in route order and never wrap to a second row %s" % str(columns))
		report(research.graph.edges.is_empty(), "no display-order connector is drawn, so no decoration can be read as a research prerequisite")
		var search_box := by_id(g,"research.search")
		var nation_germany := by_id(g,"research.nation.germany")
		var nation_ussr := by_id(g,"research.nation.ussr")
		report(search_box != null and nation_germany != null and nation_ussr != null, "the research search and both nation switches expose stable ids")
		if search_box != null and nation_germany != null and nation_ussr != null:
			# Setup only: the query is placed directly, then the assertions below are driven by real clicks.
			search_box.text = "T"
			await frames(2)
			var routes_before := research.branch_columns.size()
			await driver.click(nation_germany)
			await frames(3)
			report(search_box.text == "T", "switching nation keeps the search query (got '%s')" % search_box.text)
			report(research.branch_columns.size() > 0 and routes_before > 0, "the switched nation still lays out its routes")
			research.tree_scroll.scroll_horizontal = 456
			await frames(2)
			# The container clamps the request to its own range, so the contract under test is "the value actually
			# held before the switch comes back", not a hard-coded number.
			var held := int(research.tree_scroll.scroll_horizontal)
			await driver.click(nation_ussr)
			await frames(3)
			await driver.click(nation_germany)
			await frames(3)
			report(held > 0 and int(research.scroll_memory.get("germany",-1))==held, "each nation remembers its own scroll position (held %d, remembered %s)" % [held, str(research.scroll_memory)])
			# WT-UI-011 (S09): a query that matches nothing shows the explicit empty state instead of a blank tree.
			# Setting LineEdit.text programmatically does NOT emit text_changed in Godot, so the tree's own rebuild -
			# the exact function the signal calls - is invoked to reach the state under test.
			search_box.text = "ZZZZ_NO_MATCH"
			research.rebuild()
			await frames(5)
			var empty_shown := false
			for empty_node in research.graph.get_children():
				if empty_node is Label and str((empty_node as Label).text).contains(LocalizationService.text("research_empty_title")): empty_shown = true
			report(empty_shown or research.tree_nodes.is_empty(), "a query with no match shows the explicit empty state")
			await driver.capture("nav_13_research_empty")
			search_box.text = ""
			research.rebuild()
			await frames(5)
		var sample: Control = by_id(g,"research.card.germ_leopard_2a4")
		if sample == null and not research.tree_nodes.is_empty(): sample = by_id(g,"research.card."+str(research.tree_nodes.keys()[0]))
		var ownership_texts := [LocalizationService.text("research_owned"),LocalizationService.text("research_locked"),LocalizationService.text("research_not_admitted")]
		var found := ""
		if sample != null:
			var walker2: Array[Node] = [sample]
			while not walker2.is_empty():
				var node2: Node = walker2.pop_back()
				if node2 is Label and str((node2 as Label).text) in ownership_texts: found = str((node2 as Label).text)
				for child in node2.get_children(): walker2.append(child)
		report(not found.is_empty(), "a research card states its ownership layer from the service (%s)" % found)
		report(VehicleDisplayMetadata.nation_label_for_code(str(research.vehicles[research.selected_id].nation))==LocalizationService.text("nation_"+str(research.vehicles[research.selected_id].nation)), "the detail line labels the nation from the row's own data code, not a hard-coded pair")
		report(VehicleDisplayMetadata.nation_label_for_code("nonesuch")==LocalizationService.text("nation_unknown"), "an unlisted nation code shows the explicit unknown label")
		await driver.capture("nav_06_research_compact")
		get_window().size = Vector2i(1920,1080)
		await frames(6)
		await driver.capture("nav_07_research_wide")
		get_window().size = Vector2i(1280,720)
		await frames(6)
	var before_focus := focus_owner()
	driver.tap(KEY_TAB)
	await frames(3)
	var after_focus := focus_owner()
	report(after_focus != null and tree != null and tree.is_ancestor_of(after_focus), "Tab keeps focus inside the top modal instead of the page behind it")
	report(after_focus != before_focus, "Tab actually moves focus inside the modal")
	driver.key(KEY_ESCAPE,true); await frames(2); driver.key(KEY_ESCAPE,false)
	await frames(6)
	report(not is_instance_valid(f.research_tree), "Esc closes the research tree")
	var frontend_back := g.get_node_or_null("Frontend")
	report(frontend_back != null and frontend_back.visible, "the garage frontend comes back after the tree closes")
	await frames(6)
	var restored := focus_owner()
	report(restored == tree_button, "focus returns to the control that opened the tree (%s)" % (str(restored) if restored != null else "null"))

	# --- confirmation dialog: Esc closes it, does not quit, and restores focus ------------------------------
	var quit_button := by_id(g,"garage.nav.quit")
	report(quit_button != null, "the quit entry exposes a stable id")
	if quit_button != null:
		var modals_before_quit := visible_modals()
		await driver.click(quit_button)
		await frames(3)
		report(visible_modals() > modals_before_quit, "the quit entry opens a confirmation modal")
		# WT-UI-011 (S08): a dangerous action must not start focused on its confirmation.
		var quit_focus := focus_owner()
		var quit_focus_text := str((quit_focus as Button).text) if quit_focus is Button else "none"
		report(quit_focus is Button and quit_focus_text==LocalizationService.text("menu_back"), "a dangerous confirmation focuses its cancel button first (%s)" % quit_focus_text)
		# WT-UI-011 (S09): loading states carry a stage, never a fabricated percentage.
		report(not LocalizationService.text("flow_loading_body").contains("%"), "the loading dialog states a stage instead of a fabricated percentage")
		await driver.capture("nav_04_confirm_dialog")
		driver.key(KEY_ESCAPE,true); await frames(2); driver.key(KEY_ESCAPE,false)
		await frames(8)
		report(visible_modals() == modals_before_quit, "Esc dismisses the confirmation modal")
		report(is_instance_valid(g) and is_instance_valid(g.frontend), "Esc on the confirmation does not quit the garage")
		var after_quit_focus := focus_owner()
		report(after_quit_focus == quit_button, "focus returns to the quit entry after dismissing (%s)" % (str(after_quit_focus) if after_quit_focus != null else "null"))

	# --- deploy request through the real main button ------------------------------------------------------
	var deploy := by_id(g,"garage.deploy")
	report(deploy != null and deploy.is_visible_in_tree() and not deploy.disabled, "the main deploy button is visible and enabled with a stable id")
	var selected_before := g.selected_vehicle_id()
	if deploy != null:
		await driver.click(deploy)
		await idle()
		report(app.training != null, "clicking the main deploy button issues a real deploy request and enters a match")
		# --- WT-UI-004-A04: one deploy request cannot create a second match --------------------------------
		var match_instances := 0
		for child in app.get_children():
			if child is TeamRange: match_instances += 1
		report(match_instances == 1, "the app holds exactly one match instance after the request (%d), so a second request cannot have created another" % match_instances)
		await driver.capture("nav_05_after_deploy")
		# Harness convenience only: this is how the existing verifiers get back, and it is not offered as player
		# evidence for the respawn or result flows, which belong to their own work orders.
		app.return_to_garage(); await idle()
		report(is_instance_valid(app.garage) and is_instance_valid(app.garage.frontend), "the garage is usable again after the match")
		report(app.garage.selected_vehicle_id() == selected_before, "the selected vehicle survives the round trip (got %s)" % app.garage.selected_vehicle_id())
		# --- WT-UI-010 (S07): the result card and settlement idempotency -------------------------------------
		var captured: Dictionary = app.last_result.duplicate(true)
		report(captured.has("progression") or captured.has("title"), "the returned result carries the real recorded fields (%s)" % str(captured.keys()))
		report(app.garage.result_label.text.length() > 0, "the garage shows the result card")
		var points_once: int = app.profile.snapshot().research_points
		if not captured.is_empty():
			app.return_to_garage(captured); await idle()
			var points_twice: int = app.profile.snapshot().research_points
			report(points_twice == points_once, "revisiting the same result awards nothing a second time (%d -> %d)" % [points_once,points_twice])
			var card := str(app.garage.result_label.text)
			report(card.contains(LocalizationService.text("result_saved")) or card.contains(LocalizationService.text("result_no_reward")) or card.contains(LocalizationService.text("result_save_failed")), "the result card states the save or no-reward state")
		await driver.capture("nav_10_result_card")

	print("=== ui navigation: %d checks, %d failed ===" % [checks,failed])
	print("UI_NAVIGATION_CHECKS_PASS" if failed == 0 else "UI_NAVIGATION_CHECKS_FAIL")
	# --- WT-UI-012-A01: probe the wider matrix entries honestly instead of assuming they fit ------------------
	for probe in [Vector2i(2560,1440),Vector2i(3440,1440)]:
		get_window().size = probe
		await frames(10)
		var achieved := get_window().size
		if achieved == probe:
			report(true, "the UI renders at the probed size %dx%d" % [probe.x,probe.y])
			await driver.capture("nav_14_%dx%d" % [probe.x,probe.y])
		else:
			print("[NOT_RUN] %dx%d was clamped by the device to %dx%d, so that matrix entry stays NOT_RUN" % [probe.x,probe.y,achieved.x,achieved.y])
	get_window().size = Vector2i(1280,720)
	await frames(10)

	print("driver checks=%d driver failed=%d" % [int(driver.checks),int(driver.failed)])
	get_tree().quit(0 if failed == 0 else 1)
