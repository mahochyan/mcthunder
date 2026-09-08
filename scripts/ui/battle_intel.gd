class_name BattleIntel
extends Node
## The display receives only friendly telemetry and observations from its current observer.
var sensor := AIPerception.new()
var actor_provider: Callable
var observer_provider: Callable
var clock_provider: Callable
var observations: Array[Dictionary] = []
var _observer_life := -1
var _next_scan := 0.0
var current_clock := 0.0
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_physics_priority = 290
func _physics_process(_delta: float) -> void:
	if not observer_provider.is_valid() or not clock_provider.is_valid(): return
	var observer: VehicleActor = observer_provider.call()
	current_clock = float(clock_provider.call())
	if observer == null or observer.state.destroyed:
		observations.clear()
		return
	if observer.life_id != _observer_life:
		_observer_life = observer.life_id
		sensor.clear()
		observations.clear()
		_next_scan = current_clock
	if current_clock < _next_scan: return
	_next_scan = current_clock+0.3
	sensor.actor_provider = actor_provider
	observations = sensor.scan(observer,current_clock)
func visible_enemy(id: String, life: int) -> bool:
	for row in observations:
		if row.entity_id == id and row.life_id == life and row.visible and current_clock-row.last_seen <= 0.4: return true
	return false
func snapshot(player: VehicleActor) -> Dictionary:
	var markers: Array[Dictionary] = []
	if player == null: return {"markers":markers}
	if actor_provider.is_valid():
		for vehicle in actor_provider.call():
			if not is_instance_valid(vehicle) or vehicle.state.team_id != player.state.team_id or vehicle.state.destroyed: continue
			markers.append({"id":vehicle.entity_id,"life_id":vehicle.life_id,"kind":"self" if vehicle == player else "friend","position":vehicle.tank.global_position,"heading":vehicle.tank.global_rotation.y})
	for row in observations:
		var age := current_clock-float(row.last_seen)
		if age < 0 or age > AIPerception.MEMORY_SECONDS: continue
		markers.append({"id":row.entity_id,"life_id":row.life_id,"kind":"enemy" if row.visible else "last_seen","position":row.position,"age":age})
	return {"markers":markers,"clock":current_clock,"observer_life":_observer_life}
