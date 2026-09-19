extends SceneTree
## WT-EXPANSION-01 secondary armament, SCENARIO FIRST. Written before any implementation, on the rule this package
## follows everywhere else: the acceptance check exists first, it fails for the right reason, and only then is the
## implementation written against it.
##
## THE CONTRACT IT ASSERTS comes from the local War Thunder install (build 2.59.0.13) and is recorded in
## docs/wt/wt-reference/WT_REFERENCE_SECONDARY.json:
##   T-80B      coaxial 7.62 mm PKT   belt 750  reload 8 s  cadence 11.66 /s  round ap_i_ball   817.5 m/s
##              AA     12.7 mm NSV     belt 250  reload 5 s  cadence 11.666 /s round ap_i_t_ball 865   m/s
##   Leopard    coaxial 7.92 mm MG3   belt 200  reload 8 s  cadence 20 /s     round ap_ball     853   m/s
##              hull   7.92 mm MG3    belt 200  reload 8 s  cadence 20 /s     round ap_ball     853   m/s
##
## THIS IS AN AUTHORISED EXPANSION BEYOND THE PACKAGE 96 CASES, not one of them: the user asked on 2026-09-19 for
## the game completeness to be raised directly from the unpacked War Thunder data. The probe says so in its own
## name and in the record, so no reader can mistake it for package content.
##
## WHAT IS EXPECTED TODAY: FAILURE. The secondary weapons are not modelled, so the declaration checks fail and
## every cadence check after them is reported as unmet rather than silently skipped.

const SECONDARY := {
	"ussr_t_80b": [
		{"group":"coaxial","caliber_mm":7.62,"belt":750,"reload_s":8.0,"cadence_rps":11.66,"round":"ap_i_ball","speed_mps":817.5},
		{"group":"machinegun","caliber_mm":12.7,"belt":250,"reload_s":5.0,"cadence_rps":11.666,"round":"ap_i_t_ball","speed_mps":865.0}
	],
	"germ_leopard_2a4": [
		{"group":"coaxial","caliber_mm":7.92,"belt":200,"reload_s":8.0,"cadence_rps":20.0,"round":"ap_ball","speed_mps":853.0},
		{"group":"machinegun","caliber_mm":7.92,"belt":200,"reload_s":8.0,"cadence_rps":20.0,"round":"ap_ball","speed_mps":853.0}
	]
}

var checks := 0
var fail := 0
var unmet := 0

func _initialize() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: fail += 1
	print("[PASS] " if ok else "[FAIL] ",label)
func _frames(n: int) -> void:
	for i in n: await process_frame

func _run() -> void:
	var defs := VehicleDefs.new()
	check(defs.load_defaults().ok,"WT-EXPANSION-01 the vehicle definitions load")
	var catalog := VehicleCatalog.new()
	check(catalog.load_all(defs).ok,"WT-EXPANSION-01 the historical packages load")
	check(catalog.load_engineering(defs).ok,"WT-EXPANSION-01 both engineering packets are admitted")
	var world := Node3D.new(); root.add_child(world)
	var index := 0
	for id in SECONDARY.keys():
		index += 1
		var path := "res://configs/vehicles/engineering/" + str(id) + ".json"
		var handle := FileAccess.open(path,FileAccess.READ)
		check(handle != null,"WT-EXPANSION-01 %s packet is readable" % str(id))
		if handle == null: continue
		var packet: Dictionary = JSON.parse_string(handle.get_as_text())
		# 1. THE DECLARATION, read from the packet rather than assumed: a list of secondary weapons with the
		#    groups the file names, so a coaxial and an anti-air gun are distinguishable.
		var declared: Array = packet.get("secondary_weapons",[])
		check(declared.size()==(SECONDARY[id] as Array).size(),
			"WT-EXPANSION-01 %s declares its %d secondary weapons" % [str(id),(SECONDARY[id] as Array).size()])
		var by_group := {}
		for row in declared:
			if row is Dictionary: by_group[str(row.get("group",""))] = row
		for want in SECONDARY[id]:
			var got: Dictionary = by_group.get(str(want.group),{})
			check(not got.is_empty(),"WT-EXPANSION-01 %s declares a %s weapon" % [str(id),str(want.group)])
			if got.is_empty():
				unmet += 1
				continue
			check(absf(float(got.get("caliber_mm",0.0))-float(want.caliber_mm))<0.01,
				"WT-EXPANSION-01 %s %s caliber is the file value %.2f mm" % [str(id),str(want.group),float(want.caliber_mm)])
			check(int(got.get("belt",0))==int(want.belt),
				"WT-EXPANSION-01 %s %s belt is the file value %d" % [str(id),str(want.group),int(want.belt)])
			check(absf(float(got.get("reload_s",0.0))-float(want.reload_s))<0.01,
				"WT-EXPANSION-01 %s %s reload is the file value %.1f s" % [str(id),str(want.group),float(want.reload_s)])
			check(absf(float(got.get("cadence_rps",0.0))-float(want.cadence_rps))<0.01,
				"WT-EXPANSION-01 %s %s cadence is the file value %.3f /s" % [str(id),str(want.group),float(want.cadence_rps)])
			check(absf(float(got.get("speed_mps",0.0))-float(want.speed_mps))<0.5,
				"WT-EXPANSION-01 %s %s round speed is the file value %.1f m/s" % [str(id),str(want.group),float(want.speed_mps)])
			check(str(got.get("round",""))==str(want.round),
				"WT-EXPANSION-01 %s %s carries the file round %s" % [str(id),str(want.group),str(want.round)])
		# 2. THE RUNTIME: a real actor must expose the second firing channel with its own belt and cadence, and the
		#    main gun must be untouched, which is the whole point of a separate channel rather than a bigger magazine.
		var actor := VehicleActor.new(); world.add_child(actor)
		var installed := actor.setup(defs,str(id),"wtexp01_"+str(index),index,Transform3D.IDENTITY,2,null)
		check(installed.ok,"WT-EXPANSION-01 %s installs a real actor" % str(id))
		await _frames(30)
		actor.set_physics_process(false); actor.tank.set_physics_process(false)
		var channels := 0
		if actor.gunner != null and actor.gunner.get("secondary") != null: channels = (actor.gunner.secondary as Array).size()
		check(channels==(SECONDARY[id] as Array).size(),
			"WT-EXPANSION-01 %s runtime exposes %d secondary firing channels" % [str(id),channels])
		if channels==0: unmet += 1
		# 3. THE FIRE REQUEST IS ANSWERED, never faked: with the channels installed the request must be answered
		#    with either a real shot or a refusal BY NAME. Until the round own impact profile is declared the honest
		#    answer is secondary_round_profile_missing, and a belt that was not debited proves no silent shot.
		if channels > 0:
			var belt_before: int = int(actor.gunner.secondary_channel(0).get("belt_remaining",0))
			var answer: Dictionary = actor.gunner.try_fire_secondary(0)
			var belt_after: int = int(actor.gunner.secondary_channel(0).get("belt_remaining",0))
			print("[WT-EXPANSION-01] %s fire answer: %s (belt %d -> %d)" % [str(id),str(answer),belt_before,belt_after])
			check(answer.get("reason","")!="" ,"WT-EXPANSION-01 %s the secondary fire request is ANSWERED" % str(id))
			if not bool(answer.get("ok",false)):
				check(belt_after==belt_before,"WT-EXPANSION-01 %s a refused secondary shot debits NOTHING" % str(id))
			else:
				check(belt_after==belt_before-1,"WT-EXPANSION-01 %s a fired secondary shot debits exactly one round" % str(id))
		actor.queue_free()
	world.queue_free(); await _frames(2)
	print("=== result: %d checks, %d failed, %d unmet-declaration legs ==="%[checks,fail,unmet])
	print("WT_EXPANSION_01_%s"%("PASS" if fail==0 else "FAIL"))
	quit(0 if fail==0 else 1)
