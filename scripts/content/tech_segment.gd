class_name TechSegment
extends RefCounted
## WT-029: the first-release technology segment, frozen as data with honest pools.
##
## Frozen facts of this repository (measured, not assumed):
##  * the content tree holds USSR and Germany rows only - there is no M1A1 and no ZTZ-99A
##    reference entry anywhere.
##  * `assets/vehicles/m1a1/m1a1.glb` exists as an isolated LOD study that was never
##    integrated into the game asset library, so M1A1 has assets but no reference entry.
##  * the two pilots (`ussr_t_80b`, `germ_leopard_2a4`) have reference entries and frozen
##    models, but neither is combat-admitted.
## Therefore the first-release combat pool stays the four admitted historical vehicles, the
## modern pilots sit in an explicitly experimental pool, and M1A1/ZTZ-99A are deferred with
## named blockers instead of being forced into a competitive segment.

const SEGMENT_ID := "first_release_main"
const SEGMENT_VERSION := 1
## No human feedback exists yet, so the experience gate stays pending.
const EXPERIENCE_GATE := "PENDING"
const POOL_FIRST_RELEASE := "first_release"
const POOL_EXPERIMENTAL := "experimental"
const POOL_DEFERRED := "deferred"

const POOLS := {
	"first_release":["us_m4a3_75w_vvss_1944","us_m24_m6_t85e1_1951","us_m26_m3_1945","us_m36_m4a1_1945"],
	"experimental":["ussr_t_80b","germ_leopard_2a4"],
	"deferred":["us_m1a1_abrams","cn_ztz_99a"],
}

## Facts (from configurations and repository state) are kept apart from tuning values.
const FACTS := {
	"ussr_t_80b":{"ready_rounds":28,"reserve_rounds":10,"crew":3,"has_loader":false,
		"night_vision":true,"thermal":true,"reference_entry":"assets/reference_data/candidates/ussr_t_80b.json",
		"model":"assets/research/models/ussr_t_80b.glb","combat_admitted":false},
	"germ_leopard_2a4":{"ready_rounds":15,"reserve_rounds":27,"crew":4,"has_loader":true,
		"night_vision":false,"thermal":true,"reference_entry":"assets/reference_data/candidates/germ_leopard_2a4.json",
		"model":"assets/research/models/germ_leopard_2a4.glb","combat_admitted":false},
	"us_m1a1_abrams":{"reference_entry":"","model":"assets/vehicles/m1a1/m1a1.glb","combat_admitted":false,
		"note":"canonical GLB with import companion present; no reference entry and no packet model_binding"},
	"cn_ztz_99a":{"reference_entry":"","model":"assets/vehicles/ztz99a/ztz99a_1000.glb","combat_admitted":false,
		"note":"canonical GLB with import companion and manifest present; no reference entry and no packet model_binding"},
}
const TUNING := {
	"ussr_t_80b":{"reload_s":5.4,"ready_resupply_s":20.0},
	"germ_leopard_2a4":{"reload_s":6.2,"ready_resupply_s":20.0},
}
const DEFERRED_BLOCKERS := {
	# Corrected by WT-030D-R1: the earlier "unintegrated LOD study" and "no model" claims
	# came from a content grep that cannot see file names. Both vehicles DO have canonical
	# GLBs with import companions; what they lack is a reference entry and a model_binding.
	"us_m1a1_abrams":["no_reference_entry_in_content_tree","dirty_binary_assets_isolated_per_audit","packet_has_no_model_binding"],
	"cn_ztz_99a":["no_reference_entry_in_content_tree","packet_has_no_model_binding"],
}
## Balance levers: matchmaking, mission, spawn resources and map - not a copied rating table.
const LEVERS := [
	{"lever":"matchmaking_pool","value":"four admitted historical vehicles; modern pilots experimental only"},
	{"lever":"mission_objectives","value":"three capture zones (BattleObjectives MAX_POINTS=3)"},
	{"lever":"spawn_resources","value":"tickets 300, death cost 30 (MatchRulePreset team_standard_300@v1)"},
	{"lever":"map","value":"river_junction (large) + village/industrial (4v4)"},
]
const CAPABILITY_DIFFERENCES := [
	{"aspect":"loading","ussr_t_80b":"carousel autoloader, 28 ready + 10 reserve, no loader post",
		"germ_leopard_2a4":"human loader, 15 ready + 27 reserve",
		"counter":"losing power stops the autoloader while a human loader keeps working; the autoloader exhausts its ready rack sooner"},
	{"aspect":"sensors","ussr_t_80b":"thermal and night vision","germ_leopard_2a4":"thermal only",
		"counter":"both channels obey smoke and cover rules, so a night-vision advantage is not a wall-piercing advantage"},
	{"aspect":"crew","ussr_t_80b":"three crew, no loader to injure","germ_leopard_2a4":"four crew, a loader injury stops loading",
		"counter":"the manual loader is more resilient to power loss but vulnerable to crew casualties"},
]
const MUST_HAVE_EQUIPMENT := ["rangefinding","optical_sight","thermal_sight","fire_control_computer"]

static func pool_of(vehicle_id: String) -> String:
	for pool in POOLS:
		if POOLS[pool].has(vehicle_id): return str(pool)
	return "unlisted"

static func in_first_release(vehicle_id: String) -> bool:
	return pool_of(vehicle_id) == POOL_FIRST_RELEASE

static func facts_of(vehicle_id: String) -> Dictionary:
	return (FACTS.get(vehicle_id,{}) as Dictionary).duplicate(true)

static func tuning_of(vehicle_id: String) -> Dictionary:
	return (TUNING.get(vehicle_id,{}) as Dictionary).duplicate(true)

static func factual_fields(vehicle_id: String) -> Array[String]:
	var out: Array[String] = []
	for key in FACTS.get(vehicle_id,{}).keys(): out.append(str(key))
	return out

static func tuning_fields(vehicle_id: String) -> Array[String]:
	var out: Array[String] = []
	for key in TUNING.get(vehicle_id,{}).keys(): out.append(str(key))
	return out

static func is_tuning(field: String) -> bool:
	for vehicle_id in TUNING:
		if TUNING[vehicle_id].has(field): return true
	return false

static func blockers_of(vehicle_id: String) -> Array[String]:
	var out: Array[String] = []
	for blocker in DEFERRED_BLOCKERS.get(vehicle_id,[]): out.append(str(blocker))
	return out

## Promotion is refused while any blocker stands: nothing is silently promoted.
static func promote(vehicle_id: String, target_pool: String) -> Dictionary:
	var blockers := blockers_of(vehicle_id)
	if not blockers.is_empty():
		return {"ok":false,"reason":"blockers_remain","vehicle_id":vehicle_id,"blockers":blockers}
	if not POOLS.has(target_pool): return {"ok":false,"reason":"unknown_pool"}
	if target_pool == POOL_FIRST_RELEASE:
		var facts := facts_of(vehicle_id)
		if not bool(facts.get("combat_admitted",false)):
			return {"ok":false,"reason":"not_combat_admitted","vehicle_id":vehicle_id}
	return {"ok":true,"vehicle_id":vehicle_id,"pool":target_pool}

## Must-have equipment present versus the deferred gaps, per experimental pilot.
static func gap_table() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for vehicle_id in POOLS[POOL_EXPERIMENTAL]:
		var present: Array[String] = []
		var missing: Array[String] = []
		for equipment in MUST_HAVE_EQUIPMENT:
			if ModernEquipment.is_equipped(vehicle_id,equipment): present.append(equipment)
			else: missing.append(equipment)
		var deferred: Array[String] = []
		for row in ModernEquipment.unimplemented_list(): deferred.append(str(row.equipment))
		var smoke: Variant = SupportActions.capability_for(vehicle_id).get("smoke")
		out.append({"vehicle_id":vehicle_id,"must_have_present":present,"must_have_missing":missing,
			"deferred_systems":deferred,"smoke_launcher_configured":smoke != null,
			"experience_gate":EXPERIENCE_GATE})
	return out

static func experience_gate() -> String:
	return EXPERIENCE_GATE

static func levers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row in LEVERS: out.append(row.duplicate(true))
	return out

static func snapshot() -> Dictionary:
	return {"segment_id":SEGMENT_ID,"segment_version":SEGMENT_VERSION,"experience_gate":EXPERIENCE_GATE,
		"pools":POOLS.duplicate(true),"facts":FACTS.duplicate(true),"tuning":TUNING.duplicate(true),
		"blockers":DEFERRED_BLOCKERS.duplicate(true),"levers":levers(),
		"differences":CAPABILITY_DIFFERENCES.duplicate(true),"gaps":gap_table(),
		"modern_in_normal_match":false}
