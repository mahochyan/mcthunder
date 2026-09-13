class_name RoleMappingAudit
extends RefCounted
## WT-031C-D / WT-030D-R2: read-only role resolution over an arbitrary model set.
##
## The hint table is built from the node names actually observed in the German set (see
## MODEL_BINDING_PROBE.md and the intake audit), not from guesswork:
##   hull           -> HullArmour / SideArmour / Hull...
##   turret         -> TurretArmour / Turret... / RotatingPlatform / LauncherPedestal...
##   gun            -> MainGunAndMuzzleBrake / MainGun / barrel / SecondaryGun
##   muzzle         -> no dedicated node in these assets (the brake is part of the gun mesh)
##   running_left   -> track_l / wheel_l_* / Laufwerk...
##   running_right  -> track_r / wheel_r_* / Laufwerk...
##
## A role resolves to a node only when exactly one candidate matches; several candidates are
## reported as AMBIGUOUS with the list, and no muzzle node becomes a DERIVED frame on the
## gun node. Nothing is installed, registered or written into any asset.

const HINTS := {
	"hull":["hullarmour","hullarmor","sidearmour","hull","body","wanne"],
	"turret":["turretarmour","turret","turm","rotatingplatform","launcherpedestal","cupola"],
	"gun":["maingunandmuzzl","maingun","barrel","kanone","rohr","cannon","gun"],
	"muzzle":["muzzle"],
	"running_left":["track_l","trackleft","laufwerk_l","wheel_l","lefttrack"],
	"running_right":["track_r","trackright","laufwerk_r","wheel_r","righttrack"],
}
const DERIVED_ROLES := ["muzzle"]
const DERIVED_OFFSET_M := [0.0,0.0,-2.4]
## Roles whose hint must match exactly or as a prefix. Without this, `muzzle` matched the
## compound gun mesh name `MainGunAndMuzzleBrake` and pointed the muzzle role at the whole
## gun instead of a muzzle point; a muzzle node is accepted only when it truly is one.
const STRICT_ROLES := ["muzzle"]

static func resolve(probe_report: Dictionary) -> Dictionary:
	var roles: Dictionary = {}
	if not probe_report.get("ok",false):
		return {"ok":false,"reason":str(probe_report.get("reason","unparsable")),"roles":roles,
			"node_roles":0,"derived_roles":0,"ambiguous_roles":0,"missing_roles":ModelBindingValidator.ROLES.size()}
	var names: Array[String] = []
	for row in probe_report.get("nodes",[]):
		if str(row.get("type","")) == "mesh": names.append(str(row.get("name","")))
	var counts := {"node":0,"derived":0,"ambiguous":0,"missing":0}
	for role in ModelBindingValidator.ROLES:
		var candidates: Array[String] = []
		for hint in HINTS.get(role,[]):
			candidates.clear()
			for name in names:
				var lowered := name.to_lower()
				var hit := false
				if STRICT_ROLES.has(role): hit = lowered == str(hint) or lowered.begins_with(str(hint))
				else: hit = lowered.contains(str(hint))
				if hit: candidates.append(name)
			if not candidates.is_empty(): break
		var entry: Dictionary = {}
		if candidates.size() == 1:
			entry = {"kind":"node","node":candidates[0]}
		elif candidates.size() > 1:
			entry = {"kind":"ambiguous","candidates":candidates.slice(0,8),"count":candidates.size()}
		elif DERIVED_ROLES.has(role) and roles.has("gun") and str(roles.gun.get("kind","")) == "node":
			entry = {"kind":"derived","parent":str(roles.gun.node),"offset_m":DERIVED_OFFSET_M,"provenance":"author"}
		else:
			entry = {"kind":"missing"}
		counts[str(entry.kind)] = int(counts.get(str(entry.kind),0))+1
		roles[role] = entry
	var blocking := int(counts.missing)+int(counts.ambiguous)
	return {"ok":true,"roles":roles,"counts":counts,"node_roles":int(counts.node),
		"derived_roles":int(counts.derived),"ambiguous_roles":int(counts.ambiguous),
		"missing_roles":int(counts.missing),"binding_ready":counts.missing == 0 and counts.ambiguous == 0,
		"muzzle_authored":counts.derived > 0}

## Draft binding in the consumer's shape, built only from roles that really resolved to a
## node. Derived roles (the muzzle frame) are reported separately as pending author steps,
## because putting them on the gun node would make two roles share one node.
static func draft_binding(asset_root: String, folder: String, probe_report: Dictionary, result: Dictionary) -> Dictionary:
	var nodes := {}
	var pending: Array[String] = []
	if result.get("ok",false):
		for role in ModelBindingValidator.ROLES:
			var entry: Dictionary = result.roles.get(role,{})
			match str(entry.get("kind","")):
				"node": nodes[role] = str(entry.node)
				"derived": pending.append("%s(framed on %s)"%[role,str(entry.parent)])
				_: pending.append("%s(unresolved)"%role)
	return {"model":{"path":"%s/%s/vehicle.glb"%[asset_root,folder],"sha256":str(probe_report.get("sha256",""))},
		"units":{"meters_per_unit":float(probe_report.get("meters_per_unit",1.0))},
		"nodes":nodes,"pending_author_steps":pending,"node_roles_resolved":nodes.size()}

## Shape validation through the production validator, plus the two gates that are decided
## outside this repository (where the asset lives, and whether it may be redistributed).
static func registration_blockers(asset_root: String, folder: String, probe_report: Dictionary, result: Dictionary) -> Dictionary:
	var draft := draft_binding(asset_root,folder,probe_report,result)
	var shape: Array = []
	if draft.nodes.size() > 0:
		shape = ModelBindingValidator._shape(draft,folder)
	var path_gate := str(draft.model.path).begins_with("res://assets/vehicles/")
	var licence := "unknown"
	return {"shape_errors":shape,"pending_author_steps":draft.pending_author_steps,
		"node_roles_resolved":int(draft.node_roles_resolved),
		"path_inside_repo":path_gate,"path_gate":"internal" if path_gate else "external_asset_needs_intake_authorisation",
		"licence":licence,"licence_gate":"blocked_pending_source" if licence == "unknown" else "redistributable",
		"registration_ready":shape.is_empty() and draft.pending_author_steps.is_empty() and path_gate}

static func summary_line(folder: String, result: Dictionary) -> String:
	if not result.get("ok",false): return "%s: UNPARSABLE (%s)"%[folder,str(result.get("reason",""))]
	var parts: Array[String] = []
	for role in ModelBindingValidator.ROLES:
		var entry: Dictionary = result.roles.get(role,{})
		match str(entry.get("kind","")):
			"node": parts.append("%s=%s"%[role,str(entry.node)])
			"derived": parts.append("%s=derived(%s)"%[role,str(entry.parent)])
			"ambiguous": parts.append("%s=AMBIGUOUS(%d)"%[role,int(entry.count)])
			_: parts.append("%s=MISSING"%role)
	return "%s: ready=%s node=%d derived=%d ambiguous=%d missing=%d | %s"%[folder,str(result.binding_ready),
		int(result.node_roles),int(result.derived_roles),int(result.ambiguous_roles),int(result.missing_roles),
		" ".join(parts)]
