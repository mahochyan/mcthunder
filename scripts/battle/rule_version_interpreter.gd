class_name RuleVersionInterpreter
extends RefCounted
## MCT-COMBAT-DEEPEN-01 CD14: read a stored match result BY THE RULE VERSION THAT PRODUCED IT.
##
## The sixth case asks for exactly two things: a historical result is explained by its own rule version, and an UNKNOWN
## version is explicitly migrated or refused rather than being silently reinterpreted under today's rules. This file does
## that and nothing else - it is not a migration engine and it does not invent a rule set for a version it does not know.

const KNOWN := {
	1: "team_standard_300",
	2: "ground_rb_like_v1",
}
const MIGRATABLE := [1]

static func known_versions() -> Array:
	var out: Array = []
	for v in KNOWN.keys(): out.append(int(v))
	out.sort()
	return out

## Explain a stored result under its own version. A known version returns the rule set that produced it; an unknown one is
## REFUSED BY NAME, and a version that can be migrated says so instead of pretending the numbers are current.
static func interpret(stored: Dictionary) -> Dictionary:
	if not stored is Dictionary: return {"ok":false,"reason":"stored_result_malformed","action":"refuse"}
	var raw: Variant = stored.get("rule_version",null)
	if raw == null: return {"ok":false,"reason":"rule_version_missing","action":"refuse",
		"note":"a result without a rule version cannot be explained by the rules that produced it"}
	var version := int(raw)
	if KNOWN.has(version):
		return {"ok":true,"rule_version":version,"rules":str(KNOWN[version]),
			"explained_by":"stored_rule_version","migrated":false,
			"note":"the result is read by the version that produced it; nothing is reinterpreted under newer rules"}
	if version in MIGRATABLE:
		return {"ok":true,"rule_version":version,"rules":str(KNOWN[version]),"explained_by":"stored_rule_version",
			"migrated":true,"migration":"forward_only","note":"this version is known and may be migrated forward explicitly"}
	return {"ok":false,"reason":"unknown_rule_version:%d"%version,"action":"refuse_or_migrate","migrated":false,
		"known_versions":known_versions(),
		"note":"an unknown version is never silently read under the current rules"}

## The history keeps the version it was written with, whatever the current preset is, so nothing rewrites the past.
static func tag(result: Dictionary, version: int) -> Dictionary:
	var out := result.duplicate(true)
	out["rule_version"] = version
	return out

static func describe() -> Dictionary:
	return {"known_versions":known_versions(),"known":KNOWN.duplicate(),"migratable":MIGRATABLE.duplicate(),
		"provenance":"game_rule","comparison":"NOT_COMPARED"}
