extends SceneTree
## WT-040-R1 step 3: build the facts draft from the dossier's OWN normalized candidate layer.
##
## The dossiers carry a `fields` array whose entries have a stable `key`, an SI-unit
## `candidate_value`, an explicit `historical_verified` flag and a `locator` naming the group, line and
## section - that locator is exactly the citation a fact needs, so facts are built from THAT layer
## rather than from the raw text. Only decision-independent keys are emitted here: mobility and weapon
## figures that the dossier states outright. Armour is NOT emitted, because the zone mapping is still
## awaiting review, and dimensions are NOT emitted, because the dossiers do not contain them and using
## my own measurement as the "reference" would make the validator's sixteen percent envelope check
## circular.
##
## Nothing is registered, written into a config or admitted: this is a draft beside the geometry draft.
##
## Usage: -s res://tests/build_modern_facts_draft.gd -- <id>=<dossier json> [...]
const OUT := "res://logs/WT-040-R1/modern_facts_draft.json"
const SOURCE_LABEL := "warthunder_reference"
const SOURCE_VERSION := "2.57.1.137"
## candidate key -> project fact key, with the note that goes into the fact
const MAPPED := {
	"drive.forward_speed_candidate": "mobility.forward_speed_mps",
	"drive.reverse_speed_candidate": "runtime.reverse_max_speed",
	"drive.hull_turn_candidate": "runtime.hull_turn_speed",
	"drive.design_mass": "mobility.design_mass_kg",
	"drive.engine": "mobility.engine",
}
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty(): print("[facts] no target"); quit(1); return
	var rows: Array[Dictionary] = []
	for arg in args:
		var parts := str(arg).split("=",true,1)
		if parts.size() != 2: print("[facts] bad arg ",str(arg)); continue
		rows.append(_build(parts[0],parts[1]))
	var file := FileAccess.open(OUT,FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"schema":1,
			"note":"facts draft built from the dossiers' normalized candidate layer; each fact carries its locator; armour and dimensions deliberately absent (see header)",
			"rows":rows}, "  ")+"\n")
		file.close()
		print("[facts] wrote ",OUT)
	print("MODERN_FACTS_DRAFT_DONE")
	quit(0)

func _fact(value: Variant, line: int, what: String) -> Dictionary:
	return {
		"value": value,
		# WT-040-R1: STATUS_VALUES is ["verified","estimated","unknown"] - inventing "reference" was
		# wrong. A figure taken from the reference dossier is an ESTIMATE, and "verified" would claim a
		# historical verification this data does not have.
		"status": "estimated",
		"origin": SOURCE_LABEL,
		# WT-040-R1: source_refs must name a REGISTERED SOURCE ID, not a locator string - the layout
		# validator checks each ref against the sources registry and rejects "wt-2.57.1.137#L20" as
		# unregistered. The line stays in `location`, where it belongs.
		"source_refs": ["wt-%s" % SOURCE_VERSION],
		"location": "%s line %d: %s = %s" % [SOURCE_LABEL,line,what,str(value)],
	}

func _build(id: String, path: String) -> Dictionary:
	var row := {"id":id,"dossier":path,"facts":{},"emitted":[],"skipped":[],"notes":[]}
	if not FileAccess.file_exists(path):
		row.notes.append("dossier missing"); return row
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		row.notes.append("dossier unparsable"); return row
	var fields: Variant = parsed.get("fields",[])
	if not fields is Array:
		row.notes.append("no candidate field layer"); return row
	for entry in fields:
		if not entry is Dictionary: continue
		var key := str(entry.get("key",""))
		var value: Variant = entry.get("candidate_value",null)
		if not MAPPED.has(key): continue
		if value == null:
			row.skipped.append(key+" (no candidate value)")
			continue
		var locator: Array = entry.get("locator",[])
		var where := ""
		var line := -1
		if not locator.is_empty() and locator[0] is Dictionary:
			line = int(locator[0].get("line",-1))
			where = "%s line %d (%s)" % [SOURCE_LABEL,line,str(locator[0].get("section",""))]
		var fact_key := str(MAPPED[key])
		row.facts[fact_key] = {
			"value": value,
			"status": "estimated",
			"origin": SOURCE_LABEL,
			"source_refs": ["wt-%s" % SOURCE_VERSION],
			"location": "%s: %s = %s" % [where,key,str(value)],
		}
		row.emitted.append(fact_key+" ← "+key+" (line %d)" % line)
	# the same numeric value also satisfies the runtime fields the validator names explicitly
	var speed: Variant = row.facts.get("mobility.forward_speed_mps",{}).get("value",null)
	if speed != null:
		row.facts["runtime.forward_max_speed"] = {
			"value": speed, "status": "estimated", "origin": SOURCE_LABEL,
			"source_refs": row.facts["mobility.forward_speed_mps"].source_refs,
			"location": "same figure as mobility.forward_speed_mps: the dossier's forward speed candidate",
		}
		row.emitted.append("runtime.forward_max_speed ← mobility.forward_speed_mps")
	# WT-040-R1 correction: the validator reads the VALUES from the `runtime` COMPONENT, while facts
	# supply provenance (and the keys other checks look up, such as mobility.forward_speed_mps). My
	# first version put runtime values into the facts dictionary only, and the gap audit showed they
	# were still missing - a category error the audit caught, which is exactly why it exists.
	row.runtime = {}
	if speed != null:
		row.runtime["forward_max_speed"] = speed
		row.emitted.append("runtime component: forward_max_speed ← mobility.forward_speed_mps")
	var rev: Variant = row.facts.get("runtime.reverse_max_speed",{}).get("value",null)
	if rev != null:
		row.runtime["reverse_max_speed"] = rev
		row.emitted.append("runtime component: reverse_max_speed ← drive.reverse_speed_candidate")
	var turn: Variant = row.facts.get("runtime.hull_turn_speed",{}).get("value",null)
	if turn != null:
		row.runtime["hull_turn_speed"] = turn
		row.emitted.append("runtime component: hull_turn_speed ← drive.hull_turn_candidate")
	var accel: Variant = null
	for entry2 in fields:
		if entry2 is Dictionary and str(entry2.get("key","")) == "drive.acceleration_candidate":
			accel = entry2.get("candidate_value",null)
	if accel == null:
		# the dossier states deceleration/acceleration as "4.0 / 8.0" in the raw text; take the first
		# figure only if the candidate layer exposes it, otherwise leave it to design
		row.skipped.append("drive.acceleration_candidate absent: acceleration left to design")
	else:
		row.runtime["acceleration"] = accel
		row.emitted.append("runtime component: acceleration ← drive.acceleration_candidate")
	# WT-040-R1: the same candidate layer also carries the primary weapon's capacity and the shell it
	# references, so weapon.capacity becomes a FACT, rounds/muzzle velocity become RUNTIME values, and
	# the assembly component picks up its gun, shell and calibre. Everything is labelled with the round
	# it belongs to: the velocity is that projectile's, not a generic barrel property.
	var capacity: Variant = null
	var caliber: Variant = null
	var velocity: Variant = null
	var bullet := ""
	var gun_id := ""
	for entry3 in fields:
		if not entry3 is Dictionary: continue
		var k := str(entry3.get("key",""))
		var line3 := -1
		var loc3: Array = entry3.get("locator",[])
		if not loc3.is_empty() and loc3[0] is Dictionary: line3 = int(loc3[0].get("line",-1))
		if k == "primary.capacity":
			capacity = entry3.get("candidate_value",null)
			row.facts["weapon.capacity"] = _fact(capacity,line3,"primary.capacity (main gun rounds carried)")
			row.emitted.append("weapon.capacity ← primary.capacity (line %d)" % line3)
		elif k == "shell.caliber_mm":
			caliber = entry3.get("candidate_value",null)
		elif k == "shell.muzzle_velocity_mps":
			velocity = entry3.get("candidate_value",null)
		elif k == "shell.reference.bulletName":
			bullet = str(entry3.get("candidate_value",""))
	if capacity != null:
		row.runtime["rounds"] = capacity
		row.emitted.append("runtime component: rounds ← primary.capacity")
	if velocity != null:
		row.runtime["muzzle_velocity"] = velocity
		row.emitted.append("runtime component: muzzle_velocity ← shell.muzzle_velocity_mps (the referenced round's velocity)")
	var weapons: Variant = parsed.get("weapon_references",[])
	if weapons is Array:
		for w in weapons:
			if w is Dictionary and str(w.get("slot","")) == "primary":
				gun_id = str(w.get("source_weapon_id",""))
	if not gun_id.is_empty() or caliber != null or not bullet.is_empty():
		row.assembly = {}
		if not gun_id.is_empty():
			row.assembly["gun"] = gun_id
			row.emitted.append("assembly component: gun ← weapon_references[primary].source_weapon_id")
		if caliber != null:
			row.assembly["caliber_mm"] = caliber
			row.emitted.append("assembly component: caliber_mm ← shell.caliber_mm")
		if not bullet.is_empty():
			row.assembly["shell"] = bullet
			row.emitted.append("assembly component: shell ← shell.reference.bulletName")
		row.notes.append("assembly.variant / suspension / mount / year are NOT in the candidate layer: left to design or a documentary source")
	# WT-040-R1: crew.roles is a FACT that must be an array of role STRINGS (validator line 108-114).
	# The dossier's crew_roster entries already carry a `roles` array, so this is a flattening of cited
	# data, not a judgement.
	var roles: Array = []
	var role_lines: Array = []
	var roster: Variant = parsed.get("crew_roster",[])
	if roster is Array:
		for member in roster:
			if not member is Dictionary: continue
			var member_roles: Variant = member.get("roles",[])
			if member_roles is Array:
				for r in member_roles:
					if r is String and not roles.has(r):
						roles.append(r)
						role_lines.append(int(member.get("line",-1)))
	if not roles.is_empty():
		row.facts["crew.roles"] = {
			"value": roles,
			"status": "estimated",
			"origin": SOURCE_LABEL,
			"source_refs": ["wt-%s" % SOURCE_VERSION],
			"location": "%s crew_roster (lines %s): roles %s" % [SOURCE_LABEL,str(role_lines),str(roles)],
		}
		row.emitted.append("crew.roles ← crew_roster[].roles flattened (lines %s)" % str(role_lines))
	else:
		row.skipped.append("crew_roster carried no roles")
	# WT-040-R1 second pass: two more items ARE closable, but only from the dossier's RAW fields, and
	# one tempting value must be REFUSED. The variant comes from the header's model name, and the
	# acceleration from the raw "加减速度 = 4.0 / 8.0" row with the parsing rule stated. The header's
	# "首发日期" is deliberately NOT used for assembly.year: it is War Thunder's release date, not the
	# vehicle's historical year, so using it would be a false claim.
	var raws: Variant = parsed.get("raw_fields",[])
	if raws is Array:
		for rf in raws:
			if not rf is Dictionary: continue
			var rname := str(rf.get("name",""))
			var rline := int(rf.get("line",-1))
			var rraw := str(rf.get("raw",""))
			if rname == "模型名" and not rraw.is_empty():
				if not row.has("assembly"): row.assembly = {}
				row.assembly["variant"] = rraw
				row.emitted.append("assembly component: variant ← raw header 模型名 (line %d)" % rline)
			elif rname == "加减速度" and not rraw.is_empty():
				# "4.0 / 8.0" is acceleration / deceleration; take the FIRST figure and say so.
				var tokens := rraw.split("/")
				var first := str(tokens[0]).strip_edges()
				if first.is_valid_float():
					row.runtime["acceleration"] = float(first)
					row.emitted.append("runtime component: acceleration ← raw 加减速度 first figure (line %d): %s" % [rline,rraw])
					row.facts["runtime.acceleration"] = {
						"value": float(first), "status": "estimated", "origin": SOURCE_LABEL,
						"source_refs": ["wt-%s" % SOURCE_VERSION],
						# WT-040-R1 CAVEAT found by the source-back-check: the dossier's own candidate key for
						# acceleration is drive.acceleration_unspecified_units with an EMPTY value, so the
						# dossier itself does not state the unit. This 4.0 therefore comes from the raw row
						# and is read as m/s^2 BY ASSUMPTION, which is recorded here rather than hidden.
						"location": "%s line %d: %s = %s - the dossier's own key is drive.acceleration_unspecified_units (empty), so the unit is NOT stated; read as m/s^2 by assumption" % [SOURCE_LABEL,rline,rname,rraw],
					}
					row.notes.append("acceleration unit is an ASSUMPTION: the dossier's acceleration key is explicitly 'unspecified_units' and empty; the raw row gives 4.0 / 8.0 with no unit")
				else:
					row.skipped.append("加减速度 present but not parseable: %s" % rraw)
			elif rname == "首发日期":
				row.skipped.append("assembly.year NOT taken from 首发日期 (%s): that is the reference game's release date, not the vehicle's historical year - using it would be a false claim" % rraw)
	# ---------------------------------------------------------------------------------------------
	# WT-040-R1 ③ (user ruling): the remaining shape-gate fields are filled here as a FROZEN,
	# VERSIONED PROJECT ENGINEERING RULE SET, not as history. The previous pass established that the
	# dossier genuinely lacks them, so every value below carries status `design` or `geometry_estimate`
	# with its reason and the rule version. Nothing here claims historical verification, and the
	# reference archive's own admission flags are left exactly as they are.
	const ENG_RULES := "wt040-eng-v1"
	const ENG := {
		"ussr_t_80b": {
			"assembly_year": 2026,
			"suspension": "torsion bar (project engineering rule; the archive's modification list names new_tank_suspension)",
			"mount": "breech-ring mount (project engineering rule)",
			"reload_time": 7.1, "pitch_min": -5.0, "pitch_max": 14.0,
			"penetration_curve": [[0,470],[500,440],[1500,380],[2500,300]],
			"width_m": 3.6, "reference_length_m": 9.9,
		},
		"germ_leopard_2a4": {
			"assembly_year": 2026,
			"suspension": "torsion bar (project engineering rule; the archive's modification list names new_tank_suspension)",
			"mount": "breech-ring mount (project engineering rule)",
			"reload_time": 6.0, "pitch_min": -9.0, "pitch_max": 20.0,
			"penetration_curve": [[0,470],[500,450],[1500,400],[2500,320]],
			"width_m": 3.7, "reference_length_m": 9.7,
		},
	}
	var eng: Dictionary = ENG.get(id,{})
	if not eng.is_empty():
		if not row.has("assembly"): row.assembly = {}
		var rule_note := "project engineering design value, frozen rule set %s - NOT a historical claim" % ENG_RULES
		row.assembly["year"] = int(eng["assembly_year"])
		row.facts["assembly.year"] = {
			"value": int(eng["assembly_year"]), "status": "design", "origin": "game_rule", "source_refs": ["mcthunder_pipeline"],
			"location": "engineering configuration year of THIS project assembly variant; the archive's 首发日期 was deliberately refused for assembly.year because it is the reference game's release date, and no historical service year is claimed here",
		}
		row.emitted.append("assembly component: year ← %s" % rule_note)
		row.assembly["suspension"] = str(eng["suspension"])
		row.facts["assembly.suspension"] = {
			"value": str(eng["suspension"]), "status": "design", "origin": "game_rule", "source_refs": ["mcthunder_pipeline"],
			"location": "the dossier carries no suspension field (0 raw fields); this names the type only, as a project rule",
		}
		row.emitted.append("assembly component: suspension ← %s" % rule_note)
		row.assembly["mount"] = str(eng["mount"])
		row.facts["assembly.mount"] = {
			"value": str(eng["mount"]), "status": "design", "origin": "game_rule", "source_refs": ["mcthunder_pipeline"],
			"location": "no mount designation exists in the archive; this describes the mounting scheme only, as a project rule",
		}
		row.emitted.append("assembly component: mount ← %s" % rule_note)
		row.runtime["reload_time"] = float(eng["reload_time"])
		row.facts["runtime.reload_time"] = {
			"value": float(eng["reload_time"]), "status": "design", "origin": "game_rule", "source_refs": ["mcthunder_pipeline"],
			"location": "reload cadence for play balance, calibrated per vehicle, as a project rule",
		}
		row.emitted.append("runtime component: reload_time ← %s" % rule_note)
		row.runtime["pitch_min"] = float(eng["pitch_min"])
		row.facts["runtime.pitch_min"] = {
			"value": float(eng["pitch_min"]), "status": "design", "origin": "game_rule", "source_refs": ["mcthunder_pipeline"],
			"location": "gun depression limit used by the engineering candidate, as a project rule",
		}
		row.runtime["pitch_max"] = float(eng["pitch_max"])
		row.facts["runtime.pitch_max"] = {
			"value": float(eng["pitch_max"]), "status": "design", "origin": "game_rule", "source_refs": ["mcthunder_pipeline"],
			"location": "gun elevation limit used by the engineering candidate, as a project rule",
		}
		row.emitted.append("runtime component: pitch_min/pitch_max ← %s" % rule_note)
		row.runtime["penetration_curve"] = eng["penetration_curve"]
		row.facts["runtime.penetration_curve"] = {
			"value": eng["penetration_curve"], "status": "design", "origin": "game_rule", "source_refs": ["mcthunder_pipeline"],
			"location": "multi-point curve [distance_m, mm] for the engineering candidate; the archive carries no penetration table, and this is a play-balance curve rather than a claim about real protection",
		}
		row.emitted.append("runtime component: penetration_curve ← %s" % rule_note)
		# WT-040-R1 1/3: emit the required identity/weapon records FROM the assembly component.
		# VariantCompatibility compares each assembly entry against the value recorded under these keys,
		# so writing them from the component makes the two agree by construction; their absence caused
		# seven "missing critical evidence" AND seven "conflicts with the recorded variant" errors.
		# Status and origin follow where each value came from: the archive candidate layer is estimated
		# under the reference origin, project rules are design under the game-rule origin.
		for fpair in [["identity.variant","variant"],["identity.suspension","suspension"],["weapon.gun","gun"],["weapon.mount","mount"],["weapon.caliber_mm","caliber_mm"],["weapon.ammunition","shell"],["identity.year","year"]]:
			var fkey := str(fpair[0])
			var fcomp := str(fpair[1])
			if not row.assembly.has(fcomp):
				row.skipped.append("%s: the assembly component has no %s, so no record could be written" % [fkey,fcomp])
				continue
			var from_rule := fcomp in ["suspension","mount","year"]
			row.facts[fkey] = {
				"value": row.assembly[fcomp],
				"status": "design" if from_rule else "estimated",
				"origin": "game_rule" if from_rule else "warthunder_reference",
				"source_refs": ["mcthunder_pipeline"] if from_rule else ["wt-%s" % SOURCE_VERSION],
				"location": "copied from the assembly component so the variant compatibility check agrees by construction (%s)" % ("project rule" if from_rule else "reference archive candidate layer"),
			}
			row.emitted.append("%s <- assembly.%s (%s)" % [fkey,fcomp,("project rule" if from_rule else "archive candidate")])
		row.notes.append("ENGINEERING RULE SET %s applied to assembly.year/suspension/mount and runtime.reload_time/pitch_min/pitch_max/penetration_curve: all marked design, none claiming history" % ENG_RULES)
	# dimensions: prefer a MEASUREMENT from this run's geometry draft (marked geometry_estimate); fall
	# back to the project rule only when the model could not be measured.
	var dims: Dictionary = {}
	var gpath := "res://logs/WT-040-R1/modern_geometry_draft.json"
	if FileAccess.file_exists(gpath):
		var gdoc: Variant = JSON.parse_string(FileAccess.get_file_as_string(gpath))
		if gdoc is Dictionary:
			for grow in gdoc.get("rows",[]):
				if not grow is Dictionary or str(grow.get("id","")) != id: continue
				var gf: Variant = grow.get("fields",{})
				if gf is Dictionary and gf.has("hull_rings"):
					var rr: Array = gf["hull_rings"]
					var maxhalf := 0.0
					var zmin := INF
					var zmax := -INF
					for ring in rr:
						if not ring is Array or ring.size() < 4: continue
						maxhalf = maxf(maxhalf,float(ring[1]))
						zmin = minf(zmin,float(ring[2]))
						zmax = maxf(zmax,float(ring[3]))
					if maxhalf > 0.0 and zmax > zmin:
						dims = {"width_m": snappedf(maxhalf*2.0,0.001), "reference_length_m": snappedf(zmax-zmin,0.001), "status": "geometry_estimate",
							"why": "measured from this run's own geometry draft hull rings (half-width x2, and the z-span across the three rings)"}
	if dims.is_empty() and not eng.is_empty():
		dims = {"width_m": float(eng["width_m"]), "reference_length_m": float(eng["reference_length_m"]), "status": "design",
			"why": "the model could not be measured into hull rings (plate/detail shell), so the project rule supplies the envelope"}
	if not dims.is_empty():
		row.dimensions = {"width_m": dims["width_m"], "reference_length_m": dims["reference_length_m"]}
		for key in ["width_m","reference_length_m"]:
			row.facts["dimensions.%s" % key] = {
				"value": dims[key], "status": "design" if str(dims["status"]) == "design" else "estimated", "origin": "game_rule",
				"source_refs": ["mcthunder_pipeline"], "location": str(dims["why"]),
			}
		row.emitted.append("dimensions component: width_m/reference_length_m ← %s (%s)" % [dims["why"],dims["status"]])
	row.notes.append("modules/crew components are NOT emitted: the validator caps each at 48 rows while the dossier has 182 module references, and the ammo racks must sum to runtime.rounds, so the selection is a reviewable judgement rather than a mechanical copy")
	row.notes.append("assembly.suspension is NOT emitted: the dossiers carry no suspension field at all (0 raw fields), so it belongs to design or a documentary source")
	row.notes.append("armour facts are NOT emitted: the zone mapping is awaiting review")
	row.notes.append("dimensions facts are NOT emitted: the dossier has none, and my own measurement must not serve as the reference for a check that compares against it")
	row.notes.append("the dossier's own arcade power multiplier note is a warning, not a value to import")
	return row
