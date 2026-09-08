class_name WreckRegistry
extends Node
## Retains actual actor collision/layout; cleanup is not another destruction event.
var protected_provider := Callable()
var max_count := RecoveryRules.WRECK_MAX_COUNT
var lifetime_s := RecoveryRules.WRECK_LIFETIME_SECONDS
var _entries: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func register(actor: VehicleActor) -> bool:
	if not is_instance_valid(actor) or not actor.state.destroyed: return false
	for entry in _entries:
		if entry.actor == actor and entry.generation == actor.state.generation: return false
	_prune_invalid()
	while _entries.size() >= max_count:
		var index := _oldest_unprotected()
		if index < 0: return false
		_remove(index)
	_entries.append({"actor":actor,"generation":actor.state.generation,"age":0.0})
	return true

func _physics_process(delta: float) -> void:
	_prune_invalid()
	for i in range(_entries.size()-1,-1,-1):
		_entries[i].age += delta
		if float(_entries[i].age) >= lifetime_s and not _protected(_entries[i].actor):
			_remove(i)

func _protected(actor: VehicleActor) -> bool:
	return protected_provider.is_valid() and protected_provider.call(actor)

func _oldest_unprotected() -> int:
	for i in _entries.size():
		if not _protected(_entries[i].actor): return i
	return -1

func _prune_invalid() -> void:
	for i in range(_entries.size()-1,-1,-1):
		var actor = _entries[i].actor
		if not is_instance_valid(actor) or not actor.state.destroyed or actor.state.generation != _entries[i].generation:
			_entries.remove_at(i)

func _remove(index: int) -> void:
	var actor: VehicleActor = _entries[index].actor
	_entries.remove_at(index)
	if is_instance_valid(actor): actor.queue_free()

func count() -> int:
	_prune_invalid()
	return _entries.size()

func clear_tracking() -> void:
	_entries.clear()
