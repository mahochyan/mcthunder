extends "res://tests/run_garage_frontend_checks.gd"

func query(tree: VehicleResearchTree, text: String) -> void:
	tree.search.text=text; tree.rebuild(); await frames()

func run() -> void:
	var args := OS.get_cmdline_user_args(); var index := args.find("--shot-dir")
	if index>=0 and index+1<args.size(): shot_dir=args[index+1]; DirAccess.make_dir_recursive_absolute(shot_dir)
	root.size=Vector2i(1280,720)
	var g := GarageShell.new(); g.profile=ProfileStore.new(""); root.add_child(g); await frames()
	var before := g.profile.snapshot(); var original := g.selected_vehicle_id()
	await click(g.frontend.tree_button)
	var tree: VehicleResearchTree=g.frontend.research_tree
	check(tree.country=="ussr" and tree.tree_nodes.size()==116 and tree.nation_buttons.keys()==["ussr","germany"],"Soviet first, two nations, 116 producer-selected Soviet bases")
	check(tree.preview_control.model_id=="ussr_t_34_1941" and not tree.test_button.disabled,"actual T34 base GLB opens in dossier")
	check(tree.select_button.disabled,"static model cannot bypass combat packet admission")
	check(tree.vehicles.has("ussr_t_80") and tree.vehicles.has("ussr_t_80b"),"light T80 and main battle T80 remain distinct producer families")
	check(not tree.vehicles.has("ussr_t_80u") and not tree.vehicles.has("germ_leopard_2a7v"),"reference variants do not become duplicate tree nodes")
	check(tree.tree_nodes.ussr_t_34_1941.position.x!=tree.tree_nodes.ussr_is_1.position.x and tree.tree_nodes.ussr_is_1.position.x!=tree.tree_nodes.ussr_t_80.position.x,"medium, heavy and light tanks use distinct parallel columns")
	await click(tree.route_buttons.spaa)
	check(tree.tree_scroll.scroll_horizontal>0,"route shortcut reveals right-hand anti-air branch at 720p")
	await click(tree.route_buttons.medium)
	for dimensions in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=dimensions; await frames()
		check(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(tree.test_button.get_global_rect()) and Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(tree.select_button.get_global_rect()),"both actions remain visible at "+str(dimensions))
		await capture("10_soviet_bases_"+str(dimensions.x))
	root.size=Vector2i(1280,720); await frames()
	await query(tree,"T-80U")
	check(tree.tree_nodes.size()==1 and tree.selected_id=="ussr_t_80b","variant search resolves to exact modeled T80B without creating a T80U model")
	check(tree.preview_control.model_id==tree.selected_id,"dossier model identity follows selected base")
	await capture("11_t80_family_720")
	await click(tree.test_button)
	var trial: ResearchTrialDrive=tree.trial
	check(is_instance_valid(trial) and trial.view.model_id=="ussr_t_80b","test drive loads the selected Soviet base snapshot")
	var origin := trial.vehicle.position
	trial.paused=false; Input.action_press("move_forward")
	for tick in 80: await physics_frame
	Input.action_release("move_forward")
	check(trial.vehicle.position.distance_to(origin)>0.3,"normal forward input moves the selected model in isolated trial")
	trial.paused=true; var stopped := trial.vehicle.position
	for tick in 8: await physics_frame
	check(trial.vehicle.position==stopped,"paused trial freezes movement")
	trial.reset_vehicle(); check(trial.speed==0 and trial.vehicle.position.distance_to(Vector3(0,0.05,0))<0.001,"trial reset restores actual body and speed")
	await capture("12_soviet_model_trial")
	await click(trial.close_button)
	check(not is_instance_valid(tree.trial) and tree.selected_id=="ussr_t_80b","trial return preserves selected family and frees trial scene")
	await query(tree,"BMP-1")
	check(tree.test_button.disabled and not tree.preview_control.visible and tree.preview_control.model_id.is_empty(),"unmodeled base clears previous preview and disables trial")
	await query(tree,"THIS DOES NOT EXIST")
	check(tree.tree_nodes.is_empty() and tree.selected_id.is_empty() and tree.test_button.disabled,"empty search cannot reuse a previously selected model")
	await click(tree.nation_buttons.germany)
	check(tree.tree_nodes.size()==96,"German tree uses exactly 96 producer-selected bases")
	await capture("13_german_bases_720")
	await query(tree,"Leopard 2A7V")
	check(tree.tree_nodes.size()==1 and tree.selected_id=="germ_leopard_2a4","Leopard2 variants fold into producer-designated A4 base")
	check(tree.preview_control.model_id=="germ_leopard_2a4" and not tree.test_button.disabled,"German base has its own actual snapshot preview and trial")
	await capture("14_leopard_family_720")
	await click(tree.test_button); trial=tree.trial
	check(trial.view.model_id=="germ_leopard_2a4","German trial does not substitute Soviet or US model")
	await click(trial.close_button)
	await query(tree,"IRIS SLM FCS")
	check(tree.selected_id=="germ_iris_slm_fcs" and not tree.test_button.disabled,"unarmed support vehicle remains available for model driving")
	check(tree.detail_label.text.contains("初速 缺失") and tree.detail_label.text.contains("无可控武器"),"dossier exposes missing weapon data and the unarmed model contract")
	await click(tree.test_button); trial=tree.trial
	check(trial.weapon_control_status=="none" and not trial.weapon_controls_available,"unarmed support model does not receive invented tank-gun controls")
	await click(trial.close_button)
	await query(tree,"9A33BM3")
	check(tree.detail_label.text.contains("容量 冲突") and tree.detail_label.text.contains("非标准武器机构待适配"),"dossier exposes conflicting cache data and the nonstandard model contract")
	await click(tree.test_button); trial=tree.trial
	check(trial.weapon_control_status=="unavailable_nonstandard" and not trial.weapon_controls_available,"ambiguous missile rig stays drivable without applying conflicting traverse data")
	await click(trial.close_button)
	await query(tree,""); tree.ready_filter.button_pressed=true; await frames()
	check(tree.tree_nodes.size()==int(tree.catalog.models.germany),"ready filter follows frozen published-model inventory")
	var loaded := 0; var rejected: Array=[]
	for row in tree.vehicles.values():
		if row.model is Dictionary:
			if tree.preview_control.show_vehicle(row): loaded+=1
			else: rejected.append(row.id)
	check(rejected.is_empty() and loaded==141,"all 141 frozen base GLBs load with finite geometry: "+str(rejected))
	tree.close(); await frames()
	check(g.selected_vehicle_id()==original and g.profile.snapshot()==before,"browsing and trial never substitute battle selection or mutate player profile")
	check(g.get_node("Frontend").is_visible_in_tree(),"closing tree restores normal garage")
	g.free(); await frames()
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failed])
	print("RESEARCH_TREE_CHECKS_PASS" if failed==0 else "RESEARCH_TREE_CHECKS_FAIL")
	quit(0 if failed==0 else 1)
