class_name GarageService
extends RefCounted
var catalog := VehicleCatalog.new()
var definitions := VehicleDefs.new()
var ready := false

func _init() -> void:
	# Historical-only installations can omit optional engineering resources. The
	# modern river entry and its candidate build require both complete packets;
	# they reject missing content instead of treating historical fallback as success.
	var historical := catalog.load_all(definitions)
	ready = historical.ok
	var engineering := catalog.load_engineering(definitions)
	if not engineering.ok:
		push_warning("engineering content admission (non-fatal, candidate assets may be absent from a package): "+", ".join(engineering.errors))

func has_vehicle(id: String) -> bool:
	# The curated roster is a publication boundary. Import candidates and temporary
	# registrations never become purchasable just because a dictionary contains them.
	# WT-040-R1: the roster is the curated historical set PLUS the explicitly admitted engineering vehicles.
	return ready and VehicleCatalog.is_combat_vehicle(id) and catalog.packages.get(id,{}).get("ok",false) and definitions.vehicles.has(id)

func vehicle_ids() -> Array[String]:
	var ids: Array[String]=[]
	# WT-040-R1: curated history first, then the explicitly admitted engineering vehicles, in a stable order.
	for id in VehicleCatalog.IDS + VehicleCatalog.ENGINEERING_IDS:
		if has_vehicle(id): ids.append(id)
	return ids

func vehicle_label(id: String) -> String:
	return str(catalog.packages[id].packet.display_name) if has_vehicle(id) else id

func default_loadout(id: String) -> Dictionary:
	if not has_vehicle(id): return {}
	var ammo := VehicleShellCatalog.build(catalog.packages[id].packet)
	if not ammo.ok: return {}
	var total: int = int(catalog.packages[id].packet.runtime.rounds)
	var alternate := floori(total*0.3) if ammo.options.size()>1 else 0
	var counts := {}
	var remaining := alternate
	var nondefault: int=ammo.options.size()-1
	for option in ammo.options:
		if option.id==ammo.default_id: counts[option.id]=total-alternate
		else:
			var share := ceili(float(remaining)/float(nondefault))
			counts[option.id]=share; remaining-=share; nondefault-=1
	return {"vehicle_id":id,"counts":counts,"first_shell":ammo.default_id}

func build_loadout(value: Dictionary) -> Dictionary:
	if not value.get("vehicle_id") is String or not has_vehicle(value.vehicle_id): return _reject(LocalizationService.text("ui_2fccbd4d8788"))
	if not value.get("counts") is Dictionary or not value.get("first_shell") is String: return _reject(LocalizationService.text("ui_23b3dc158d62"))
	var pack: Dictionary = catalog.packages[value.vehicle_id]
	var ammo := VehicleShellCatalog.build(pack.packet)
	if not ammo.ok: return _reject(LocalizationService.text("ui_bc6810c01ecc"))
	var expected: Array = []
	for option in ammo.options: expected.append(option.id)
	if value.counts.size() != expected.size(): return _reject(LocalizationService.text("ui_6796ae3df153"))
	var counts := {}
	var total := 0
	for id in value.counts:
		if id not in expected: return _reject(LocalizationService.text("ui_40aceacf5f23"))
		if not value.counts[id] is int or value.counts[id] < 0: return _reject(LocalizationService.text("ui_adb9181d07b8"))
		counts[id] = value.counts[id]; total += int(counts[id])
	if total <= 0: return _reject(LocalizationService.text("ui_de455a7a9591"))
	var rack_ids: Array = []
	var capacities := {}
	for module in pack.layout.modules:
		if module.kind == "ammo": rack_ids.append(module.id); capacities[module.id] = module.ammo_capacity
	var inventory := AmmoInventory.new()
	var loading: LoadingProfile=definitions.vehicles[value.vehicle_id].loading_profile
	rack_ids=loading.initial_rack_order(rack_ids)
	if not inventory.configure_loadout(counts,rack_ids,capacities,value.first_shell,loading.initial_distribution): return _reject(LocalizationService.text("ui_3774b78e7ca6"))
	return {"ok":true,"loadout":{"vehicle_id":value.vehicle_id,"counts":counts,"first_shell":value.first_shell},"inventory":inventory.snapshot(),"options":ammo.options}

func install(vehicle: VehicleActor, loadout: Dictionary) -> bool:
	var checked := build_loadout(loadout)
	return checked.ok and vehicle.definition.id == loadout.vehicle_id and vehicle.gunner.configure_shell_loadout(checked.options,checked.loadout.counts,checked.loadout.first_shell)

static func _reject(reason: String) -> Dictionary: return {"ok":false,"reason":reason}
