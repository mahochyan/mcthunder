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
var chamber_from := ""
var _rack_move: Dictionary = {}
var _move_sequence := 0
## WT-CD-001 design point 2 / CD01-T06: a signature of the current dynamic occupancy, so a query snapshot can state
## which occupancy it was taken from and a stale request can be refused instead of being answered from old data. It is
## derived from the state itself - rack contents, carried round, chamber, losses and reservations - so no mutation site
## can forget to update it.
var occupancy_revision: int:
	get:
		return hash([racks,chamber_shell,transfer_shell,transfer_from,chamber_from,fired,supplied,lost,_move_sequence,_rack_move])
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
	chamber_from=""; _rack_move.clear()
	supplied = maxi(total,0); fired = 0; lost = 0
	var ids: Array = []
	for id in rack_ids:
		if not str(id).is_empty() and not ids.has(str(id)): ids.append(str(id))
	if ids.is_empty(): ids.append("reserve")
	if chamber>0:
		for id in ids:
			if capacities.is_empty() or int(capacities.get(id,0))>0: chamber_from=str(id); break
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

func configure_loadout(counts: Dictionary, rack_ids: Array, capacities: Dictionary, first_shell: String, distribution: String = "sequential") -> bool:
	# Validate before replacing the current inventory.
	if distribution not in ["sequential","proportional"]: return false
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
			room -= 1; chamber_deducted = true; chamber_from=id
		if distribution=="proportional":
			var allocation := proportional_allocation(left,room)
			for shell_id in allocation:
				_rack_shells[id][shell_id]=allocation[shell_id]; left[shell_id]-=allocation[shell_id]
			continue
		for shell_id in left:
			var amount := mini(room,int(left[shell_id]))
			_rack_shells[id][shell_id] = amount; left[shell_id] -= amount; room -= amount
	return conserved()

static func proportional_allocation(left: Dictionary, room: int) -> Dictionary:
	# Largest remainders distribute only physical rounds. Stable ID tie breaks make
	# initial stowage independent of JSON/dictionary insertion order.
	var total := 0
	for count in left.values(): total+=int(count)
	var take := mini(room,total)
	var allocation := {}; var ranked: Array=[]; var assigned := 0
	var ids: Array=left.keys(); ids.sort()
	for id in ids:
		var amount := floori(float(take)*float(left[id])/float(total)) if total>0 else 0
		allocation[id]=amount; assigned+=amount
		ranked.append({"id":id,"remainder":(take*int(left[id]))%total if total>0 else 0})
	if total==0: return allocation
	ranked.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		return a.remainder>b.remainder if a.remainder!=b.remainder else a.id<b.id)
	for i in take-assigned: allocation[ranked[i].id]+=1
	return allocation

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
	if not rack_capacities.is_empty() and rack_occupied(rack_id)+amount > int(rack_capacities.get(rack_id,0)): return false
	_rack_shells[rack_id][shell_id] = int(_rack_shells[rack_id].get(shell_id,0))+amount
	supplied += amount
	return true

func conserved() -> bool:
	if total_available()+fired+lost != supplied or total_available() > capacity or chamber+in_transfer > 1: return false
	for row in _rack_shells.values():
		for n in row.values():
			if not n is int or n < 0: return false
	for id in rack_capacities:
		if rack_occupied(id)>int(rack_capacities[id]): return false
	if not _rack_move.is_empty() and int(_rack_shells.get(_rack_move.from,{}).get(_rack_move.shell,0))<1: return false
	return true

func consume_chamber() -> bool:
	if chamber != 1: return false
	chamber_shell = ""; chamber_from=""; fired += 1
	return true

func begin_transfer() -> bool:
	if chamber > 0 or in_transfer > 0: return false
	for id in _rack_shells:
		if begin_transfer_from(id,selected_shell): return true
	return false

func available_in_rack(rack_id: String, shell_id: String) -> int:
	var reserved := 1 if _rack_move.get("from","")==rack_id and _rack_move.get("shell","")==shell_id else 0
	return maxi(0,int(_rack_shells.get(rack_id,{}).get(shell_id,0))-reserved)

func rack_occupied(rack_id: String) -> int:
	return int(racks.get(rack_id,0))+(chamber if chamber_from==rack_id else 0)+(in_transfer if transfer_from==rack_id else 0)+(1 if _rack_move.get("to","")==rack_id else 0)

func begin_transfer_from(rack_id: String, shell_id: String) -> bool:
	if chamber>0 or in_transfer>0 or shell_id not in allowed_shells or available_in_rack(rack_id,shell_id)<1: return false
	_rack_shells[rack_id][shell_id]-=1
	transfer_shell=shell_id; transfer_from=rack_id
	return true

func reserve_rack_move(from: String, to: String, shell_id: String) -> Dictionary:
	if not _rack_move.is_empty() or from==to or not _rack_shells.has(to) or not rack_capacities.has(to) or available_in_rack(from,shell_id)<1: return {"ok":false}
	if rack_occupied(to)>=int(rack_capacities[to]): return {"ok":false}
	_move_sequence+=1
	_rack_move={"token":_move_sequence,"from":from,"to":to,"shell":shell_id}
	return {"ok":true,"token":_move_sequence}

func commit_rack_move(token: int) -> bool:
	if _rack_move.is_empty() or _rack_move.token!=token: return false
	var move := _rack_move.duplicate()
	if int(_rack_shells.get(move.from,{}).get(move.shell,0))<1 or rack_occupied(move.to)>int(rack_capacities.get(move.to,0)): return false
	_rack_shells[move.from][move.shell]-=1
	_rack_shells[move.to][move.shell]=int(_rack_shells[move.to].get(move.shell,0))+1
	_rack_move.clear()
	return true

func cancel_rack_move(token: int) -> bool:
	if _rack_move.is_empty() or _rack_move.token!=token: return false
	_rack_move.clear()
	return true

func rack_move_snapshot() -> Dictionary: return _rack_move.duplicate(true)
func has_rack_move() -> bool: return not _rack_move.is_empty()

func complete_load() -> bool:
	if chamber > 0 or in_transfer != 1: return false
	chamber_shell = transfer_shell; chamber_from=transfer_from; transfer_shell = ""; transfer_from = ""
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
	chamber_from=""; _rack_move.clear()

func lose_rack(rack_id: String) -> Dictionary:
	# Stored rounds only. Chamber and the carried loading round are distinct physical
	# locations. Cancel a reservation without resurrecting its already-lost source.
	if not _rack_shells.has(rack_id): return {}
	var removed: Dictionary=_rack_shells[rack_id].duplicate(true)
	for id in _rack_shells[rack_id]:
		lost+=int(_rack_shells[rack_id][id]); _rack_shells[rack_id][id]=0
	if not _rack_move.is_empty() and (_rack_move.from==rack_id or _rack_move.to==rack_id): _rack_move.clear()
	return removed

func snapshot() -> Dictionary:
	return {"racks":racks,"rack_shells":_rack_shells.duplicate(true),"chamber":chamber,"in_transfer":in_transfer,
		"chamber_shell":chamber_shell,"transfer_shell":transfer_shell,"selected_shell":selected_shell,
		"transfer_from":transfer_from,"available":total_available(),"capacity":capacity,"shell_counts":shell_counts(),
		"supplied":supplied,"fired":fired,"lost":lost,"chamber_from":chamber_from,"rack_move":rack_move_snapshot()}

## WT-CD-001 design point 2 and CD01-T06: an immutable view of the five ammunition states - stowed in each rack,
## reserved by a pending rack move, carried in the loader, chambered, and lost - together with the revision it was
## taken from. Fixed structures are deliberately absent: the rack structure and the compartment barrier are separate
## entities with their own hit and resistance rules, so an exhausted contents volume never removes them.
func occupancy_snapshot() -> Dictionary:
	var reserved := {}
	if not _rack_move.is_empty(): reserved[str(_rack_move.get("to",""))] = int(reserved.get(str(_rack_move.get("to","")),0)) + 1
	return {"stowed":racks.duplicate(),"reserved":reserved,"carried":in_transfer,"carried_shell":transfer_shell,
		"carried_from":transfer_from,"chambered":chamber,"chamber_shell":chamber_shell,"chamber_from":chamber_from,
		"lost":lost,"revision":occupancy_revision}
