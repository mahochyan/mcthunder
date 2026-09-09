class_name CombatFeedback
extends Node3D
## One presenter owned by one live ProjectileManager. No replay subscriptions.
## Observes committed state; never mutates ammunition, damage, aim or match state.
var manager: ProjectileManager
var audio: CombatAudioPool
var fx: CombatFXPool
var subtitles: CombatSubtitles
var actors: Dictionary = {}
var seen: Dictionary = {}
var presented: Dictionary = {}
var _flight_seen: Dictionary = {}

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_PAUSABLE
	audio=CombatAudioPool.new(); add_child(audio)
	fx=CombatFXPool.new(); add_child(fx)
	subtitles=CombatSubtitles.new(); add_child(subtitles)
	manager=get_parent() as ProjectileManager
	manager.projectile_contact.connect(on_contact)
	manager.projectile_finished.connect(on_finished)

func bind_actor(actor: VehicleActor) -> void:
	if actor==null or actor.state==null or actors.has(actor.get_instance_id()): return
	actors[actor.get_instance_id()]={"ref":weakref(actor),"generation":actor.state.generation,
		"dead":actor.state.destroyed,"death_age":0.0,"chamber":actor.gunner.inventory.chamber,
		"hull_yaw":actor.tank.global_rotation.y,"yaw":actor.turret.rotation.y,"pitch":actor.turret.barrel_pivot.rotation.x}
	actor.vehicle_destroyed.connect(on_destroyed.bind(weakref(actor)))

func on_destroyed(record: Dictionary, reference: WeakRef) -> void:
	var actor:=reference.get_ref() as VehicleActor
	if actor==null or int(record.get("generation",-1))!=actor.state.generation: return
	var kind:="explosion" if record.get("cause","")=="ammo_detonation" else "destroyed"
	on_combat_event("death:"+_identity(actor),kind,record.get("point_world",actor.tank.global_position),4)

func _identity(actor: VehicleActor) -> String:
	return str(actor.life_id)+":"+str(actor.state.generation)

func on_combat_event(key: String, kind: String, point: Vector3, priority: int=2) -> void:
	if seen.has(key): return
	seen[key]=true
	if seen.size()>512: seen.erase(seen.keys()[0])
	presented[kind]=int(presented.get(kind,0))+1
	audio.play_voice(key,kind,point,priority)
	subtitles.present(kind,point)
	if kind in ["non_penetration","ricochet","penetrated","world"]: fx.spawn_bounded(kind,point)

func on_shot(spec: Dictionary) -> void:
	var key:="shot:"+JSON.stringify([spec.round_id,spec.shooter_id,spec.shooter_life_id,spec.shot_id])
	on_combat_event(key,"shot",spec.position_world,3)

func on_contact(record: Dictionary) -> void:
	var kind:=str(record.get("result","non_penetration"))
	if kind not in ["ricochet","penetrated"]: kind="non_penetration"
	var key:="contact:"+str(record.get("projectile_id",0))+":"+str(record.get("contact_index",0))
	on_combat_event(key,kind,record.get("impact_point",Vector3.ZERO),2)

func on_finished(record: Dictionary) -> void:
	var pid:=int(record.get("projectile_id",0)); _flight_seen.erase(pid)
	if record.get("reason","")=="impact_world":
		on_combat_event("world:"+str(pid),"world",record.get("impact_point",record.get("position_world",Vector3.ZERO)),1)

func stop_all() -> void:
	if audio!=null: audio.stop_all()
	if fx!=null: fx.clear()

func _process(delta: float) -> void:
	if manager==null: stop_all(); return
	if manager._shut_down: audio.stop_loops(); return
	for id in actors.keys():
		var row: Dictionary=actors[id]
		var actor:=row.ref.get_ref() as VehicleActor
		if actor==null or actor.is_queued_for_deletion(): actors.erase(id); continue
		if row.generation!=actor.state.generation:
			row.generation=actor.state.generation; row.dead=actor.state.destroyed; row.death_age=0.0
			row.chamber=actor.gunner.inventory.chamber
			row.yaw=actor.turret.rotation.y; row.pitch=actor.turret.barrel_pivot.rotation.x
			row.hull_yaw=actor.tank.global_rotation.y
		var identity:=_identity(actor)
		var point:=actor.tank.global_position+Vector3.UP
		if actor.state.destroyed and not row.dead:
			row.dead=true
			var kind:="explosion" if actor.state.death_record.get("cause","")=="ammo_detonation" else "destroyed"
			on_combat_event("death:"+identity,kind,point,4)
		var chamber:=actor.gunner.inventory.chamber
		if chamber>0 and int(row.chamber)==0 and not actor.state.destroyed:
			on_combat_event("reload:"+identity+":"+str(actor.gunner.shot_id),"reload",point,3)
		row.chamber=chamber
		if actor.state.destroyed:
			row.death_age+=delta
			if row.death_age<45 and actor.state.death_record.get("cause","") in ["ammo_detonation","fire_crew_out"]:
				audio.play_voice("fire:"+identity,"fire",point,1,0.6,1,true)
			continue
		if not actor.is_physics_processing(): continue
		var speed:=actor.tank.velocity.length()
		var hull_yaw:=actor.tank.global_rotation.y
		var turning:=absf(wrapf(hull_yaw-float(row.hull_yaw),-PI,PI))/maxf(delta,0.0001)
		row.hull_yaw=hull_yaw
		var track_speed:=speed+turning*1.5
		var capabilities:=actor.capabilities()
		if capabilities.get("drive",false):
			audio.play_voice("engine:"+identity,"engine",point,0,0.55,0.72+minf(speed/15,0.8),true)
		if track_speed>0.08:
			audio.play_voice("tracks:"+identity,"tracks",point,0,minf(0.7,track_speed/5),0.7+minf(track_speed/18,0.7),true)
		var yaw:=actor.turret.rotation.y; var pitch:=actor.turret.barrel_pivot.rotation.x
		var turn:=absf(wrapf(yaw-float(row.yaw),-PI,PI))+absf(pitch-float(row.pitch))
		row.yaw=yaw; row.pitch=pitch
		if turn/maxf(delta,0.0001)>0.01:
			audio.play_voice("turret:"+identity,"turret",point,0,0.3,1,true)
		if not actor.state.fires.is_empty(): audio.play_voice("fire:"+identity,"fire",point,1,0.7,1,true)
	var camera:=get_viewport().get_camera_3d()
	if camera!=null:
		for state in manager.active_states():
			if not _flight_seen.has(state.projectile_id) and state.age_s>0.04 and state.position_world.distance_to(camera.global_position)<12:
				_flight_seen[state.projectile_id]=true
				on_combat_event("flyby:"+str(state.projectile_id),"flyby",state.position_world,1)
