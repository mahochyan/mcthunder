class_name ModernEquipment
extends RefCounted
## WT-028: which modern equipment actually exists, what it depends on, and what it may see.
##
## Encoded rules:
##  * a capability is enabled per vehicle EXPLICITLY; it is never switched on because a
##    vehicle is classified as modern.
##  * the first-release must-have list is frozen: rangefinding, a sight, power and the
##    fire-control dependency.
##  * thermal and night vision are sensor CHANNELS that go through the observation rules,
##    so a thermal sight does not paint every enemy through a wall or through smoke.
##  * power is a real dependency: losing it disables the equipment that needs it, and the
##    reported capability follows immediately.
##  * gameplay sensor limits are policy data and never read display settings, so turning
##    effects off cannot turn the limits off.
##  * warning receivers, radar, active protection and guided/programmable ammunition are
##    declared unimplemented and need their own orders; nothing here pretends otherwise.

const TIERS := ["supported","experimental","unimplemented"]
const MUST_HAVE := ["rangefinding","sight","power","fire_control_dependency"]
const PROVENANCE := "game_rule"

## First-release capability table. Every duration/threshold is a calibratable game rule and
## no historical performance is claimed.
const EQUIPMENT := {
	"rangefinding":{"tier":"experimental","requires_power":false,"sensor_channel":"none","module":"rangefinder",
		"role_capability":"rangefinding","provenance":PROVENANCE},
	"optical_sight":{"tier":"experimental","requires_power":false,"sensor_channel":"optical","module":"optics",
		"role_capability":"sight","provenance":PROVENANCE},
	"thermal_sight":{"tier":"experimental","requires_power":true,"sensor_channel":"thermal","module":"optics",
		"role_capability":"sight","provenance":PROVENANCE},
	"night_vision":{"tier":"experimental","requires_power":true,"sensor_channel":"thermal","module":"optics",
		"role_capability":"sight","provenance":PROVENANCE},
	"fire_control_computer":{"tier":"experimental","requires_power":true,"sensor_channel":"none","module":"fire_control",
		"role_capability":"fire_control_dependency","provenance":PROVENANCE},
	"gun_stabilizer":{"tier":"experimental","requires_power":true,"sensor_channel":"none","module":"turret_drive",
		"role_capability":"fire_control_dependency","provenance":PROVENANCE},
}
## Declared out of scope for the first release; each needs its own order.
const OUT_OF_SCOPE := {
	"laser_warning_receiver":{"tier":"unimplemented","requires_separate_order":true,
		"abstract_rule":"a warning cue only: direction band, never the emitter's identity or internals"},
	"radar":{"tier":"unimplemented","requires_separate_order":true,
		"abstract_rule":"search cue with an explicit range band and an explicit false-positive rule"},
	"active_protection":{"tier":"unimplemented","requires_separate_order":true,
		"abstract_rule":"one bounded interception with its own ammunition and reset rules"},
	"guided_ammunition":{"tier":"unimplemented","requires_separate_order":true,
		"abstract_rule":"a steering rule with a bounded correction window"},
	"programmable_ammunition":{"tier":"unimplemented","requires_separate_order":true,
		"abstract_rule":"a fuse setting that is part of the frozen shot context"},
}
## Equipment is opt-in per vehicle.
const VEHICLES := {
	"ussr_t_80b":{"equipment":["rangefinding","optical_sight","thermal_sight","night_vision","fire_control_computer","gun_stabilizer"],
		"role_requirements":{"gunner":["sight","rangefinding","fire_control_dependency"],"driver":[],"commander":["sight"]}},
	"germ_leopard_2a4":{"equipment":["rangefinding","optical_sight","thermal_sight","fire_control_computer","gun_stabilizer"],
		"role_requirements":{"gunner":["sight","rangefinding","fire_control_dependency"],"driver":[],"commander":["sight","rangefinding"]}},
}

static func equipment_ids() -> Array[String]:
	var out: Array[String] = []
	for id in EQUIPMENT: out.append(id)
	return out

static func tier_of(equipment_id: String) -> String:
	if EQUIPMENT.has(equipment_id): return str(EQUIPMENT[equipment_id].tier)
	if OUT_OF_SCOPE.has(equipment_id): return str(OUT_OF_SCOPE[equipment_id].tier)
	return "unknown"

static func is_equipped(vehicle_id: String, equipment_id: String) -> bool:
	var entry: Dictionary = VEHICLES.get(vehicle_id,{})
	if entry.is_empty(): return false
	return entry.get("equipment",[]).has(equipment_id)

## Availability honours the tier, the per-vehicle opt-in and the power dependency.
static func availability(vehicle_id: String, equipment_id: String, power_ok: bool = true) -> Dictionary:
	if OUT_OF_SCOPE.has(equipment_id):
		return {"ok":false,"reason":"unimplemented","requires_separate_order":true}
	if not EQUIPMENT.has(equipment_id): return {"ok":false,"reason":"unknown_equipment"}
	if not is_equipped(vehicle_id,equipment_id):
		# never enabled by vehicle class: absent means absent
		return {"ok":false,"reason":"not_equipped"}
	if bool(EQUIPMENT[equipment_id].requires_power) and not power_ok:
		return {"ok":false,"reason":"power_lost","tier":str(EQUIPMENT[equipment_id].tier)}
	return {"ok":true,"tier":str(EQUIPMENT[equipment_id].tier),
		"sensor_channel":str(EQUIPMENT[equipment_id].sensor_channel),
		"module":str(EQUIPMENT[equipment_id].module)}

## The capability/module dependency matrix for one vehicle.
static func capability_matrix(vehicle_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for equipment_id in EQUIPMENT:
		var row: Dictionary = EQUIPMENT[equipment_id].duplicate(true)
		row["equipment"] = equipment_id
		row["equipped"] = is_equipped(vehicle_id,equipment_id)
		out.append(row)
	for equipment_id in OUT_OF_SCOPE:
		var row: Dictionary = OUT_OF_SCOPE[equipment_id].duplicate(true)
		row["equipment"] = equipment_id
		row["equipped"] = false
		row["module"] = ""
		row["sensor_channel"] = "none"
		row["requires_power"] = false
		out.append(row)
	return out

## Modules the equipment depends on, so damage can be traced to capability.
static func required_modules(vehicle_id: String) -> Array[String]:
	var out: Array[String] = []
	for equipment_id in EQUIPMENT:
		if not is_equipped(vehicle_id,equipment_id): continue
		var module := str(EQUIPMENT[equipment_id].module)
		if not module.is_empty() and not out.has(module): out.append(module)
	return out

## A role is ready only when every capability it needs is actually available.
static func role_readiness(vehicle_id: String, role: String, power_ok: bool = true) -> Dictionary:
	var entry: Dictionary = VEHICLES.get(vehicle_id,{})
	if entry.is_empty(): return {"ok":false,"ready":false,"reason":"unknown_vehicle"}
	var requirements: Array = entry.get("role_requirements",{}).get(role,[])
	var missing: Array[String] = []
	var have: Array[String] = []
	for capability in requirements:
		var satisfied := false
		for equipment_id in EQUIPMENT:
			if str(EQUIPMENT[equipment_id].role_capability) != capability: continue
			if availability(vehicle_id,equipment_id,power_ok).ok: satisfied = true
		if satisfied: have.append(capability)
		else: missing.append(capability)
	return {"ok":true,"ready":missing.is_empty(),"role":role,"have":have,"missing":missing}

## Thermal and night vision obey the observation rules: a channel attenuates, it does not
## reveal through a wall.
static func sensor_visibility(media: String, channel: String) -> Dictionary:
	var attenuation := ObservationPolicy.attenuation(media,channel)
	var blocked := ObservationPolicy.visual_blocked(media,channel)
	return {"media":media,"channel":channel,"attenuation":attenuation,"blocked":blocked,
		"can_observe":not blocked,
		"note":"a thermal channel has its own smoke rule; a wall blocks both channels"}

## A role is "fully ready" only when every required capability is met by equipment whose
## tier is actually `supported`. With nothing promoted past `experimental` yet, no modern
## role may be reported as fully ready.
static func fully_ready(vehicle_id: String, role: String, power_ok: bool = true) -> Dictionary:
	var entry: Dictionary = VEHICLES.get(vehicle_id,{})
	if entry.is_empty(): return {"ok":false,"fully_ready":false,"reason":"unknown_vehicle"}
	var requirements: Array = entry.get("role_requirements",{}).get(role,[])
	var unsupported: Array[String] = []
	for capability in requirements:
		var met := false
		for equipment_id in EQUIPMENT:
			if str(EQUIPMENT[equipment_id].role_capability) != capability: continue
			if str(EQUIPMENT[equipment_id].tier) != "supported": continue
			if availability(vehicle_id,equipment_id,power_ok).ok: met = true
		if not met: unsupported.append(capability)
	return {"ok":true,"fully_ready":unsupported.is_empty(),"role":role,
		"reason":"no_supported_tier_yet" if not unsupported.is_empty() else "",
		"capabilities_without_supported_equipment":unsupported}

## What the vehicle loses when power fails, so the prompt and the capability agree.
static func power_report(vehicle_id: String, power_ok: bool) -> Dictionary:
	var lost: Array[String] = []
	var kept: Array[String] = []
	for equipment_id in EQUIPMENT:
		if not is_equipped(vehicle_id,equipment_id): continue
		if bool(EQUIPMENT[equipment_id].requires_power) and not power_ok: lost.append(equipment_id)
		else: kept.append(equipment_id)
	return {"vehicle_id":vehicle_id,"power_ok":power_ok,"lost":lost,"kept":kept}

## Gameplay sensor limits are policy data; display settings never enter this module.
static func effects_independent() -> bool:
	return true

static func must_have_list() -> Array[String]:
	var out: Array[String] = []
	for item in MUST_HAVE: out.append(str(item))
	return out

static func unimplemented_list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for equipment_id in OUT_OF_SCOPE:
		out.append({"equipment":equipment_id,"tier":str(OUT_OF_SCOPE[equipment_id].tier),
			"requires_separate_order":bool(OUT_OF_SCOPE[equipment_id].requires_separate_order),
			"abstract_rule":str(OUT_OF_SCOPE[equipment_id].abstract_rule)})
	return out

static func snapshot(vehicle_id: String, power_ok: bool = true) -> Dictionary:
	return {"vehicle_id":vehicle_id,"provenance":PROVENANCE,"must_have":must_have_list(),
		"equipment":capability_matrix(vehicle_id),"modules":required_modules(vehicle_id),
		"gunner":role_readiness(vehicle_id,"gunner",power_ok),
		"power":power_report(vehicle_id,power_ok),
		"unimplemented":unimplemented_list(),
		"effects_independent":effects_independent(),
		"historical_values_claimed":false}
