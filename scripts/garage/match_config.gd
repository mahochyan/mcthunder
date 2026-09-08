class_name MatchConfig
extends RefCounted
## Nested state never escapes by reference. The garage validates before creating a snapshot.
var _data: Dictionary = {}

static func build(value: Dictionary, service: GarageService, unlocked: Array) -> Dictionary:
	for field in ["mode","selected_vehicle_id","map","difficulty"]:
		if not value.get(field) is String: return {"ok":false,"reason":"出战设置格式无效"}
	if value.map != "hill_village" or value.difficulty not in ["easy","normal","hard"]: return {"ok":false,"reason":"地图或难度不可用"}
	if not value.get("lineup") is Array or not value.get("loadouts") is Dictionary: return {"ok":false,"reason":"缺少编成或配弹"}
	var lineup := Lineup.validate(value.lineup,value.selected_vehicle_id,value.mode,unlocked)
	if not lineup.ok: return lineup
	var copied := {}
	for id in lineup.ids:
		if not value.loadouts.get(id) is Dictionary: return {"ok":false,"reason":"编成车辆缺少配弹"}
		var checked := service.build_loadout(value.loadouts[id])
		if not checked.ok: return checked
		if checked.loadout.vehicle_id != id: return {"ok":false,"reason":"配弹车型与编成不符"}
		copied[id] = checked.loadout
	var config := MatchConfig.new()
	config._data = {"mode":value.mode,"selected_vehicle_id":value.selected_vehicle_id,"map":value.map,"difficulty":value.difficulty,"lineup":lineup.ids,"loadouts":copied}
	return {"ok":true,"config":config}

func snapshot() -> Dictionary: return _data.duplicate(true)
func loadout(id: String) -> Dictionary: return _data.get("loadouts",{}).get(id,{}).duplicate(true)
func vehicle_ids() -> Array: return _data.get("lineup",[]).duplicate()
func selected() -> String: return str(_data.get("selected_vehicle_id",""))
func difficulty() -> String: return str(_data.get("difficulty","normal"))
func mode() -> String: return str(_data.get("mode","training"))
