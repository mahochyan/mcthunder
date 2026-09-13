class_name SupportActions
extends RefCounted
## WT-018: auxiliary weapons, smoke, recon, repair assist and tow as one authority-side
## state machine.
##
## Rules encoded here:
##  * capabilities are per vehicle (a vehicle without one is REFUSED, never silently
##    given a universal machine gun); the training vehicle deliberately has none.
##  * auxiliary ammunition lives in its own pool per (vehicle, life): the main gun
##    inventory is never touched, and switching vehicles cannot carry ammo across.
##  * a deployed smoke cloud is ONE shared object that AI, network and replay all read;
##    replay/spectator may never spawn or refresh one.
##  * recon marks expire and say so; repair assist and tow are separate actions with
##    explicit cancel reasons and boundary refusals.
##  * a client request may not author inventory or repair amounts - only the authority
##    advances these counters.

## Game-design values, not historical performance. Vehicles absent from this table have
## no auxiliary capability at all.
const CAPABILITIES := {
	"us_m4a3_75w_vvss_1944":{
		"aux_weapons":[{"id":"hull_mg_30","caliber_mm":7.62,"ammo_capacity":600,"cooldown_s":0.12,"reload_s":4.0,"yaw_deg":15.0,"pitch_deg":[-10.0,20.0]}],
		"smoke":{"count":6,"reload_s":12.0,"cloud_radius_m":18.0,"cloud_duration_s":20.0},
		"recon":{"spot_duration_s":15.0,"mark_precision_m":15.0},"repair_assist":true,"tow":true},
	"us_m24_chaffee":{
		"aux_weapons":[{"id":"coax_mg_30","caliber_mm":7.62,"ammo_capacity":400,"cooldown_s":0.12,"reload_s":4.0,"yaw_deg":0.0,"pitch_deg":[-8.0,15.0]},
			{"id":"hull_mg_50","caliber_mm":12.7,"ammo_capacity":200,"cooldown_s":0.25,"reload_s":6.0,"yaw_deg":15.0,"pitch_deg":[-10.0,20.0]}],
		"smoke":{"count":4,"reload_s":12.0,"cloud_radius_m":15.0,"cloud_duration_s":18.0},
		"recon":{"spot_duration_s":15.0,"mark_precision_m":15.0},"repair_assist":true,"tow":true},
	"us_m26_pershing":{
		"aux_weapons":[{"id":"coax_mg_30","caliber_mm":7.62,"ammo_capacity":500,"cooldown_s":0.12,"reload_s":4.0,"yaw_deg":0.0,"pitch_deg":[-8.0,15.0]},
			{"id":"hull_mg_50","caliber_mm":12.7,"ammo_capacity":300,"cooldown_s":0.25,"reload_s":6.0,"yaw_deg":15.0,"pitch_deg":[-10.0,20.0]}],
		"smoke":{"count":6,"reload_s":12.0,"cloud_radius_m":18.0,"cloud_duration_s":20.0},
		"recon":{"spot_duration_s":15.0,"mark_precision_m":15.0},"repair_assist":true,"tow":true},
	"us_m36_jackson":{
		"aux_weapons":[{"id":"hull_mg_50","caliber_mm":12.7,"ammo_capacity":300,"cooldown_s":0.25,"reload_s":6.0,"yaw_deg":15.0,"pitch_deg":[-10.0,20.0]}],
		"smoke":{"count":4,"reload_s":12.0,"cloud_radius_m":15.0,"cloud_duration_s":18.0},
		"recon":{"spot_duration_s":15.0,"mark_precision_m":15.0},"repair_assist":true,"tow":true},
	# The training vehicle (and any vehicle not listed) has NO auxiliary capability:
	# absent equipment is refused rather than invented.
	"player_tank":{"aux_weapons":[],"smoke":null,"recon":null,"repair_assist":true,"tow":false},
}

const AUX_SOURCES := ["authority","local_player","ai"]
const SPAWN_SOURCES := ["authority","local_player","ai"]

var vehicle_id := ""
var life_id := -1
var aux_pools: Dictionary = {}          # weapon_id -> {remaining, ready_at}
var smoke_stock := 0
var smoke_ready_at := 0.0
var smoke_clouds: Array[Dictionary] = []
var recon_marks: Dictionary = {}        # entity_id -> {life_id, position, source, expires_at, precision_m}
var repair_target := ""
var repair_cancelled_reason := ""
var tow_target := ""
var tow_cancel_reason := ""
var refusals: Array[String] = []

static func capability_for(id: String) -> Dictionary:
	return CAPABILITIES.get(id,{"aux_weapons":[],"smoke":null,"recon":null,"repair_assist":false,"tow":false})

static func is_capable(id: String) -> bool:
	return CAPABILITIES.has(id)

func begin(vehicle: String, life: int) -> void:
	# Per (vehicle, life): switching vehicles or respawning never carries aux ammo over.
	vehicle_id = vehicle
	life_id = life
	aux_pools.clear()
	var cap := capability_for(vehicle)
	for spec in cap.get("aux_weapons",[]):
		aux_pools[str(spec.id)] = {"remaining":int(spec.ammo_capacity),"ready_at":0.0}
	var smoke: Variant = cap.get("smoke")
	smoke_stock = int(smoke.count) if smoke != null else 0
	smoke_ready_at = 0.0
	smoke_clouds.clear()
	recon_marks.clear()
	repair_target = ""
	repair_cancelled_reason = ""
	tow_target = ""
	tow_cancel_reason = ""
	refusals.clear()

func aux_weapons() -> Array:
	return capability_for(vehicle_id).get("aux_weapons",[]).duplicate(true)

func aux_weapon(weapon_id: String) -> Dictionary:
	for spec in aux_weapons():
		if str(spec.id) == weapon_id: return spec
	return {}

func aux_pool(weapon_id: String) -> Dictionary:
	return (aux_pools.get(weapon_id,{}) as Dictionary).duplicate(true)

func fire_aux(weapon_id: String, now: float) -> Dictionary:
	var spec := aux_weapon(weapon_id)
	if spec.is_empty():
		refusals.append("no_aux_capability:%s"%weapon_id)
		return {"ok":false,"reason":"no_aux_capability"}
	var pool: Dictionary = aux_pools.get(weapon_id,{})
	if int(pool.get("remaining",0)) <= 0:
		refusals.append("aux_depleted:%s"%weapon_id)
		return {"ok":false,"reason":"aux_depleted"}
	if now < float(pool.get("ready_at",0.0)):
		refusals.append("aux_cooldown:%s"%weapon_id)
		return {"ok":false,"reason":"aux_cooldown"}
	pool["remaining"] = int(pool.remaining)-1
	pool["ready_at"] = now+float(spec.cooldown_s)
	aux_pools[weapon_id] = pool
	return {"ok":true,"weapon_id":weapon_id,"remaining":int(pool.remaining),"caliber_mm":float(spec.caliber_mm)}

## Smoke: authority-only spawn, real stock, bounded reload, and ONE shared cloud object.
func deploy_smoke(now: float, position: Vector3, source: String = "authority") -> Dictionary:
	if not SPAWN_SOURCES.has(source):
		# replay and spectator read the cloud list, they never create or refresh clouds
		refusals.append("replay_cannot_spawn_smoke:%s"%source)
		return {"ok":false,"reason":"replay_cannot_spawn_smoke"}
	var smoke: Variant = capability_for(vehicle_id).get("smoke")
	if smoke == null:
		refusals.append("no_smoke_capability")
		return {"ok":false,"reason":"no_smoke_capability"}
	if smoke_stock <= 0:
		refusals.append("smoke_depleted")
		return {"ok":false,"reason":"smoke_depleted"}
	if now < smoke_ready_at:
		refusals.append("smoke_reloading")
		return {"ok":false,"reason":"smoke_reloading"}
	smoke_stock -= 1
	smoke_ready_at = now+float(smoke.reload_s)
	var cloud := {"id":"smoke:%s:%d" % [vehicle_id,smoke_clouds.size()],
		"owner":vehicle_id,"owner_life":life_id,"position":position,
		"radius_m":float(smoke.cloud_radius_m),"spawned_at":now,
		"expires_at":now+float(smoke.cloud_duration_s),
		"media":"smoke","blocks_projectile":false}
	smoke_clouds.append(cloud)
	return {"ok":true,"cloud":cloud.duplicate(true),"stock":smoke_stock}

func active_clouds(now: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for cloud in smoke_clouds:
		if now <= float(cloud.expires_at): out.append(cloud.duplicate(true))
	return out

## The single shared occlusion object: AI, network and replay all ask this, and the
## answer feeds ObservationPolicy with media="smoke".
func occluding_media(position: Vector3, now: float) -> String:
	for cloud in active_clouds(now):
		var offset: Vector3 = cloud.position-position
		if Vector2(offset.x,offset.z).length() <= float(cloud.radius_m): return "smoke"
	return "none"

func recon_mark(entity_id: String, entity_life: int, position: Vector3, now: float, source: String = "authority") -> Dictionary:
	if not SPAWN_SOURCES.has(source):
		refusals.append("replay_cannot_mark:%s"%source)
		return {"ok":false,"reason":"replay_cannot_mark"}
	var recon: Variant = capability_for(vehicle_id).get("recon")
	if recon == null:
		refusals.append("no_recon_capability")
		return {"ok":false,"reason":"no_recon_capability"}
	recon_marks[entity_id] = {"entity_id":entity_id,"life_id":entity_life,"position":position,
		"source":source,"precision_m":float(recon.mark_precision_m),
		"created_at":now,"expires_at":now+float(recon.spot_duration_s)}
	return {"ok":true,"mark":recon_marks[entity_id].duplicate(true)}

func recon_marks_now(now: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entity_id in recon_marks.keys():
		var mark: Dictionary = recon_marks[entity_id]
		if now > float(mark.expires_at):
			refusals.append("recon_expired:%s"%entity_id)
			recon_marks.erase(entity_id)
			continue
		out.append(mark.duplicate(true))
	return out

func start_repair_assist(target_id: String, now: float) -> Dictionary:
	if not bool(capability_for(vehicle_id).get("repair_assist",false)):
		refusals.append("no_repair_capability")
		return {"ok":false,"reason":"no_repair_capability"}
	if target_id.is_empty():
		return {"ok":false,"reason":"no_target"}
	repair_target = target_id
	repair_cancelled_reason = ""
	return {"ok":true,"target":target_id,"started_at":now,"mode":"assist"}

func cancel_repair_assist(reason: String) -> Dictionary:
	if repair_target.is_empty(): return {"ok":false,"reason":"no_active_assist"}
	repair_cancelled_reason = reason
	repair_target = ""
	return {"ok":true,"reason":"repair_cancelled","cancel_reason":reason}

func connect_tow(target_id: String, target_state: Dictionary) -> Dictionary:
	if not bool(capability_for(vehicle_id).get("tow",false)):
		refusals.append("tow_not_capable")
		return {"ok":false,"reason":"tow_not_capable"}
	if not tow_target.is_empty():
		refusals.append("tow_already_connected")
		return {"ok":false,"reason":"tow_already_connected"}
	if bool(target_state.get("is_wreck",false)):
		refusals.append("tow_wreck_bounds")
		return {"ok":false,"reason":"tow_wreck_bounds"}
	if not bool(target_state.get("mobile_hull",true)):
		refusals.append("tow_immobile_target")
		return {"ok":false,"reason":"tow_immobile_target"}
	if bool(target_state.get("terrain_blocks_tow",false)):
		refusals.append("tow_terrain")
		return {"ok":false,"reason":"tow_terrain"}
	tow_target = target_id
	tow_cancel_reason = ""
	return {"ok":true,"target":target_id}

func disconnect_tow(reason: String) -> Dictionary:
	if tow_target.is_empty(): return {"ok":false,"reason":"no_active_tow"}
	tow_cancel_reason = reason
	tow_target = ""
	return {"ok":true,"reason":"tow_disconnected","cancel_reason":reason}

## A client may ask for an action; it may never author inventory or repair amounts.
func apply_client_request(request: Dictionary) -> Dictionary:
	for forbidden in ["smoke_stock","stock","aux_ammo","ammo","repair_amount","instant_repair","repair_seconds"]:
		if request.has(forbidden):
			refusals.append("client_cannot_author:%s"%forbidden)
			return {"ok":false,"reason":"client_cannot_author_inventory"}
	match str(request.get("action","")):
		"fire_aux": return fire_aux(str(request.get("weapon_id","")),float(request.get("now",0.0)))
		"smoke": return deploy_smoke(float(request.get("now",0.0)),request.get("position",Vector3.ZERO),"local_player")
		"recon": return recon_mark(str(request.get("entity_id","")),int(request.get("life_id",-1)),
			request.get("position",Vector3.ZERO),float(request.get("now",0.0)),"local_player")
		"repair_assist": return start_repair_assist(str(request.get("target_id","")),float(request.get("now",0.0)))
		"cancel_repair": return cancel_repair_assist(str(request.get("reason","player_cancelled")))
	return {"ok":false,"reason":"unknown_action"}

## Read-only view for replay, spectator and network sync.
func snapshot(now: float) -> Dictionary:
	return {"vehicle_id":vehicle_id,"life_id":life_id,
		"aux_pools":aux_pools.duplicate(true),"smoke_stock":smoke_stock,
		"smoke_ready_at":smoke_ready_at,"active_clouds":active_clouds(now),
		"recon_marks":recon_marks_now(now),"repair_target":repair_target,
		"tow_target":tow_target,"refusals":refusals.duplicate()}
