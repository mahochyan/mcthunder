class_name NetworkEventJournal
extends RefCounted
## Bounded public projectile facts for the local authority slice. Transport and
## world snapshots are deliberately outside this class. A history eviction is
## an explicit resync requirement, never an invented successful replay.
const VERSION := 1
const CAPACITY := 256
const BATCH_LIMIT := 16
const MAX_ACTIVE := 64 # Matches the current ProjectileManager limit.
const MAX_SHOOTERS := 64
const MAX_SAFE_INTEGER := 9007199254740991
const MAX_EVENT_BYTES := 1024
const MAX_BATCH_BYTES := 24576
const POSITION_LIMIT := 1000000.0
const SPEED_LIMIT := 10000.0
const GRAVITY_LIMIT := 1000.0
var session_id := ""
var _head := 0
var _last_tick := -1
var _max_projectile_id := 0
var _events: Array[Dictionary] = []
var _active: Dictionary = {} # Projectile id -> complete original fired event.
var _shooters: Dictionary = {} # Entity id -> latest accepted shot identity.

static func integer(value: Variant, minimum: int = 0) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=minimum and float(value)<=MAX_SAFE_INTEGER and float(value)==floor(float(value))

static func identifier(value: Variant, maximum: int = 64) -> bool:
	if not value is String or value.is_empty() or value.length()>maximum: return false
	for i in value.length():
		var c: int=value.unicode_at(i)
		if not (c>=48 and c<=57 or c>=65 and c<=90 or c>=97 and c<=122 or c in [45,46,58,95]): return false
	return true

static func valid_session(value: Variant) -> bool:
	if not value is String or value.length()!=32: return false
	for i in value.length():
		var c: int=value.unicode_at(i)
		if not (c>=48 and c<=57 or c>=97 and c<=102): return false
	return true

static func vector(value: Variant, limit: float) -> bool:
	if not value is Array or value.size()!=3: return false
	for component in value:
		if not (component is int or component is float) or not is_finite(float(component)) or absf(float(component))>limit: return false
	return true

static func valid_shot(value: Variant) -> bool:
	if not value is Dictionary or value.size()!=5 or not identifier(value.get("shooter_id")): return false
	for key in ["round_id","projectile_id","shooter_life_id","shot_id"]:
		if not integer(value.get(key),1): return false
	return true

static func valid_event(value: Variant) -> bool:
	if not value is Dictionary or value.size()!=6: return false
	if not integer(value.get("version"),1) or value.version!=VERSION: return false
	if not integer(value.get("sequence"),1) or not integer(value.get("tick")): return false
	if value.get("kind") not in ["projectile_fired","projectile_finished"] or not valid_shot(value.get("shot")): return false
	var payload: Variant=value.get("payload")
	if not payload is Dictionary or not vector(payload.get("position"),POSITION_LIMIT): return false
	if value.kind=="projectile_fired":
		if payload.size()!=4 or not identifier(payload.get("shell_id")) or not vector(payload.get("velocity"),SPEED_LIMIT) or not vector(payload.get("gravity"),GRAVITY_LIMIT): return false
		var speed := Vector3(payload.velocity[0],payload.velocity[1],payload.velocity[2]).length()
		if speed<=0 or speed>SPEED_LIMIT: return false
	else:
		if payload.size()!=2 or not identifier(payload.get("reason")): return false
	return JSON.stringify(value).to_utf8_buffer().size()<=MAX_EVENT_BYTES

static func valid_batch(value: Variant) -> bool:
	if not value is Dictionary or value.size()!=5 or not integer(value.get("version"),1) or value.version!=VERSION: return false
	if not valid_session(value.get("session_id")) or not integer(value.get("after")) or not integer(value.get("head")) or value.after>value.head: return false
	if not value.get("events") is Array or value.events.size()>BATCH_LIMIT: return false
	if value.events.is_empty() and value.after!=value.head: return false
	var expected := int(value.after)
	var previous_tick := -1
	var highest_projectile := 0
	var fired: Dictionary={}
	var finished: Dictionary={}
	for event in value.events:
		if not valid_event(event) or expected==MAX_SAFE_INTEGER: return false
		expected+=1
		if event.sequence!=expected or event.sequence>value.head or event.tick<previous_tick: return false
		previous_tick=int(event.tick)
		var projectile_id := int(event.shot.projectile_id)
		var identity := _shot_copy(event.shot)
		if event.kind=="projectile_fired":
			if projectile_id<=highest_projectile: return false
			fired[projectile_id]=identity
		else:
			if finished.has(projectile_id) or (fired.has(projectile_id) and fired[projectile_id]!=identity): return false
			finished[projectile_id]=true
		highest_projectile=maxi(highest_projectile,projectile_id)
	return JSON.stringify(value).to_utf8_buffer().size()<=MAX_BATCH_BYTES

func reset(next_session: Variant) -> bool:
	# Invalid reset cannot erase an already valid session's evidence.
	if not valid_session(next_session) or next_session==session_id: return false
	session_id=next_session; _head=0; _last_tick=-1; _max_projectile_id=0
	_events.clear(); _active.clear(); _shooters.clear()
	return true

func head() -> int: return _head
func oldest() -> int: return int(_events[0].sequence) if not _events.is_empty() else _head+1
func retained_count() -> int: return _events.size()
func active_count() -> int: return _active.size()
func has_active(projectile_id: int) -> bool: return _active.has(projectile_id)
func active_fired_events() -> Array:
	# Launch facts only. A resync's current in-flight poses must come from the
	# world's live projectile states; these old origins must not masquerade as them.
	return _active.values().duplicate(true)

static func _shot_copy(value: Dictionary) -> Dictionary:
	return {"round_id":int(value.round_id),"projectile_id":int(value.projectile_id),"shooter_id":str(value.shooter_id),"shooter_life_id":int(value.shooter_life_id),"shot_id":int(value.shot_id)}

static func valid_projectiles(value: Variant) -> bool:
	if not value is Array or value.size()>MAX_ACTIVE: return false
	var ids := {}
	for projectile in value:
		if not projectile is Dictionary or projectile.size()!=6 or not valid_shot(projectile.get("shot")) or not identifier(projectile.get("shell_id")): return false
		var id := int(projectile.shot.projectile_id)
		if ids.has(id): return false
		ids[id]=true
		for field in ["position","velocity","gravity"]:
			var limit: float={"position":POSITION_LIMIT,"velocity":SPEED_LIMIT,"gravity":GRAVITY_LIMIT}[field]
			if not vector(projectile.get(field),limit): return false
		var age: Variant=projectile.get("age_s")
		if not (age is int or age is float) or not is_finite(float(age)) or age<0 or age>3600: return false
	return true

static func valid_checkpoint(value: Variant, snapshot: Dictionary) -> bool:
	if not value is Dictionary or value.size()!=6 or not integer(value.get("version"),1) or value.version!=VERSION: return false
	if not valid_session(value.get("session_id")) or value.session_id!=snapshot.get("session_id"): return false
	if not integer(value.get("cursor")) or value.cursor!=snapshot.get("event_sequence") or not integer(value.get("after")) or value.after>value.cursor: return false
	if value.get("reason") not in ["initial","new_session","history_evicted"]: return false
	if value.reason=="history_evicted" and value.after==value.cursor: return false
	if value.reason!="history_evicted" and value.after!=0: return false
	return valid_projectiles(value.get("active_projectiles"))

func append(kind: Variant, tick: Variant, shot: Variant, payload: Variant) -> Dictionary:
	if not valid_session(session_id): return {"ok":false,"reason":"session_required"}
	if _head==MAX_SAFE_INTEGER: return {"ok":false,"reason":"sequence_exhausted"}
	var candidate := {"version":VERSION,"sequence":_head+1,"tick":tick,"kind":kind,"shot":shot,"payload":payload}
	if not valid_event(candidate): return {"ok":false,"reason":"invalid_event"}
	if int(tick)<_last_tick: return {"ok":false,"reason":"tick_regression"}
	var identity := _shot_copy(shot)
	var projectile_id: int=identity.projectile_id
	var entity: String=identity.shooter_id
	if kind=="projectile_fired":
		if projectile_id<=_max_projectile_id: return {"ok":false,"reason":"projectile_reused_or_out_of_order"}
		if _active.size()>=MAX_ACTIVE: return {"ok":false,"reason":"active_capacity"}
		if not _shooters.has(entity) and _shooters.size()>=MAX_SHOOTERS: return {"ok":false,"reason":"shooter_capacity"}
		if _shooters.has(entity):
			var before: Dictionary=_shooters[entity]
			if identity.round_id<before.round_id or identity.shooter_life_id<before.shooter_life_id:
				return {"ok":false,"reason":"stale_shooter_identity"}
			if identity.round_id==before.round_id and identity.shooter_life_id==before.shooter_life_id and identity.shot_id<=before.shot_id:
				return {"ok":false,"reason":"shot_reused_or_out_of_order"}
	else:
		if not _active.has(projectile_id): return {"ok":false,"reason":"finish_without_active_fire"}
		if _active[projectile_id].shot!=identity: return {"ok":false,"reason":"finish_identity_mismatch"}
	# All checks finish before any mutation, including admission watermarks.
	candidate.tick=int(tick); candidate.shot=identity; candidate.payload=payload.duplicate(true)
	if kind=="projectile_fired":
		_active[projectile_id]=candidate.duplicate(true)
		_shooters[entity]=identity.duplicate(true)
		_max_projectile_id=projectile_id
	else: _active.erase(projectile_id)
	_head+=1; _last_tick=int(tick)
	_events.append(candidate.duplicate(true))
	if _events.size()>CAPACITY: _events.pop_front()
	return {"ok":true,"event":candidate.duplicate(true)}

func read_after(cursor: Variant, limit: int = BATCH_LIMIT) -> Dictionary:
	if not valid_session(session_id): return {"ok":false,"reason":"session_required"}
	if not integer(cursor) or limit<1 or limit>BATCH_LIMIT: return {"ok":false,"reason":"invalid_cursor_or_limit"}
	if int(cursor)>_head: return {"ok":false,"reason":"future_cursor"}
	if int(cursor)<oldest()-1:
		return {"ok":false,"reason":"history_evicted","resync":true,"session_id":session_id,"requested_after":int(cursor),"oldest":oldest(),"head":_head}
	var records: Array=[]
	for event in _events:
		if int(event.sequence)<=int(cursor): continue
		records.append(event.duplicate(true))
		if records.size()==limit: break
	return {"ok":true,"mode":"delta","batch":{"version":VERSION,"session_id":session_id,"after":int(cursor),"head":_head,"events":records}}

static func consume_batch(value: Variant, expected_session: String, cursor: Variant) -> Dictionary:
	# This returns a proposal. The client commits cursor and emits events only
	# after accepting the whole result; malformed suffixes cannot partially apply.
	if not valid_batch(value) or not valid_session(expected_session) or not integer(cursor): return {"ok":false,"reason":"invalid_batch"}
	if value.session_id!=expected_session: return {"ok":false,"reason":"wrong_session"}
	if int(value.after)>int(cursor): return {"ok":false,"reason":"gap","expected_sequence":int(cursor)+1}
	var next := int(cursor)
	var delivered: Array=[]
	for event in value.events:
		if int(event.sequence)<=next: continue
		if int(event.sequence)!=next+1: return {"ok":false,"reason":"gap","expected_sequence":next+1}
		delivered.append(event.duplicate(true)); next+=1
	return {"ok":true,"cursor":next,"head":maxi(next,int(value.head)),"events":delivered}

static func acknowledge(value: Variant, expected_session: String, previous: Variant, last_sent: Variant) -> Dictionary:
	if not value is Dictionary or value.size()!=2 or not valid_session(value.get("session_id")) or not integer(value.get("cursor")) or not valid_session(expected_session) or not integer(previous) or not integer(last_sent) or previous>last_sent:
		return {"ok":false,"reason":"invalid_ack"}
	if value.session_id!=expected_session: return {"ok":false,"reason":"wrong_session"}
	if value.cursor<previous: return {"ok":false,"reason":"stale_ack"}
	if value.cursor>last_sent: return {"ok":false,"reason":"unsent_ack"}
	return {"ok":true,"cursor":int(value.cursor)}
