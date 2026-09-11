class_name VehicleSimulationDriver
extends Node
## One roster, one physical step: no actor moves before every controller polls.
var actor_provider := Callable()
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_PAUSABLE
	process_physics_priority=SimulationPhases.VEHICLES
func _active(actor: Variant) -> bool:
	return is_instance_valid(actor) and not actor.is_queued_for_deletion() and actor.is_physics_processing() and actor.can_process()
func _physics_process(delta: float) -> void:
	if not actor_provider.is_valid(): return
	var actors: Array = actor_provider.call()
	actors=actors.filter(func(actor: VehicleActor) -> bool: return _active(actor))
	actors.sort_custom(func(a: VehicleActor,b: VehicleActor) -> bool: return a.entity_id<b.entity_id)
	var work: Array[Dictionary]=[]
	for actor in actors:
		if not _active(actor): continue
		var command: VehicleCommand = actor.collect_simulation_command(delta)
		if not _active(actor): continue
		work.append({"actor":actor,"command":command,"generation":actor.state.generation,"epoch":actor.control_epoch})
	for entry in work:
		if not _active(entry.actor): continue
		var actor: VehicleActor=entry.actor
		if not actor.simulation_step_valid(entry): continue
		entry["step"]=actor.begin_simulation_command(entry.command,delta)
	for phase in ["advance_simulation_drive","advance_simulation_aim","advance_simulation_mechanism","finish_simulation_command"]:
		for entry in work:
			if not _active(entry.actor): continue
			var actor: VehicleActor=entry.actor
			if not entry.has("step"): continue
			if phase=="finish_simulation_command": actor.finish_simulation_command(entry.step)
			else: actor.call(phase,entry.step,delta)
