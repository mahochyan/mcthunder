class_name AmmoInventory
extends RefCounted
## Ammunition has one location. Transfers never change total available rounds.
var racks: Dictionary = {}
var chamber := 0
var in_transfer := 0
var transfer_from := ""
var supplied := 0
var fired := 0
var lost := 0

func configure(total: int, rack_ids: Array = [], capacities: Dictionary = {}) -> void:
	racks.clear()
	chamber = 1 if total > 0 else 0
	in_transfer = 0
	transfer_from = ""
	supplied = maxi(total,0)
	fired = 0
	lost = 0
	var ids: Array = []
	for id in rack_ids:
		if not str(id).is_empty() and not ids.has(str(id)): ids.append(str(id))
	if ids.is_empty(): ids.append("reserve") # Explicit legacy fixture compartment.
	for id in ids: racks[str(id)] = 0
	var remaining := supplied-chamber
	if not capacities.is_empty():
		var capacity := 0
		for id in ids: capacity += maxi(0,int(capacities.get(id,0)))
		if capacity < supplied:
			push_error("AmmoInventory: declared rack capacity is below initial load")
			chamber = 0; supplied = 0
			return
		for i in ids.size():
			var available := maxi(0,int(capacities.get(ids[i],0))-(chamber if i == 0 else 0))
			var amount := mini(remaining,available)
			racks[str(ids[i])] = amount; remaining -= amount
		return
	for i in ids.size():
		var amount := ceili(float(remaining)/float(ids.size()-i))
		racks[str(ids[i])] = amount
		remaining -= amount

func total_available() -> int:
	var total := chamber+in_transfer
	for n in racks.values(): total += int(n)
	return total

func supply_round(amount: int, rack_id: String) -> bool:
	if amount <= 0 or not racks.has(rack_id): return false
	racks[rack_id] += amount
	supplied += amount
	return true

func conserved() -> bool:
	return total_available()+fired+lost == supplied and chamber in [0,1] and in_transfer in [0,1]

func consume_chamber() -> bool:
	if chamber != 1: return false
	chamber = 0
	fired += 1
	return true

func begin_transfer() -> bool:
	if chamber > 0 or in_transfer > 0: return false
	for id in racks:
		if int(racks[id]) > 0:
			racks[id] -= 1
			in_transfer = 1
			transfer_from = id
			return true
	return false

func finish_transfer() -> bool:
	if chamber > 0 or in_transfer != 1: return false
	chamber = 1
	in_transfer = 0
	transfer_from = ""
	return true

func cancel_transfer() -> void:
	if in_transfer == 1:
		racks[transfer_from] = int(racks.get(transfer_from,0))+1
		in_transfer = 0
		transfer_from = ""

func lose_all() -> void:
	lost += total_available()
	for id in racks: racks[id] = 0
	chamber = 0
	in_transfer = 0
	transfer_from = ""

func snapshot() -> Dictionary:
	return {"racks":racks.duplicate(true),"chamber":chamber,"in_transfer":in_transfer,
		"transfer_from":transfer_from,"available":total_available(),"supplied":supplied,"fired":fired,"lost":lost}
