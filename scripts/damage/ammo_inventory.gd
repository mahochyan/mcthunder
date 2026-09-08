class_name AmmoInventory
extends RefCounted
## One canonical location per round. Integer rack views are derived from typed stock.
const LEGACY := "__legacy__"
var _rack_shells: Dictionary = {}
var rack_capacities: Dictionary = {}
var capacity := 0
var typed := false
var chamber_shell := ""
var transfer_shell := ""
var selected_shell := LEGACY
var allowed_shells: Array = [LEGACY]
var transfer_from := ""
var supplied := 0
var fired := 0
var lost := 0
var racks: Dictionary:
	get:
		var out := {}
		for id in _rack_shells:
			out[id] = 0
			for n in _rack_shells[id].values(): out[id] += int(n)
		return out
var chamber: int:
	get: return 0 if chamber_shell.is_empty() else 1
var in_transfer: int:
	get: return 0 if transfer_shell.is_empty() else 1

func configure(total: int, rack_ids: Array = [], capacities: Dictionary = {}) -> void:
	typed = false
	allowed_shells = [LEGACY]; selected_shell = LEGACY
	_rack_shells.clear()
	rack_capacities = capacities.duplicate(true)
	chamber_shell = LEGACY if total > 0 else ""
	transfer_shell = ""; transfer_from = ""
	supplied = maxi(total,0); fired = 0; lost = 0
	var ids: Array = []
	for id in rack_ids:
		if not str(id).is_empty() and not ids.has(str(id)): ids.append(str(id))
	if ids.is_empty(): ids.append("reserve")
	for id in ids: _rack_shells[str(id)] = {LEGACY:0}
	capacity = 0
	for id in ids: capacity += maxi(0,int(capacities.get(id,0)))
	if capacities.is_empty(): capacity = maxi(supplied,30) # Legacy test fixture default.
	if capacity < supplied:
		push_error("AmmoInventory: declared rack capacity is below initial load")
		chamber_shell = ""; supplied = 0
		return
	var remaining := supplied-chamber
	for i in ids.size():
		var amount := ceili(float(remaining)/float(ids.size()-i)) if capacities.is_empty() else mini(remaining,maxi(0,int(capacities.get(ids[i],0))-(chamber if i == 0 else 0)))
		_rack_shells[str(ids[i])][LEGACY] = amount
		remaining -= amount

func configure_loadout(counts: Dictionary, rack_ids: Array, capacities: Dictionary, first_shell: String) -> bool:
	# Validate before replacing the current inventory.
	var total := 0
	var declared := 0
	if counts.is_empty() or not counts.has(first_shell) or rack_ids.is_empty(): return false
	for id in counts:
		if not id is String or id.is_empty() or not counts[id] is int or counts[id] < 0: return false
		total += int(counts[id])
	var unique := {}
	for id in rack_ids:
		if not id is String or id.is_empty() or unique.has(id) or not capacities.get(id) is int or capacities[id] < 0: return false
		unique[id] = true; declared += int(capacities[id])
	if total > declared or (total > 0 and int(counts[first_shell]) == 0): return false
	configure(0,rack_ids,capacities)
	typed = true; allowed_shells = counts.keys(); selected_shell = first_shell
	supplied = total
	var left := counts.duplicate(true)
	if total > 0:
		chamber_shell = first_shell; left[first_shell] -= 1
	for id in rack_ids: _rack_shells[id] = {}
	var chamber_deducted := false
	for id in rack_ids:
		var room := int(capacities[id])
		if chamber > 0 and room > 0 and not chamber_deducted:
			room -= 1; chamber_deducted = true
		for shell_id in left:
			var amount := mini(room,int(left[shell_id]))
			_rack_shells[id][shell_id] = amount; left[shell_id] -= amount; room -= amount
	return conserved()

func total_available() -> int:
	var total := chamber+in_transfer
	for n in racks.values(): total += int(n)
	return total

func shell_counts() -> Dictionary:
	var out := {}
	for id in allowed_shells: out[id] = 0
	for row in _rack_shells.values():
		for id in row: out[id] = int(out.get(id,0))+int(row[id])
	for id in [chamber_shell,transfer_shell]:
		if not id.is_empty(): out[id] = int(out.get(id,0))+1
	return out

func select_next(shell_id: String) -> bool:
	if not allowed_shells.has(shell_id): return false
	selected_shell = shell_id
	return true

func supply_round(amount: int, rack_id: String, shell_id: String = "") -> bool:
	if shell_id.is_empty(): shell_id = selected_shell
	if amount <= 0 or not _rack_shells.has(rack_id) or not allowed_shells.has(shell_id): return false
	if total_available()+amount > capacity: return false
	var occupied := int(racks[rack_id])+(in_transfer if transfer_from == rack_id else 0)
	if not rack_capacities.is_empty() and occupied+amount > int(rack_capacities.get(rack_id,0)): return false
	_rack_shells[rack_id][shell_id] = int(_rack_shells[rack_id].get(shell_id,0))+amount
	supplied += amount
	return true

func conserved() -> bool:
	if total_available()+fired+lost != supplied or total_available() > capacity or chamber+in_transfer > 1: return false
	for row in _rack_shells.values():
		for n in row.values():
			if not n is int or n < 0: return false
	return true

func consume_chamber() -> bool:
	if chamber != 1: return false
	chamber_shell = ""; fired += 1
	return true

func begin_transfer() -> bool:
	if chamber > 0 or in_transfer > 0: return false
	for id in _rack_shells:
		if int(_rack_shells[id].get(selected_shell,0)) > 0:
			_rack_shells[id][selected_shell] -= 1
			transfer_shell = selected_shell; transfer_from = id
			return true
	return false

func complete_load() -> bool:
	if chamber > 0 or in_transfer != 1: return false
	chamber_shell = transfer_shell; transfer_shell = ""; transfer_from = ""
	return true

func finish_transfer() -> bool:
	return complete_load()

func cancel_transfer() -> void:
	if in_transfer == 1:
		_rack_shells[transfer_from][transfer_shell] = int(_rack_shells[transfer_from].get(transfer_shell,0))+1
		transfer_shell = ""; transfer_from = ""

func lose_all() -> void:
	lost += total_available()
	for id in _rack_shells:
		for shell_id in _rack_shells[id]: _rack_shells[id][shell_id] = 0
	chamber_shell = ""; transfer_shell = ""; transfer_from = ""

func snapshot() -> Dictionary:
	return {"racks":racks,"rack_shells":_rack_shells.duplicate(true),"chamber":chamber,"in_transfer":in_transfer,
		"chamber_shell":chamber_shell,"transfer_shell":transfer_shell,"selected_shell":selected_shell,
		"transfer_from":transfer_from,"available":total_available(),"capacity":capacity,"shell_counts":shell_counts(),
		"supplied":supplied,"fired":fired,"lost":lost}
