class_name ModernSample
extends RefCounted
## WT-029: the modern engagement sample as a deterministic harness.
##
## SCOPE, honestly stated: the two pilots have no combat definition, so this sample
## exercises MECHANISMS and EQUIPMENT (loading, power, sensors, smoke, terrain, routes) and
## does not pretend to be a gunnery duel. Every scenario returns its own record so the
## report can be checked step by step.

const SCENARIOS := ["long_range","flank","hilltop","smoke_retreat","damaged_loading_recovery"]
const NOT_A_GUNNERY_DUEL := true
const MODERN_IN_NORMAL_MATCH := false

static func long_range(vehicle_id: String, distance_m: float, media: String = "none") -> Dictionary:
	var steps: Array[Dictionary] = []
	var thermal := ModernEquipment.availability(vehicle_id,"thermal_sight",true)
	steps.append({"step":"thermal_available","ok":thermal.ok,"detail":str(thermal.get("reason","available"))})
	var visibility := ModernEquipment.sensor_visibility(media,"thermal")
	steps.append({"step":"thermal_visibility","media":media,"attenuation":visibility.attenuation,
		"blocked":visibility.blocked})
	var optical := ModernEquipment.sensor_visibility(media,"optical")
	steps.append({"step":"optical_visibility","media":media,"attenuation":optical.attenuation,
		"blocked":optical.blocked})
	var rangefinder := ModernEquipment.availability(vehicle_id,"rangefinding",true)
	steps.append({"step":"rangefinding_available","ok":rangefinder.ok})
	var ok: bool = bool(thermal.ok) and bool(rangefinder.ok) and not bool(visibility.blocked) and distance_m > 0.0
	return {"scenario":"long_range","vehicle_id":vehicle_id,"distance_m":distance_m,"media":media,
		"steps":steps,"ok":ok,"note":"range is a design distance; no ballistic claim is made"}

static func flank(team_size: int = 16) -> Dictionary:
	var purposes := RiverJunctionDefinition.route_purposes(team_size)
	var flank_routes: Array[Dictionary] = []
	var attack_routes: Array[Dictionary] = []
	for row in purposes:
		var purpose := str(row.purpose)
		if purpose == "flank_or_observation": flank_routes.append(row)
		# attack lanes are the central hook and the secondary pushes (the outermost lane is
		# the bypass, so it is deliberately not counted as an attack lane)
		elif purpose in ["central_hook","secondary_push","main_push"]: attack_routes.append(row)
	return {"scenario":"flank","team_size":team_size,"flank_routes":flank_routes.size(),
		"attack_routes":attack_routes.size(),"ok":flank_routes.size() >= 1 and attack_routes.size() >= 1,
		"note":"both an attack lane and a bypass lane exist, so each side has attack and defence options"}

static func hilltop() -> Dictionary:
	var lane_x := RiverJunctionDefinition.lane_x(0.0,0.0)
	var lane_height := RiverJunctionDefinition.height(lane_x,0.0)
	var ridge_height := RiverJunctionDefinition.height(-520.0,120.0)
	return {"scenario":"hilltop","lane_height":lane_height,"ridge_height":ridge_height,
		"gain_m":ridge_height-lane_height,"ok":ridge_height > lane_height,
		"note":"an observation position above the lane exists; being higher only helps if the sensor channel can see"}

static func smoke_retreat(vehicle_id: String) -> Dictionary:
	var support := SupportActions.new()
	support.begin(vehicle_id,1)
	var steps: Array[Dictionary] = []
	var own_launcher := true
	var cloud := support.deploy_smoke(0.0,Vector3(0,9,0),"authority")
	if not cloud.ok:
		# the modern pilots have no smoke launcher configured yet; the cloud is then laid by
		# a supporting vehicle, which is exactly the shared occlusion object the sensors read
		own_launcher = false
		support.begin("us_m4a3_75w_vvss_1944",1)
		cloud = support.deploy_smoke(0.0,Vector3(0,9,0),"authority")
		steps.append({"step":"own_launcher_missing","reason":"no_smoke_capability",
			"finding":"modern pilots have no smoke launcher configured"})
	steps.append({"step":"smoke_deployed","ok":cloud.ok,"launcher":"own" if own_launcher else "supporting_vehicle"})
	var media := support.occluding_media(Vector3(0,9,0),1.0)
	steps.append({"step":"shared_occlusion_object","media":media})
	var optical := ModernEquipment.sensor_visibility(media,"optical")
	var thermal := ModernEquipment.sensor_visibility(media,"thermal")
	steps.append({"step":"optical_after_smoke","blocked":optical.blocked})
	steps.append({"step":"thermal_after_smoke","attenuation":thermal.attenuation,"blocked":thermal.blocked})
	var loading := LoadingMechanism.new()
	loading.begin(vehicle_id)
	var before := loading.accounted_rounds()
	loading.start_load()
	loading.advance(10.0)
	loading.interrupt("withdraw_under_smoke")
	steps.append({"step":"loading_unaffected_by_smoke","state":loading.state,
		"conserved":loading.accounted_rounds() == before})
	return {"scenario":"smoke_retreat","vehicle_id":vehicle_id,"own_launcher":own_launcher,"steps":steps,
		"ok":cloud.ok and bool(optical.blocked) and loading.accounted_rounds() == before,
		"note":"smoke hides the optical channel, keeps its own thermal rule, and never blocks a shell"}

static func damaged_loading_recovery(vehicle_id: String) -> Dictionary:
	var loading := LoadingMechanism.new()
	var begin := loading.begin(vehicle_id)
	if not begin.ok: return {"scenario":"damaged_loading_recovery","vehicle_id":vehicle_id,"ok":false,"steps":[]}
	var steps: Array[Dictionary] = []
	var initial := loading.accounted_rounds()
	loading.start_load()
	loading.advance(10.0)
	steps.append({"step":"load_started","state":loading.state})
	var channel := "mechanism" if loading.mechanism == "autoloader_carousel" else "loader"
	loading.set_channel(channel,true)
	steps.append({"step":"channel_damaged","channel":channel,"state":loading.state,"interrupt":loading.last_interrupt})
	steps.append({"step":"conserved_after_damage","accounted":loading.accounted_rounds(),"initial":initial})
	loading.set_channel(channel,false)
	var resumed := loading.resume()
	steps.append({"step":"resumed","ok":resumed.ok})
	loading.start_load()
	var chambered := false
	for i in 4:
		loading.advance(10.0)
		if loading.state == "ready": chambered = true
	steps.append({"step":"reloaded","chambered":chambered,"accounted":loading.accounted_rounds()})
	var fired := loading.fire_chambered()
	steps.append({"step":"fired","ok":fired.ok,"fired":loading.fired_count})
	return {"scenario":"damaged_loading_recovery","vehicle_id":vehicle_id,"steps":steps,
		"ok":resumed.ok and chambered and loading.accounted_rounds() == initial,
		"note":"damage interrupts, repair resumes, and the account is conserved throughout"}

static func run_all(vehicle_id: String = "ussr_t_80b") -> Dictionary:
	var records: Array[Dictionary] = []
	records.append(long_range(vehicle_id,1200.0,"none"))
	records.append(long_range(vehicle_id,2000.0,"smoke"))
	records.append(flank(16))
	records.append(hilltop())
	records.append(smoke_retreat(vehicle_id))
	records.append(damaged_loading_recovery(vehicle_id))
	var passed := 0
	for record in records:
		if bool(record.ok): passed += 1
	return {"schema":1,"work_order":"WT-029-R1","vehicle_id":vehicle_id,
		"scenarios":SCENARIOS.duplicate(),"records":records,"passed":passed,"total":records.size(),
		"not_a_gunnery_duel":NOT_A_GUNNERY_DUEL,"modern_in_normal_match":MODERN_IN_NORMAL_MATCH,
		"experience_gate":TechSegment.experience_gate(),
		"note":"mechanism and equipment sample: no ballistics, armor or admission claim is made here"}
