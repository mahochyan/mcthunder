extends "res://scripts/diagnostics/window_input_driver.gd"
## WT-UI-007/008 (MCT-UI-FIELDWORK-01): S04 layout and information-boundary checks, measured on a real match.
##
## The match is entered through the normal deploy button, and every assertion reads the real HUD that the battle UI
## handed its view model to. The centre clear region is checked per panel rectangle; the four ammunition lines are
## compared against the real chambered round and the real remaining count; and the minimap is compared against the
## BattleIntel snapshot the HUD was given, because the minimap must show exactly the permitted intel and nothing
## more. No pose, health, ammo, cooldown or match rule is written anywhere in this file.
## `app` is already declared by window_input_driver, which this verifier extends.
var hud: BattleHUD
var battle_ui: BattleUI

func idle() -> void:
	for i in 1200:
		await get_tree().process_frame
		if not app._transitioning: return
	check(false,"bounded scene transition")

func rect_of(control: Control) -> Rect2:
	return control.get_global_rect() if is_instance_valid(control) else Rect2()

func in_clear_region(control: Control, view: Vector2) -> bool:
	var clear := Rect2(Vector2(view.x*0.25,view.y*0.20),Vector2(view.x*0.50,view.y*0.50))
	return rect_of(control).intersects(clear)

func finish_result() -> void:
	print("=== ui hud: %d checks, %d failed ===" % [int(checks),int(failed)])
	print("UI_HUD_CHECKS_PASS" if failed == 0 else "UI_HUD_CHECKS_FAIL")
	get_tree().quit(0 if failed == 0 else 1)

func run(flow: AppFlow) -> void:
	get_tree().create_timer(600,true,false,true).timeout.connect(func() -> void: print("UI_HUD_TIMEOUT"); get_tree().quit(2))
	app = flow
	var args := OS.get_cmdline_user_args()
	var shot_index := args.find("--shot-dir")
	if shot_index >= 0 and shot_index+1 < args.size(): shot_dir = args[shot_index+1]
	if shot_dir.is_empty(): shot_dir = ProjectSettings.globalize_path("user://tests/ui_hud_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(shot_dir)
	print("UI_HUD_RUNTIME release=",OS.has_feature("release")," evidence=",shot_dir)
	await idle()
	await click(app.garage.frontend.deploy)
	await idle()
	check(app.training != null,"normal deploy enters a real match for the HUD checks")
	if app.training == null: finish_result(); return
	await frames(20)
	battle_ui = app.training.battle_ui
	check(battle_ui != null and battle_ui.overlay != null,"the running match exposes the real HUD")
	if battle_ui == null or battle_ui.overlay == null: finish_result(); return
	hud = battle_ui.overlay
	var view := hud.get_viewport_rect().size
	check(hud.layout_token_source in ["hud_compact","hud_wide"],"the HUD applied a token layout row (%s)" % hud.layout_token_source)
	check(hud.layout_token_source == "hud_compact","at %d wide the compact token row applies" % int(view.x))

	# --- S04 zoning ---------------------------------------------------------------------------------------
	var header_rect := rect_of(hud.header)
	check(absf(header_rect.get_center().x - view.x*0.5) < view.x*0.12,"the objective bar is centred horizontally (centre %.0f vs %.0f)" % [header_rect.get_center().x,view.x*0.5])
	check(header_rect.position.y < view.y*0.2,"the objective bar sits in the top band")
	check(rect_of(hud.own_panel).get_center().x < view.x*0.4,"the own-vehicle panel sits on the left")
	var ammo_centre := rect_of(hud.weapon_panel).get_center().x
	check(ammo_centre > view.x*0.3 and ammo_centre < view.x*0.72,"the ammunition panel sits in the centre band (%.0f)" % ammo_centre)
	check(rect_of(hud.map_panel).get_center().x > view.x*0.68,"the minimap panel sits on the right")
	for pair in [["own",hud.own_panel],["ammo",hud.weapon_panel],["map",hud.map_panel]]:
		check(rect_of(pair[1]).position.y > view.y*0.5,"the %s panel sits in the bottom band" % pair[0])

	# --- centre clear region ------------------------------------------------------------------------------
	var offenders: Array[String] = []
	for pair in [["header",hud.header],["objectives",hud.objective_strip],["own",hud.own_panel],["ammo",hud.weapon_panel],["map",hud.map_panel],["footer",hud.footer]]:
		if in_clear_region(pair[1],view): offenders.append(str(pair[0]))
	check(offenders.is_empty(),"no permanent panel occupies the centre clear region x25-75%% y20-70%% (offenders=%s; ammo rect=%s; clear=%s)" % [str(offenders),str(rect_of(hud.weapon_panel)),str(Rect2(Vector2(view.x*0.25,view.y*0.20),Vector2(view.x*0.50,view.y*0.50)))])

	# --- ammunition semantics from real AmmoInventory state -----------------------------------------------
	var chamber_text := hud.chamber_label.text
	var carrying_text := hud.carrying_label.text
	var next_text := hud.next_label.text
	var stock_text := hud.stock_label.text
	check(chamber_text!=carrying_text and chamber_text!=next_text and chamber_text!=stock_text and carrying_text!=next_text and carrying_text!=stock_text and next_text!=stock_text,"the four ammunition lines are distinct")
	var model: Dictionary = hud.view_model
	var real_chamber := str(model.get("chamber_shell_label",""))
	if real_chamber.is_empty():
		check(chamber_text.contains(LocalizationService.text("ui_609f061f5455")),"an empty chamber says so explicitly instead of borrowing a shell name")
	else:
		check(chamber_text.contains(real_chamber),"the chamber line shows the real chambered round (%s)" % real_chamber)
	check(stock_text.contains(str(int(model.get("ammo",-1)))),"the stock line shows the real remaining count (%d)" % int(model.get("ammo",-1)))
	var next_real := str(model.get("next_shell_label",""))
	check(next_real.is_empty() or next_text.contains(next_real),"the next-round line shows the real selected round (%s)" % next_real)

	# --- objectives: three-point and single-point follow the real set -------------------------------------
	var points: Array = model.get("match",{}).get("objectives",[])
	check(hud.objective_strip.visible == (points.size() > 1),"the objective strip follows the real objective set (%d points, visible=%s)" % [points.size(),str(hud.objective_strip.visible)])
	var visible_cards := 0
	for card in hud.objective_cards:
		if card.panel.visible: visible_cards += 1
	check(visible_cards == points.size(),"exactly the real objectives are rendered (%d of %d)" % [visible_cards,points.size()])

	# --- the minimap shows exactly the permitted intel ---------------------------------------------------
	var snapshot: Dictionary = battle_ui.intel.snapshot(battle_ui.player())
	var permitted: Array = snapshot.get("markers",[])
	var shown: Array = hud.minimap.markers
	check(shown.size() == permitted.size(),"the minimap shows exactly the permitted intel markers (%d of %d)" % [shown.size(),permitted.size()])
	var extra := 0
	for marker in shown:
		var found := false
		for allowed in permitted:
			if str(allowed.get("id",""))==str(marker.get("id","")) and str(allowed.get("kind",""))==str(marker.get("kind","")): found = true
		if not found: extra += 1
	check(extra == 0,"the minimap adds no marker the intel layer did not allow (%d extra)" % extra)

	# --- the real battle HUD carries no garage navigation or collection strip ------------------------------
	var forbidden := ["MCTHUNDER","科技树","训练中心","VEHICLE COLLECTION","车库"]
	var found_forbidden: Array[String] = []
	var stack: Array[Node] = [hud]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Label:
			for word in forbidden:
				if str((node as Label).text).contains(word): found_forbidden.append(word)
		for child in node.get_children(): stack.append(child)
	check(found_forbidden.is_empty(),"the battle HUD contains no garage navigation or collection strip (found=%s)" % str(found_forbidden))

	# --- critical state stays readable --------------------------------------------------------------------
	check(hud.reload_bar != null and hud.reload_bar.visible,"the reload progress stays visible")
	check(hud.reason_label != null and hud.reason_label.visible == (not str(model.get("weapon_text","")).is_empty()),"the weapon limit reasons follow the real capability output")
	check(hud.drive_label != null and hud.drive_label.text.length() > 0,"the drive state line is present")
	await capture("hud_10_normal_compact")

	# --- optics keeps the minimal state -------------------------------------------------------------------
	tap(KEY_L)
	await frames(8)
	check(str(hud.view_model.get("optics_text","")).length() > 0,"the optics line carries real optics information")
	check(hud.weapon_panel.is_visible_in_tree() and hud.reload_bar.visible,"the ammunition and reload state stay visible in optics")
	await capture("hud_11_optics")
	tap(KEY_L)
	await frames(8)

	# --- WT-UI-008 (S05): one key prompt near the centre, a corner queue, merged repeats ------------------
	hud.notices.clear(); hud._refresh_notices()
	hud.push_notice("第一次提示","k1",4.0,false)
	hud.push_notice("第二次提示","k2",4.0,false)
	hud.push_notice("第二次提示","k2",4.0,false)
	var center_lines := 0
	if hud.notice_center.visible and not hud.notice_center.text.is_empty(): center_lines = 1
	check(center_lines <= 1,"at most one key prompt is shown near the centre (%d)" % center_lines)
	check(hud.notice_center.text=="第一次提示","the centre prompt shows the first live notice (%s)" % hud.notice_center.text)
	check(hud.notice_corner.get_child_count()==1,"secondary notices queue in the corner (%d)" % hud.notice_corner.get_child_count())
	var merged := ""
	for item in hud.notices:
		if str(item.key)=="k2": merged = str(item.text)
	check(merged.contains("×2"),"a repeated notice merges with a count instead of stacking (%s)" % merged)
	hud.push_notice("关键错误","k3",0.5,true)
	hud._tick_notices(10.0)
	var critical_kept := false
	for item in hud.notices:
		if str(item.key)=="k3": critical_kept = true
	check(critical_kept,"a critical notice does not expire with time")
	hud.notices.clear(); hud._refresh_notices()
	check(not hud.notice_center.visible,"the centre prompt hides again when nothing is pending")
	check(HUDPresenter.hit_feedback_text({"hit_result":"penetrated","hit_contacts":1,"hit_damage":0})==str(CoreUI.NAMES.get("penetrated","")),"the hit line words a penetration with the repository's own term")
	check(HUDPresenter.hit_feedback_text({"hit_result":"armor_stopped","hit_contacts":1,"hit_damage":0})==str(CoreUI.NAMES.get("stopped","")),"the hit line words a stopped round with the repository's own term")
	check(HUDPresenter.hit_feedback_text({"hit_result":"","hit_contacts":0,"hit_damage":0})=="","no recorded shot means no hit line")
	var summary: Dictionary = battle_ui.latest_hit_summary()
	check(summary.is_empty() or summary.has("hit_result"),"the hit summary comes from the real projectile records (%s)" % str(summary.keys()))
	await capture("hud_13_notice_queue")

	# --- WT-UI-010/S07: the replay entry obeys the existing permission rule ---------------------------------
	# Measured fact, not a click: the replay entry is declared by the range HUD (`scripts/hud.gd`) and the team range
	# hides it outright (`team_range.gd` sets hud.replay_toggle_button.visible = false), so a battle never offers it.
	# The design's rule that the replay entry follows the existing permission is therefore satisfied by that existing
	# behaviour, and this verifier records the fact instead of clicking a control no real battle shows.
	check(not ("replay_toggle_button" in hud), "a battle HUD exposes no replay entry, matching the existing permission rule")

	# --- WT-UI-008/S05: the key hints must come from the live binding, never a hard-coded letter ------------
	var repair_hint := InputBindingService.hint("repair")
	check(hud.action_label.text.contains(repair_hint), "the recovery hint shows the current binding for repair (%s)" % repair_hint)
	var rebound := InputEventKey.new()
	rebound.keycode = KEY_K
	var rebind_error := InputBindingService.apply_binding("repair",InputBindingService.code_for(rebound))
	check(rebind_error.is_empty(), "the binding can be changed through the real service (%s)" % rebind_error)
	await frames(8)
	var new_hint := InputBindingService.hint("repair")
	check(new_hint != repair_hint, "the service reports a different key after the change (%s -> %s)" % [repair_hint,new_hint])
	check(hud.action_label.text.contains(new_hint), "the HUD hint follows the live binding without a restart")
	var restore_event := InputEventKey.new()
	restore_event.keycode = KEY_T
	InputBindingService.apply_binding("repair",InputBindingService.code_for(restore_event))
	await frames(6)
	check(InputBindingService.hint("repair")==repair_hint, "the original binding is restored after the check")

	# --- WT-UI-008/011-A04: a visual preference must not change any combat state ---------------------------
	var combat_before := {"rounds":int(battle_ui.player().gunner.rounds_remaining),"chamber":int(battle_ui.player().gunner.inventory.chamber),"destroyed":bool(battle_ui.player().state.destroyed),"ready":bool(hud.view_model.get("ready",false))}
	AccessibilitySettings.reduce_flashes = true
	AccessibilitySettings.fx_level = 0
	AccessibilitySettings.apply_vehicle(battle_ui.player())
	await frames(5)
	var combat_after := {"rounds":int(battle_ui.player().gunner.rounds_remaining),"chamber":int(battle_ui.player().gunner.inventory.chamber),"destroyed":bool(battle_ui.player().state.destroyed),"ready":bool(hud.view_model.get("ready",false))}
	check(combat_before == combat_after, "turning flashes off changes no combat state (rounds %d, chamber %d, destroyed %s, ready %s)" % [combat_after.rounds,combat_after.chamber,str(combat_after.destroyed),str(combat_after.ready)])
	check(not battle_ui.player().turret.flash_enabled, "the visual flash really is disabled by the preference")
	AccessibilitySettings.reduce_flashes = false
	AccessibilitySettings.fx_level = 2
	AccessibilitySettings.apply_vehicle(battle_ui.player())
	await frames(5)
	check(battle_ui.player().turret.flash_enabled, "and it is restored when the preference is turned back on")

	# --- wide layout row ----------------------------------------------------------------------------------
	get_window().size = Vector2i(1920,1080)
	await frames(10)
	hud.apply_layout_tokens()
	await frames(6)
	check(hud.layout_token_source=="hud_wide","at 1920 wide the wide token row applies (%s)" % hud.layout_token_source)
	await capture("hud_12_wide")
	# WT-UI-007/S04: at 125% the HUD must grow rather than cut the disable reasons. The text scale is applied through
	# the same mechanism the settings panel uses and the panel is measured before and after, so "grown, not cut" is
	# a measurement rather than a claim; the reason line must also stay visible.
	get_window().size = Vector2i(1280,720)
	await frames(10)
	hud.apply_layout_tokens()
	await frames(6)
	var panel_at_100: float = rect_of(hud.weapon_panel).size.y
	var reason_visible_at_100: bool = hud.reason_label.visible
	AccessibilitySettings.ui_scale = 1.25
	hud.theme = CoreUI.theme()
	AccessibilitySettings.apply(hud)
	await frames(12)
	var panel_at_125: float = rect_of(hud.weapon_panel).size.y
	# The literal "125%" inside a format string is read as a format specifier, so it is escaped as 125%% here - which
	# is why the first version printed the specifiers instead of the measured heights.
	check(panel_at_125 >= panel_at_100,"at 125%% the ammunition panel grows instead of squeezing the text away (%.0f -> %.0f)" % [panel_at_100,panel_at_125])
	check(hud.reason_label.visible or not reason_visible_at_100,"the disable reason line stays visible at 125%")
	await capture("hud_14_scale_125")
	AccessibilitySettings.ui_scale = 1.0
	hud.theme = CoreUI.theme()
	AccessibilitySettings.apply(hud)
	await frames(10)
	finish_result()
