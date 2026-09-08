class_name GarageService
extends RefCounted
var catalog := VehicleCatalog.new()
var definitions := VehicleDefs.new()
var ready := false

func _init() -> void:
	ready = catalog.load_all(definitions).ok

func default_loadout(id: String) -> Dictionary:
	if not ready or not catalog.packages.has(id): return {}
	var ammo := HistoricalShellCatalog.build(catalog.packages[id].packet)
	if not ammo.ok: return {}
	var total: int = int(catalog.packages[id].packet.runtime.rounds)
	var alternate := floori(total*0.3)
	var counts := {}
	for option in ammo.options: counts[option.id] = total-alternate if option.id == ammo.default_id else alternate
	return {"vehicle_id":id,"counts":counts,"first_shell":ammo.default_id}

func build_loadout(value: Dictionary) -> Dictionary:
	if not value.get("vehicle_id") is String or not catalog.packages.has(value.vehicle_id): return _reject("车型不可用")
	if not value.get("counts") is Dictionary or not value.get("first_shell") is String: return _reject("配弹格式无效")
	var pack: Dictionary = catalog.packages[value.vehicle_id]
	var ammo := HistoricalShellCatalog.build(pack.packet)
	if not ammo.ok: return _reject("弹种资料未通过校验")
	var expected: Array = []
	for option in ammo.options: expected.append(option.id)
	if value.counts.size() != expected.size(): return _reject("必须指定该车两个弹种的数量")
	var counts := {}
	var total := 0
	for id in value.counts:
		if id not in expected: return _reject("该车不能使用所选弹种")
		if not value.counts[id] is int or value.counts[id] < 0: return _reject("弹药数量必须为非负整数")
		counts[id] = value.counts[id]; total += int(counts[id])
	if total <= 0: return _reject("至少携带一发炮弹")
	var rack_ids: Array = []
	var capacities := {}
	for module in pack.layout.modules:
		if module.kind == "ammo": rack_ids.append(module.id); capacities[module.id] = module.ammo_capacity
	var inventory := AmmoInventory.new()
	if not inventory.configure_loadout(counts,rack_ids,capacities,value.first_shell): return _reject("配弹超过容量，或首发弹种没有余弹")
	return {"ok":true,"loadout":{"vehicle_id":value.vehicle_id,"counts":counts,"first_shell":value.first_shell},"inventory":inventory.snapshot(),"options":ammo.options}

func install(vehicle: VehicleActor, loadout: Dictionary) -> bool:
	var checked := build_loadout(loadout)
	return checked.ok and vehicle.definition.id == loadout.vehicle_id and vehicle.gunner.configure_shell_loadout(checked.options,checked.loadout.counts,checked.loadout.first_shell)

static func _reject(reason: String) -> Dictionary: return {"ok":false,"reason":reason}
