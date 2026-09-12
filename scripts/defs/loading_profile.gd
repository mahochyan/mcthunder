class_name LoadingProfile
extends Resource
## Explicit authored equipment/rack policy. Defaults preserve legacy crew loading.
@export var schema_version: int = 1
@export var mode: String = "crew"
@export var crew_role: String = "loader"
@export var missing_crew_rate: float = GameConfig.DAMAGE_MISSING_LOADER_RATE
@export var required_module_ids: Array[String] = []
@export var shot_feed_rack_ids: Array[String] = []
@export var supply_rack_ids: Array[String] = []
@export var replenishment_enabled: bool = false
@export var reserve_rack_ids: Array[String] = []
@export var replenishment_delay_s: float = 0.0
@export var replenishment_interval_s: float = 1.0
@export var replenishment_role: String = ""
@export var replenishment_module_ids: Array[String] = []
@export var replenishment_stationary: bool = true
@export var origin: String = "game_rule"
@export var note: String = "Legacy authored crew loading; no historical equipment claim."

func validate() -> Array[String]:
	var errors: Array[String]=[]
	if schema_version!=1: errors.append("loading.schema_version: unsupported")
	if mode not in ["crew","automatic"]: errors.append("loading.mode: unsupported")
	if origin not in ["game_rule","warthunder_reference"] or note.strip_edges().is_empty(): errors.append("loading: explicit reference/design origin and explanation required")
	if not is_finite(missing_crew_rate) or missing_crew_rate<0 or missing_crew_rate>1: errors.append("loading.missing_crew_rate: invalid")
	if mode=="crew" and crew_role.is_empty(): errors.append("loading.crew_role: required")
	if mode=="automatic" and (not crew_role.is_empty() or required_module_ids.is_empty() or shot_feed_rack_ids.is_empty()): errors.append("loading.automatic: explicit mechanism/feed IDs and no invented loader required")
	for ids in [required_module_ids,shot_feed_rack_ids,supply_rack_ids,reserve_rack_ids,replenishment_module_ids]:
		var seen := {}
		for id in ids:
			if id.strip_edges().is_empty() or seen.has(id): errors.append("loading.ids: empty or duplicate")
			seen[id]=true
	if not is_finite(replenishment_delay_s) or replenishment_delay_s<0 or not is_finite(replenishment_interval_s) or replenishment_interval_s<=0: errors.append("loading.replenishment: invalid independent times")
	if replenishment_enabled:
		if reserve_rack_ids.is_empty() or shot_feed_rack_ids.is_empty(): errors.append("loading.replenishment: explicit source/destination required")
		for id in reserve_rack_ids:
			if id in shot_feed_rack_ids: errors.append("loading.replenishment: overlapping racks")
	return errors

static func from_packet(value: Variant) -> Dictionary:
	var errors: Array[String]=[]
	var profile := LoadingProfile.new()
	if not value is Dictionary: return {"ok":false,"errors":["loading_profile: expected dictionary"]}
	var strings := ["mode","crew_role","replenishment_role","origin","note"]
	var arrays := ["required_module_ids","shot_feed_rack_ids","supply_rack_ids","reserve_rack_ids","replenishment_module_ids"]
	var numbers := ["missing_crew_rate","replenishment_delay_s","replenishment_interval_s"]
	var flags := ["replenishment_enabled","replenishment_stationary"]
	for key in value:
		if key in strings:
			if not value[key] is String: errors.append("loading."+key+": expected string")
			else: profile.set(key,value[key])
		elif key in arrays:
			if not value[key] is Array: errors.append("loading."+key+": expected IDs"); continue
			var valid := true
			for id in value[key]:
				if not id is String: valid=false
			if not valid: errors.append("loading."+key+": expected string IDs")
			else:
				var ids: Array=profile.get(key); ids.assign(value[key])
		elif key in numbers:
			if not (value[key] is int or value[key] is float) or not is_finite(float(value[key])): errors.append("loading."+key+": expected finite number")
			else: profile.set(key,float(value[key]))
		elif key in flags:
			if not value[key] is bool: errors.append("loading."+key+": expected bool")
			else: profile.set(key,value[key])
		elif key=="schema_version":
			if not (value[key] is int or value[key] is float) or value[key]!=1: errors.append("loading.schema_version: unsupported")
		else: errors.append("loading: unknown field "+str(key))
	if value.get("mode")=="automatic":
		for key in ["mode","crew_role","required_module_ids","shot_feed_rack_ids","origin","note"]:
			if not value.has(key): errors.append("loading.automatic: explicit "+key+" required")
	errors.append_array(profile.validate())
	return {"ok":errors.is_empty(),"errors":errors,"profile":profile}

func validate_bindings(layout: VehicleLayoutDefinition) -> Array[String]:
	var errors := validate()
	if layout==null:
		if mode=="automatic" or not required_module_ids.is_empty() or not shot_feed_rack_ids.is_empty() or replenishment_enabled: errors.append("loading: bound layout required")
		return errors
	var modules := {}; var roles: Array[String]=[]
	for module in layout.modules: modules[module.id]=module
	for station in layout.crew_stations: roles.append(station.role)
	for id in required_module_ids+replenishment_module_ids:
		if not modules.has(id): errors.append("loading.module: unknown "+id)
	var mechanism := false
	for id in required_module_ids:
		if modules.has(id) and modules[id].kind=="autoloader": mechanism=true
	if mode=="automatic" and not mechanism: errors.append("loading.automatic: bound autoloader geometry required")
	for id in shot_feed_rack_ids+supply_rack_ids+reserve_rack_ids:
		if not modules.has(id) or modules[id].kind!="ammo" or modules[id].ammo_capacity<=0: errors.append("loading.rack: missing/capacityless ammo module "+id)
	if mode=="crew" and not shot_feed_rack_ids.is_empty() and crew_role not in roles: errors.append("loading.crew_role: absent from configured roster")
	if replenishment_enabled and not replenishment_role.is_empty() and replenishment_role not in roles: errors.append("loading.replenishment_role: absent")
	return errors
