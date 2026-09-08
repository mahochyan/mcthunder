class_name TicketLedger
extends RefCounted
static func apply_events(state: TeamMatchState, owned_seconds: Dictionary) -> Array[String]:
	var dead: Array[String] = []
	if state.phase != "playing": return dead
	for key in state.pending_deaths:
		if state.seen_deaths.has(key): continue
		var record: Dictionary = state.pending_deaths[key]
		var id: String = record.entity_id
		var row: Dictionary = state.roster[id]
		state.seen_deaths[key] = true
		state.tickets[row.team] = maxi(0,int(state.tickets[row.team])-TeamMatchState.DEATH_COST)
		row.deaths += 1
		row.respawn_at = state.elapsed+TeamMatchState.RESPAWN_DELAY
		row.protection_left = 0.0
		row.waiting_reason = "countdown"
		row.respawn_requested = not row.player
		dead.append(id)
		state.record("death",{"entity_id":id,"life_id":record.life_id,"team":row.team,"cause":record.get("cause","unknown")})
	state.pending_deaths.clear()
	for owner in [1,2]:
		var enemy: int = 3-owner
		state.drain_bank[enemy] += maxf(0,float(owned_seconds.get(owner,0)))
		var loss := int(floor(float(state.drain_bank[enemy])+1e-8))
		state.drain_bank[enemy] -= loss
		state.tickets[enemy] = maxi(0,int(state.tickets[enemy])-loss)
	return dead

static func result_after_tick(state: TeamMatchState) -> String:
	if state.phase != "playing": return ""
	if state.tickets[1] <= 0 and state.tickets[2] <= 0: return "draw"
	if state.tickets[1] <= 0: return "defeat"
	if state.tickets[2] <= 0: return "victory"
	if state.elapsed >= TeamMatchState.TIME_LIMIT:
		if state.tickets[1] == state.tickets[2]: return "draw"
		return "victory" if state.tickets[1] > state.tickets[2] else "defeat"
	return ""
