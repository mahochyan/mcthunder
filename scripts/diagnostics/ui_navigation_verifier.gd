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
		await driver.capture("nav_05_after_deploy")
		# Harness convenience only: this is how the existing verifiers get back, and it is not offered as player
		# evidence for the respawn or result flows, which belong to their own work orders.
		app.return_to_garage(); await idle()
		report(is_instance_valid(app.garage) and is_instance_valid(app.garage.frontend), "the garage is usable again after the match")
		report(app.garage.selected_vehicle_id() == selected_before, "the selected vehicle survives the round trip (got %s)" % app.garage.selected_vehicle_id())

	print("=== ui navigation: %d checks, %d failed ===" % [checks,failed])
	print("UI_NAVIGATION_CHECKS_PASS" if failed == 0 else "UI_NAVIGATION_CHECKS_FAIL")
	print("driver checks=%d driver failed=%d" % [int(driver.checks),int(driver.failed)])
	get_tree().quit(0 if failed == 0 else 1)
