class_name ChallengeBattleUI
extends BattleUI
func setup(scene: Node3D) -> void:
	super.setup(scene)
	var map: Dictionary = scene.map_definition.minimap()
	overlay.minimap.world_rect = map.bounds
	overlay.minimap.obstacles.assign(map.obstacles)
	overlay.minimap.roads = map.get("roads",{})
	overlay.minimap.has_point = scene.config.id != "flank_hunter"
	overlay.minimap.point_position = scene.config.zone
	overlay.minimap.point_radius = scene.config.radius
	overlay.map_title.text = map.title+LocalizationService.text("ui_514a46f11053")
func phase() -> String: return battle.director.phase
func elapsed() -> float: return battle.director.elapsed
func match_info() -> Dictionary:
	var director: ChallengeDirector = battle.director
	var objective := director.progress_text()
	if director.phase == "countdown": objective = battle.config.objective
	if director.contested(): objective += LocalizationService.text("ui_1a8822280e44")
	if director.phase == "finished": objective = LocalizationService.text("ui_28688dd37f2e")
	return {"phase":phase(),"remaining":maxf(0,battle.config.limit-elapsed()),"countdown":director.countdown_left,"team_mode":false,"title":battle.config.title,"objective":objective,"tickets_text":LocalizationService.text("ui_37da81c9afe2")%(LocalizationService.text("ui_4ea02714a1e9") if battle.difficulty == "hard" else LocalizationService.text("ui_6bea77acefb3"))}
func roster() -> Array:
	var rows: Array = []
	for vehicle in battle.combat_actors(): rows.append({"id":vehicle.entity_id,"friendly":vehicle == player(),"deaths":int(vehicle.state.destroyed)})
	return rows
func _process(delta: float) -> void:
	super._process(delta)
	if battle.config.id == "flank_hunter":
		for vehicle in battle.combat_actors():
			if vehicle != player(): vehicle.label3d.text = LocalizationService.text("ui_f40145027897")+vehicle.entity_id
	if battle.config.id == "td_route":
		var d: ChallengeDirector = battle.director
		overlay.minimap.point_position = battle.config.route[d.checkpoint] if d.checkpoint < battle.config.route.size() else battle.config.zone
		overlay.minimap.point_radius = 8.0 if d.checkpoint < battle.config.route.size() else battle.config.radius
