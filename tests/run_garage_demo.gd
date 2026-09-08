extends "res://tests/run_historical_demo.gd"
## Public UI only. No direct unlock, loadout mutation, actor damage, cooldown or score edits.
var flow_complete := false

func choose(control: OptionButton, index: int) -> void:
	await click(control); await tap(KEY_HOME)
	for step in index+1: await tap(KEY_DOWN)
	await tap(KEY_ENTER)

func quantity(spin: SpinBox, value: int) -> void:
	await click(spin.get_line_edit())
	var select_all := InputEventKey.new(); select_all.keycode = KEY_A; select_all.ctrl_pressed = true; select_all.pressed = true
	Input.parse_input_event(select_all); await frames(2)
	select_all = select_all.duplicate(); select_all.pressed = false; Input.parse_input_event(select_all)
	for digit in str(value):
		var typed := InputEventKey.new(); typed.keycode = KEY_0+int(digit); typed.unicode = digit.unicode_at(0); typed.pressed = true
		Input.parse_input_event(typed); await frames(2); typed = typed.duplicate(); typed.pressed = false; Input.parse_input_event(typed)
	await tap(KEY_ENTER)
	check(int(spin.value)==value,"normal numeric entry sets requested ammunition quantity")

func run(flow: AppFlow) -> void:
	app = flow
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i]=="--shot-dir" and i+1<args.size(): shot_dir=args[i+1]
	if shot_dir.is_empty(): shot_dir=ProjectSettings.globalize_path("res://docs/evidence/022/wip")
	DirAccess.make_dir_recursive_absolute(shot_dir)
	await frames(30)
	check(app.garage.start_button.get_global_rect().end.y<700 and find_button(app.garage,"4 对 4 占点").get_global_rect().end.y<700,"both launch actions remain visible without scrolling")
	await capture("00_garage_cards")
	await click(find_button(app.garage,"M26\n重型 / 中型"))
	var prep := app.garage.preparation
	await choose(prep.mode_choice,1)
	check(prep.mode()=="normal" and prep.research_button.disabled and prep.research_label.text.contains("M36"),"normal mode visibly requires M36 before M26 research")
	await capture("01_research_dependency")
	await click(find_button(app.garage,"M24\n轻型"))
	await click(prep.research_button)
	check(app.profile.snapshot().research_points==20 and VehicleCatalog.IDS[1] in app.profile.snapshot().unlocked,"real research button spends initial 80 points and unlocks M24")
	await capture("02_researched_m24")
	await click(app.garage.inspect_button)
	var side_index := -1
	for i in app.garage.inspection_choice.item_count:
		if app.garage.inspection_choice.get_item_metadata(i).id=="hull_left": side_index=i
	await choose(app.garage.inspection_choice,side_index)
	check(app.garage.preview.selected_patch_id=="hull_left" and app.garage.inspection_value.text.contains("mm"),"normal armor selector highlights the side plate and displays its nominal thickness")
	await capture("02b_side_armor")
	await click(app.garage.inspect_button)
	var crew_index := -1
	for i in app.garage.inspection_choice.item_count:
		if app.garage.inspection_choice.get_item_metadata(i).kind=="crew": crew_index=i; break
	await choose(app.garage.inspection_choice,crew_index)
	check(app.garage.inspection_value.text.contains("乘员位置盒为估算"),"normal interior selector identifies crew position as estimated geometry")
	await capture("02c_crew_location")
	await click(prep.settings_button)
	var m24: String = VehicleCatalog.IDS[1]
	var m24_keys: Array = prep.shell_spins.keys()
	await quantity(prep.shell_spins[m24_keys[0]],2)
	await quantity(prep.shell_spins[m24_keys[1]],3)
	await choose(prep.first_choice,1)
	var ancestor := prep.get_parent()
	while ancestor != null and not ancestor is ScrollContainer: ancestor = ancestor.get_parent()
	check(ancestor!=null and not ancestor.get_h_scroll_bar().visible and prep.shell_spins.values().all(func(spin: SpinBox) -> bool: return spin.get_global_rect().end.x <= ancestor.get_global_rect().end.x),"ammunition controls fit horizontally without a hidden right edge")
	check(prep.loadouts[m24].counts[m24_keys[0]]==2 and prep.loadouts[m24].counts[m24_keys[1]]==3 and prep.loadouts[m24].first_shell==m24_keys[1],"two ammunition quantities and first shell follow actual controls")
	await capture("03_m24_loadout")
	await click(find_button(app.garage,"M4A3\n中型"))
	var m4: String = VehicleCatalog.IDS[0]
	var m4_keys: Array = prep.shell_spins.keys()
	await quantity(prep.shell_spins[m4_keys[0]],1)
	await quantity(prep.shell_spins[m4_keys[1]],0)
	check(app.garage._view_mode==2 and prep.store.service.build_loadout(prep.loadouts[m4]).inventory.racks.keys().all(func(id: String) -> bool: return not app.garage.preview._module_nodes[id].visible),"single chamber load visibly empties all M4 ammo racks")
	await capture("04_empty_racks")
	await click(find_button(app.garage,"M24\n轻型"))
	await click(app.garage.dossier_button)
	check(find_button(app.garage,"关闭资料档案")!=null,"selected variant dossier remains accessible after research and loadout edits")
	await capture("05_variant_dossier")
	await click(find_button(app.garage,"关闭资料档案"))
	await click(find_button(app.garage,"保存战前设置"))
	check(app.profile.snapshot().garage.loadouts[m24]==prep.loadouts[m24],"normal save button persists selected manifest")
	var confirmed := prep.build_match().config as MatchConfig
	await click(find_button(app.garage,"4 对 4 占点")); await frames(200)
	var battle := app.training as TeamRange
	check(battle!=null and battle.team_ready,"public battle button launches configured normal match")
	if battle==null: finish(); return
	check(battle.actor.definition.id==m24 and battle.actor.gunner.inventory.shell_counts()==confirmed.loadout(m24).counts and battle.actor.gunner.inventory.chamber_shell==m24_keys[1],"M24 spawns with exact selected typed ammo and first shell")
	check(battle.actor.gunner.shots_fired==0,"launch click cannot leak a shot")
	await capture("06_battle_m24")
	mouse(MOUSE_BUTTON_LEFT,true); await frames(3); mouse(MOUSE_BUTTON_LEFT,false); await frames(15)
	check(battle.actor.gunner.shots_fired==1 and battle.actor.gunner.rounds_remaining==4,"normal mouse fire consumes exactly the configured first round")
	await capture("07_first_shell_fired")
	await tap(KEY_ESCAPE); await click(find_button(battle.hud,"放弃当前车（扣30票）")); await frames(500)
	check(battle.actor.state.destroyed and battle.waiting_panel.visible,"normal abandon action reaches natural respawn wait")
	var m4_index := -1
	for i in battle.vehicle_choice.item_count:
		if battle.vehicle_choice.get_item_metadata(i)==m4: m4_index=i
	await choose(battle.vehicle_choice,m4_index)
	await capture("08_lineup_respawn")
	await click(battle.respawn_button); await frames(20)
	check(battle.actor.definition.id==m4 and not battle.actor.state.destroyed and battle.actor.gunner.rounds_remaining==1,"normal respawn chooses M4 with its own single-round manifest")
	await capture("09_battle_m4")
	await tap(KEY_ESCAPE); await click(battle.hud._training_btn); await frames(20)
	check(is_instance_valid(app.garage) and app.profile.snapshot().research_points==20 and app.last_result.progression.points==0,"normal early return preserves 20 points and records zero reward")
	check(app.garage.preparation.loadouts[m4]==confirmed.loadout(m4) and app.garage.preparation.loadouts[m24]==confirmed.loadout(m24),"return restores both actual vehicle configurations")
	await capture("10_returned_garage")
	var old_token := app.match_token
	await click(find_button(app.garage,"4 对 4 占点")); await frames(200)
	battle = app.training as TeamRange
	check(battle!=null and app.match_token!=old_token,"second public match receives a distinct registered identity")
	if battle==null: finish(); return
	# Observe a complete production match. Player remains parked; AI, capture, tickets and timeout run normally.
	for second in 605:
		if battle.director.state.phase=="finished": break
		await frames(60)
		if second%60==0: print("[MATCH_PROGRESS] simulated_seconds=",battle.director.state.elapsed," tickets=",battle.director.state.tickets)
	check(battle.director.state.phase=="finished" and battle.director.state.result.outcome!="abandoned","actual AI match reaches natural ticket or time-limit completion")
	if battle.director.state.phase!="finished": finish(); return
	var award: int = ProgressionService.REWARDS[battle.director.state.result.outcome]
	check(app.profile.snapshot().research_points==20+award and battle.result_text.text.contains("研发点 +"+str(award)),"natural result panel and persisted balance show the actual earned award")
	await capture("11_completed_match_reward")
	await click(battle.return_button); await frames(20)
	check(app.profile.snapshot().research_points==20+award and app.garage.result_label.text.contains("研发点 +"+str(award)),"returning from completed result does not award a second time")
	await capture("12_persisted_reward")
	flow_complete=true
	finish()

func finish() -> void:
	check(flow_complete,"complete normal garage-research-loadout-battle-respawn-return flow")
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failed])
	if failed==0: print("GARAGE_DEMO_CHECKS_PASS")
	get_tree().quit(0 if failed==0 else 1)
