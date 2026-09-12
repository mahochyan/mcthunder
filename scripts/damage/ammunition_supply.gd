class_name AmmunitionSupply
extends RefCounted
## Gameplay replenishment to the pre-battle typed manifest, one real rack transaction at a time.
const INTERVAL_S := 2.0
const RADIUS_M := 8.0
var clocks: Dictionary = {}
var status: Dictionary = {}

func step(vehicle: VehicleActor, delta: float, in_friendly_area: bool) -> void:
	if vehicle.get_tree()!=null and vehicle.get_tree().paused: return
	var key := str(vehicle.life_id)
	if not is_finite(delta) or delta<=0: return
	if not in_friendly_area:
		clocks.erase(key); status.erase(key); return
	if vehicle.state.destroyed or not vehicle.state.fires.is_empty() or vehicle.supply_motion_active or Vector2(vehicle.tank.velocity.x,vehicle.tank.velocity.z).length()>0.15:
		clocks.erase(key); status[key] = LocalizationService.text("ui_2300a90db445"); return
	var gun := vehicle.gunner
	var desired: Dictionary = gun.initial_shell_counts if gun.inventory.typed else {AmmoInventory.LEGACY:gun.weapon.initial_rounds}
	var current := gun.inventory.shell_counts()
	var selected := ""
	for id in desired:
		if int(current.get(id,0)) < int(desired[id]): selected = id; break
	if selected.is_empty(): clocks.erase(key); status[key] = LocalizationService.text("ui_2121f301dce2"); return
	clocks[key] = float(clocks.get(key,0))+delta
	status[key] = LocalizationService.text("ui_2b2ab656a7d2")%float(clocks[key])
	if float(clocks[key])+1e-8 < INTERVAL_S: return
	for rack in gun.supply_racks():
		if gun.rack_usable(rack) and gun.inventory.supply_round(1,rack,selected):
			clocks[key] = maxf(0,float(clocks[key])-INTERVAL_S)
			status[key] = "+1 "+gun.shell_label(selected)
			# Replenishing an empty chamber still starts a complete ordinary loading cycle.
			gun.request_load()
			return
	clocks[key] = 0.0; status[key] = LocalizationService.text("ui_516a7bbda1e5")
