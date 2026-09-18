class_name CrewDamageProfile
extends RefCounted
## MCT-COMBAT-DEEPEN-01 CD08: a VERSIONED crew condition, introduced beside the legacy boolean rather than replacing it.
##
## The work order asks for three things this file exists to answer:
##   1. injury, station and availability are different things, so a condition replaces "alive is a boolean" for reading
##      while the legacy `alive` field stays present and keeps its old meaning for anything that already reads it;
##   2. the thresholds here are PROJECT DESIGN INITIAL VALUES for this engineering version. They are not measured, they are
##      not taken from any external title, and the work order explicitly forbids presenting an unverified penalty rate as
##      external truth, so no condition in this version reduces ability at all;
##   3. a legacy record migrates under a named version and can be rolled back, which is what the sixth acceptance case asks.

## Current version of the condition vocabulary and the migration that produces it.
const VERSION := "cd008-crew-condition-v1"
## The version a record written before this order is understood to be in.
const LEGACY_VERSION := "legacy-alive-v0"

## The three project conditions, from least to most severe. Only the last one removes a person from duty in this version.
const CONDITION_HEALTHY := "healthy"
const CONDITION_LIGHT := "light"
const CONDITION_SERIOUS := "serious"
const CONDITION_INCAPACITATED := "incapacitated"
const CONDITIONS := [CONDITION_HEALTHY, CONDITION_LIGHT, CONDITION_SERIOUS, CONDITION_INCAPACITATED]

## Project design initial values, declared as such. Severity at or above a threshold yields that condition.
const SEVERITY_THRESHOLD := {CONDITION_LIGHT:1, CONDITION_SERIOUS:2, CONDITION_INCAPACITATED:3}
## Availability is separated from condition so that a future mode can decide penalties explicitly. In THIS version only
## incapacitation removes a person from duty, and no middle penalty is applied anywhere.
const AVAILABLE_WHEN := {CONDITION_HEALTHY:true, CONDITION_LIGHT:true, CONDITION_SERIOUS:true, CONDITION_INCAPACITATED:false}

static func condition_for(severity: int) -> String:
	var out := CONDITION_HEALTHY
	for condition in CONDITIONS:
		if severity >= int(SEVERITY_THRESHOLD.get(condition,999)):
			out = condition
	return out

## Availability, kept deliberately separate from the condition string so that the two can never be conflated.
static func is_available(condition: String) -> bool:
	return bool(AVAILABLE_WHEN.get(condition,true))

static func is_incapacitated(condition: String) -> bool:
	return condition == CONDITION_INCAPACITATED

static func validate(condition: String) -> Array:
	if condition.is_empty(): return ["crew condition: missing"]
	if condition not in CONDITIONS: return ["crew condition: unsupported; the vocabulary is versioned"]
	return []

## A fresh, versioned person record. `alive` is retained and derived, so a legacy reader sees exactly what it saw before.
static func fresh_person(original_role: String) -> Dictionary:
	return {"alive":true, "condition":CONDITION_HEALTHY, "condition_version":VERSION,
		"condition_severity":0, "original_role":original_role}

## Migrate a record written before this order into the versioned vocabulary, and report what was migrated so the change is
## auditable. The legacy meaning is preserved exactly: alive false becomes incapacitated, alive true becomes healthy.
static func migrate_legacy(people: Dictionary) -> Dictionary:
	var migrated := {}
	var entries: Array = []
	for key in people.keys():
		var old: Dictionary = people[key] if people[key] is Dictionary else {}
		var was_alive := bool(old.get("alive",true))
		var person := old.duplicate(true)
		if not person.has("condition"):
			person["condition"] = CONDITION_HEALTHY if was_alive else CONDITION_INCAPACITATED
			person["condition_severity"] = 0 if was_alive else int(SEVERITY_THRESHOLD[CONDITION_INCAPACITATED])
			person["condition_version"] = VERSION
			entries.append({"person":key,"from":LEGACY_VERSION,"to":VERSION,"alive":was_alive})
		person["alive"] = not is_incapacitated(str(person.get("condition","")))
		migrated[key] = person
	return {"version":VERSION, "from_version":LEGACY_VERSION, "people":migrated, "migrated":entries}

## The rollback: back to the legacy shape, which is exactly the boolean a previous reader expects.
static func rollback_to_legacy(people: Dictionary) -> Dictionary:
	var out := {}
	for key in people.keys():
		var person: Dictionary = people[key] if people[key] is Dictionary else {}
		var reverted := {"alive":bool(person.get("alive",true)), "original_role":str(person.get("original_role",""))}
		out[key] = reverted
	return {"version":LEGACY_VERSION, "rolled_back_from":VERSION, "people":out}
