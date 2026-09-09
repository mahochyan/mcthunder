class_name CombatAudioPool
extends Node3D
## Reserved 24 loops + 8 one-shots. Mono peak <= .8; gains .01/.08:
## coherent worst-case sum <= .704 before user volume and distance attenuation.
const CAPACITY := 32
const LOOP_CAPACITY := 24
const LOOP_GAIN := 0.01
const EVENT_GAIN := 0.08
const BUS := "Combat"
var voices: Array[Dictionary] = []
var streams: Dictionary = {}
var peak_voices := 0
var accepted := 0
var rejected := 0
var peak_db := -100.0

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index(BUS)<0:
		AudioServer.add_bus(); AudioServer.set_bus_name(AudioServer.bus_count-1,BUS)
		AudioServer.set_bus_send(AudioServer.get_bus_index(BUS),"Master")
		var limiter:=AudioEffectHardLimiter.new()
		limiter.pre_gain_db=18.0; limiter.ceiling_db=-1.0; limiter.release=0.1
		AudioServer.add_bus_effect(AudioServer.get_bus_index(BUS),limiter)
	for i in CAPACITY:
		var player:=AudioStreamPlayer3D.new(); player.bus=BUS
		player.unit_size=12.0; player.max_distance=240.0
		player.attenuation_model=AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(player)
		voices.append({"player":player,"key":"","priority":-1,"ttl":0.0,"loop":false,"loop_slot":i<LOOP_CAPACITY})

func stream(kind: String) -> AudioStreamWAV:
	if not streams.has(kind):
		var loaded:=load("res://assets/audio/"+kind+".wav") as AudioStreamWAV
		if loaded==null: return null
		var copy:=loaded.duplicate() as AudioStreamWAV
		if kind in ["engine","tracks","turret","fire"]:
			copy.loop_mode=AudioStreamWAV.LOOP_FORWARD
			copy.loop_begin=0; copy.loop_end=roundi(copy.get_length()*copy.mix_rate)
		streams[kind]=copy
	return streams[kind]

func play_voice(key: String, kind: String, point: Vector3, priority: int, gain: float=1.0, pitch: float=1.0, looping: bool=false) -> bool:
	if get_tree().paused or AccessibilitySettings.audio_volume<=0.0: return false
	var group_gain := AccessibilitySettings.mechanical_volume if kind in ["engine","tracks","turret"] else AccessibilitySettings.effects_volume
	if group_gain <= 0.0: return false
	var camera:=get_viewport().get_camera_3d()
	if camera!=null and camera.global_position.distance_to(point)>240.0: return false
	var slot: Dictionary={}
	for voice in voices:
		if voice.loop_slot==looping and voice.key==key: slot=voice; break
	if slot.is_empty():
		for voice in voices:
			if voice.loop_slot==looping and voice.key.is_empty(): slot=voice; break
	if slot.is_empty():
		var weakest:=priority
		for voice in voices:
			if voice.loop_slot==looping and int(voice.priority)<weakest: slot=voice; weakest=int(voice.priority)
	if slot.is_empty(): rejected+=1; return false
	var player:=slot.player as AudioStreamPlayer3D
	var restart: bool=slot.key!=key
	if restart:
		player.stop(); player.stream=stream(kind)
		if player.stream==null: return false
		slot.key=key; slot.priority=priority; slot.loop=looping; accepted+=1
	player.global_position=point
	player.pitch_scale=clampf(pitch,0.6,1.8)
	var maximum:=LOOP_GAIN if looping else EVENT_GAIN
	player.max_db=linear_to_db(maximum)
	player.volume_db=linear_to_db(maximum*clampf(gain,0.0,1.0)*clampf(group_gain,0.0,1.0))
	slot.ttl=0.12 if looping else player.stream.get_length()/player.pitch_scale+0.1
	if restart: player.play()
	peak_voices=maxi(peak_voices,active_count())
	return true

func active_count() -> int:
	var count:=0
	for voice in voices:
		if not voice.key.is_empty(): count+=1
	return count

func stop_all() -> void:
	for voice in voices:
		voice.player.stop(); voice.player.stream=null; voice.key=""; voice.ttl=0.0; voice.priority=-1

func stop_loops() -> void:
	for voice in voices:
		if voice.loop:
			voice.player.stop(); voice.player.stream=null; voice.key=""; voice.ttl=0.0; voice.priority=-1

func _exit_tree() -> void:
	stop_all()
	streams.clear()

func _process(delta: float) -> void:
	var index:=AudioServer.get_bus_index(BUS)
	AudioServer.set_bus_volume_db(index,linear_to_db(maxf(0.00001,clampf(AccessibilitySettings.audio_volume,0,1))))
	peak_db=maxf(peak_db,maxf(AudioServer.get_bus_peak_volume_left_db(index,0),AudioServer.get_bus_peak_volume_right_db(index,0)))
	if get_tree().paused or AccessibilitySettings.audio_volume<=0.0: stop_all(); return
	for voice in voices:
		voice.ttl-=delta
		if not voice.key.is_empty() and voice.ttl<=0:
			voice.player.stop(); voice.key=""; voice.priority=-1

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT: stop_all()
