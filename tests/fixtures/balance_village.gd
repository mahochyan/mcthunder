extends VillageRange
## Two fixed AI cohorts swap sides, including every natural respawn.
var swapped := false
func _configure_vehicle(vehicle: VehicleActor, id: String) -> void:
	super._configure_vehicle(vehicle,id)
	if vehicle.controller is AITankController:
		var cohort := 3-vehicle.state.team_id if swapped else vehicle.state.team_id
		var slot := 0 if id.length()==1 else int(id.substr(1))-1
		vehicle.controller._rng.seed=match_seed+cohort*100+slot*17+int(director.state.roster[id].spawns)*101
