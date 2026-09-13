class_name RoleMapping
extends RefCounted
## WT-031C-D: the authored role mapping, built from the REAL node names the probe found.
##
## Each role is resolved one of three ways, and the way is recorded:
##   node    - the GLB already contains a node for that role (measured by the probe)
##   derived - the asset has no such node, so an authored frame must be created at install
##             time from a parent node plus an offset (this is what the mount adapter does)
##   missing - neither exists yet; the asset must be re-exported
##
## Nothing here is installed and no packet is modified: this is the mapping table plus the
## evidence that produced it.

const KINDS := ["node","derived","missing"]

## Evidence: the node inventories the probe printed for each asset.
const OBSERVED_NODES := {
	"us_m1a1_abrams":["m1a1","M1A1_4k_tri","Body","TurretPivot","GunPivot","Gun","Turret"],
	"cn_ztz_99a":["ztz99a_1000","hull","LOD1000_hull","LOD1000_skirt_L","LOD1000_skirt_R","LOD1000_track_L",
		"LOD1000_track_R","LOD1000_wheels_L","LOD1000_wheels_R","turret","barrel","gun_recoil","LOD1000_gun",
		"muzzle","LOD1000_mantlet","LOD1000_turret"],
	"ussr_t_80b":["ussr_t_80b","DriverHatch","EngineAccessCover","FendersAndStowage","Headlamps","HullArmour",
		"RearExhaustLouvres","SideProtectionPlates","track_l","track_r","TurretPivot","GunPivot","MainGun","Mantlet",
		"TurretArmour","TurretCollar","TurretHatchSeatsAndCovers","TurretOptics","TurretStowage","Wheel_l_01",
		"Wheel_r_01","Wheel_l_drive","Wheel_r_drive"],
	"germ_leopard_2a4":["germ_leopard_2a4","VehicleRoot","EngineDeck","Headlights","HullArmour","LowerGlacis",
		"SideSkirtPanels","track_l","track_r","TurretPivot","Antennas","GunPivot","MainGunAndMuzzleBrake","Mantlet",
		"Optics","SmokeLaunchers","TurretArmour","TurretBustleLid","TurretRace","wheel_l_01","wheel_r_01",
		"wheel_l_drive","wheel_r_drive"],
}

const ASSET_PATHS := {
	"us_m1a1_abrams":"res://assets/vehicles/m1a1/m1a1.glb",
	"cn_ztz_99a":"res://assets/vehicles/ztz99a/ztz99a_1000.glb",
	"ussr_t_80b":"res://assets/research/models/ussr_t_80b.glb",
	"germ_leopard_2a4":"res://assets/research/models/germ_leopard_2a4.glb",
}

## The authored table. `node` entries name a node the probe actually observed; `derived`
## entries name a parent node plus an authored offset (author provenance, not measured).
const MAPPINGS := {
	"cn_ztz_99a":{
		"hull":{"kind":"node","path":"hull"},
		"turret":{"kind":"node","path":"turret"},
		"gun":{"kind":"node","path":"barrel"},
		"muzzle":{"kind":"node","path":"muzzle"},
		"running_left":{"kind":"node","path":"LOD1000_track_L"},
		"running_right":{"kind":"node","path":"LOD1000_track_R"},
	},
	"ussr_t_80b":{
		"hull":{"kind":"node","path":"HullArmour"},
		"turret":{"kind":"node","path":"TurretArmour"},
		"gun":{"kind":"node","path":"MainGun"},
		"muzzle":{"kind":"derived","parent":"MainGun","offset_m":[0.0,0.0,-2.4],"provenance":"author"},
		"running_left":{"kind":"node","path":"track_l"},
		"running_right":{"kind":"node","path":"track_r"},
	},
	"germ_leopard_2a4":{
		"hull":{"kind":"node","path":"HullArmour"},
		"turret":{"kind":"node","path":"TurretArmour"},
		"gun":{"kind":"node","path":"MainGunAndMuzzleBrake"},
		"muzzle":{"kind":"derived","parent":"MainGunAndMuzzleBrake","offset_m":[0.0,0.0,-2.6],"provenance":"author"},
		"running_left":{"kind":"node","path":"track_l"},
		"running_right":{"kind":"node","path":"track_r"},
	},
	"us_m1a1_abrams":{
		"hull":{"kind":"node","path":"Body"},
		"turret":{"kind":"node","path":"Turret"},
		"gun":{"kind":"node","path":"Gun"},
		"muzzle":{"kind":"derived","parent":"Gun","offset_m":[0.0,0.0,-2.2],"provenance":"author"},
		"running_left":{"kind":"missing","reason":"merged_lod_has_no_track_nodes"},
		"running_right":{"kind":"missing","reason":"merged_lod_has_no_track_nodes"},
	},
}

static func asset_ids() -> Array[String]:
	var out: Array[String] = []
	for id in MAPPINGS: out.append(id)
	return out

static func mapping_for(asset_id: String) -> Dictionary:
	return (MAPPINGS.get(asset_id,{}) as Dictionary).duplicate(true)

static func observed(asset_id: String) -> Array:
	return (OBSERVED_NODES.get(asset_id,[]) as Array).duplicate()

## Every `node` entry must name a node that really exists; a typo is an error, not a guess.
static func validate(asset_id: String) -> Dictionary:
	if not MAPPINGS.has(asset_id): return {"ok":false,"reason":"unknown_asset"}
	var names := observed(asset_id)
	var errors: Array[String] = []
	var by_kind := {"node":0,"derived":0,"missing":0}
	var resolved := 0
	var rows: Array[Dictionary] = []
	for role in ModelBindingValidator.ROLES:
		var entry: Dictionary = MAPPINGS[asset_id].get(role,{"kind":"missing","reason":"not_authored"})
		var kind := str(entry.get("kind","missing"))
		by_kind[kind] = int(by_kind.get(kind,0))+1
		var detail := ""
		if kind == "node":
			var path := str(entry.get("path",""))
			if not names.has(path):
				errors.append("%s: node %s is not in the asset" % [role,path])
			else: resolved += 1
			detail = path
		elif kind == "derived":
			var parent := str(entry.get("parent",""))
			if not names.has(parent): errors.append("%s: derived parent %s is not in the asset" % [role,parent])
			elif entry.get("offset_m",[]).size() != 3: errors.append("%s: derived offset must be three numbers"%role)
			else: resolved += 1
			detail = "%s + authored offset"%parent
		else:
			detail = str(entry.get("reason","missing"))
		rows.append({"role":role,"kind":kind,"detail":detail})
	return {"ok":errors.is_empty(),"asset_id":asset_id,"errors":errors,"roles":rows,
		"by_kind":by_kind,"resolved":resolved,"slots":ModelBindingValidator.ROLES.size(),
		"complete":resolved == ModelBindingValidator.ROLES.size() and errors.is_empty()}

static func missing_roles_for(asset_id: String) -> Array[String]:
	var out: Array[String] = []
	for row in validate(asset_id).roles:
		if str(row.kind) == "missing": out.append(str(row.role))
	return out

## A draft binding in the consumer's shape; derived roles are marked so the install path
## knows it must create the frame, and nothing is ever applied here.
static func draft_binding(asset_id: String) -> Dictionary:
	if not MAPPINGS.has(asset_id): return {}
	var nodes := {}
	var derived := {}
	for role in ModelBindingValidator.ROLES:
		var entry: Dictionary = MAPPINGS[asset_id].get(role,{})
		match str(entry.get("kind","missing")):
			"node": nodes[role] = str(entry.path)
			"derived": derived[role] = {"parent":str(entry.parent),"offset_m":entry.offset_m,
				"provenance":str(entry.get("provenance","author"))}
	var validation := validate(asset_id)
	return {"model":{"path":str(ASSET_PATHS[asset_id]),"sha256":FileAccess.get_sha256(str(ASSET_PATHS[asset_id]))},
		"units":{"meters_per_unit":1.0},
		"nodes":nodes,"derived_frames":derived,
		"complete":bool(validation.complete),"missing_roles":missing_roles_for(asset_id),
		"applied":false,"note":"authored mapping only: not installed, no packet modified"}

## Which vehicles can be registered once frames are created, and which need a re-export.
static func coverage() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for asset_id in MAPPINGS:
		var validation := validate(asset_id)
		out.append({"asset_id":asset_id,"by_kind":validation.by_kind,"resolved":validation.resolved,
			"slots":validation.slots,"complete":validation.complete,
			"registration_ready":validation.complete,
			"blocker":"" if validation.complete else "asset_needs_re_export_for_missing_roles"})
	return out

static func snapshot() -> Dictionary:
	var drafts := {}
	for id in MAPPINGS: drafts[id] = draft_binding(id)
	return {"assets":asset_ids(),"coverage":coverage(),"drafts":drafts,
		"installed":false,"registry_untouched":true}
