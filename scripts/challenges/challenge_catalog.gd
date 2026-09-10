class_name ChallengeCatalog
extends RefCounted
## Authored scenario rules, never overrides armour, damage or gun performance.
const VERSION := 1
const IDS := ["flank_hunter","hold_ground","td_route"]
const LEVELS := ["normal","hard"]
const M4 := "us_m4a3_75w_vvss_1944"
const M36 := "us_m36_m4a1_1945"
static func create(id: String, level: String = "normal") -> Dictionary:
	if id not in IDS or level not in LEVELS: return {}
	var hard := level == "hard"
	var c := {"id":id,"version":VERSION,"difficulty":level,"map":"hill_village","vehicle":M4,
		"rounds":6 if hard else 8,"limit":180.0,"quick":100.0,"economy":3,
		"start":Vector3(-42,0.03,20),"yaw":0.0,"zone":Vector3.ZERO,"radius":12.0,
		"hold":0.0,"route":[],"enemies":[],"enemy_rounds":6 if hard else 4,"title":"","objective":""}
	match id:
		"flank_hunter":
			c.title = LocalizationService.text("ui_5d234d7ff862")
			c.start = Vector3(0,0.03,32)
			c.rounds = 4 if hard else 6
			c.limit = 120.0 if hard else 180.0
			c.quick = 80.0
			c.economy = 2
			c.objective = LocalizationService.text("ui_6e51118c46dd")
			c.enemies = [_enemy("B1",Vector3(0,0.03,-20),PI,false,0)]
		"hold_ground":
			c.title = LocalizationService.text("ui_4ef9c2f6c089")
			c.map = "industrial_edge"
			c.start = Vector3(-78,0.03,100)
			c.zone = Vector3(-78,0,100)
			c.radius = 18.0
			c.hold = 45.0 if hard else 35.0
			c.limit = 150.0 if hard else 210.0
			c.quick = 140.0
			c.enemy_rounds = 12 if hard else 8
			c.objective = LocalizationService.text("ui_915ea832c0d0")
			c.enemies = [_enemy("B1",Vector3(-78,0.03,25),PI,true,0),_enemy("B2",Vector3(-95,0.03,25),PI,true,1)]
			c.enemies[1].alternatives = [Vector3(-95,0.03,50),Vector3(-95,0.03,75)]
		"td_route":
			c.title = LocalizationService.text("ui_67ebfb8035ee")
			c.vehicle = M36
			c.start = Vector3(-72,0.03,116)
			c.rounds = 4 if hard else 6
			c.route = [Vector3(-72,0,50),Vector3(-42,0,20)]
			c.hold = 15.0
			c.limit = 130.0 if hard else 180.0
			c.quick = 100.0
			c.economy = 2
			c.objective = LocalizationService.text("ui_9c10272116ed")
			c.enemies = [_enemy("B1",Vector3(25,0.03,-20),PI,true,0)]
	return c

static func _enemy(id: String, position: Vector3, yaw: float, active: bool, wave: int) -> Dictionary:
	return {"id":id,"position":position,"yaw":yaw,"active":active,"wave":wave,"vehicle":M4}
static func key(config: Dictionary) -> String:
	return "%s:v%d:%s"%[config.id,config.version,config.difficulty]
static func loadout(config: Dictionary, service: GarageService, enemy := false) -> Dictionary:
	var row := service.default_loadout(M4 if enemy else config.vehicle)
	if row.is_empty(): return {}
	for id in row.counts: row.counts[id] = 0
	if not enemy and config.vehicle == M4: row.first_shell = M4+"_m61_m3"
	row.counts[row.first_shell] = int(config.enemy_rounds) if enemy else int(config.rounds)
	return row
static func rules_text(c: Dictionary) -> String:
	var bonus := LocalizationService.text("ui_a1ad5dbb0bce")%c.quick if c.id == "hold_ground" else LocalizationService.text("ui_4a49eadd591d")%[c.economy,c.quick]
	return LocalizationService.text("ui_df55c3aa6d63")%[c.objective,LocalizationService.text("ui_4ea02714a1e9") if c.difficulty == "hard" else LocalizationService.text("ui_6bea77acefb3"),c.limit,c.rounds,"M61 APCBC-HE" if c.vehicle == M4 else "M77 AP",bonus,c.version]
