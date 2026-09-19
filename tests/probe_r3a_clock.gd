extends SceneTree
## R3-A CLOCK DIAGNOSTIC (authorised focused investigation, 2026-09-19).
##
## The R3-A leg in tests/run_checks.gd ("近靶 B1 稳定收敛") has been measured BOTH ways on the same build: it fails
## with first_cross=-1 and a final error near 11 degrees, and it passes with first_cross 142/143 and a final error of
## 0.01 degrees. The difference was attributed to machine load. This probe does not assume that: it reproduces the leg
## exactly, reads the always-on instrument counters, and reports which CLOCK each piece of the convergence ran on.
##
## What is being tested, stated before the measurement:
##   H1 the aim phase advances more than once per physics frame (render-clocked aim).
##   H2 the convergence TRUTH - the single get_aim_point() read that fixes P for the whole loop - is answered from the
##      CAMERA TRANSFORM (render clock) instead of the physics-derived precise intent, so P is a STALE aim point and the
##      turret can never bring the measured error under the 0.5 degree criterion.
## Both are reported as counts, never as an opinion, and the leg is then run with a controlled render load so the same
## build is measured in both regimes in one process.
##
## Usage: godot --headless --path <tree> -s res://tests/probe_r3a_clock.gd [-- --load-ms N]

const B1 := Vector3(0,0.0,-12)
const AIM_YAW := 0.0
const AIM_PITCH_DEG := -5.5

var checks := 0
var fail := 0

func _initialize() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: fail += 1
	print("[PASS] " if ok else "[FAIL] ",label)

## A real render-load source: the delay happens INSIDE a _process callback, so it stretches render frames exactly the
## way a busy machine does, without touching physics.
class Loader:
	extends Node
	var ms := 0
	func _process(_delta: float) -> void:
		if ms > 0: OS.delay_msec(ms)

func _camera_ray_hit(main: Node) -> Dictionary:
	# Same mask and self-exclusion as tests/run_checks.gd _camera_ray_hit, so the leg's input is reproduced exactly.
	var cam: Camera3D = main.cam_rig.cam
	var from: Vector3 = cam.global_position
	var dir: Vector3 = -cam.global_transform.basis.z
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from,from+dir*150.0,GameConfig.LAYER_WORLD | GameConfig.LAYER_VEHICLE,[main.tank.get_rid()])
	return space.intersect_ray(q)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var load_ms := 0
	var idx := args.find("--load-ms")
	if idx >= 0 and idx+1 < args.size(): load_ms = int(args[idx+1])
	# --pause-at N: the ONE real R3-A failure on record (logs/COMBAT-DEEPEN-01/c16r-run_checks.log) is not a slow
	# convergence - the error PLATEAUS at 10.987 degrees from frame 180 and never moves again, which is what a frozen
	# mechanism looks like. This option freezes the world mid-loop so the signature can be compared, not guessed.
	var pause_at := -1
	var pidx := args.find("--pause-at")
	if pidx >= 0 and pidx+1 < args.size(): pause_at = int(args[pidx+1])
	# --focus-out-at N: the PRODUCT path that pauses a battle, not a hand-set tree flag. scripts/main.gd:477 pauses on
	# NOTIFICATION_APPLICATION_FOCUS_OUT, the suite exercises it (T002-04), and a run that receives it mid-leg would
	# freeze the mechanism exactly like the one real R3-A failure on record.
	var focus_at := -1
	var fidx := args.find("--focus-out-at")
	if fidx >= 0 and fidx+1 < args.size(): focus_at = int(args[fidx+1])
	var ps: PackedScene = load("res://scenes/main.tscn")
	var main: Node = ps.instantiate()
	root.add_child(main)
	for i in 60: await physics_frame
	var actor: VehicleActor = main.actor_a
	check(actor != null,"R3-A diagnostic: the real main scene exposes its player VehicleActor")
	if actor == null: quit(1); return
	var loader := Loader.new(); loader.ms = load_ms; root.add_child(loader)
	# EXACTLY the leg's setup: near board at 12 m, aim set by direct field write, two process frames, then the truth
	# read once inside _stable_converge.
	var b1 := TargetBoard.new(); b1.position = B1; main.world.add_child(b1)
	main.cam_rig.aim_yaw = AIM_YAW
	main.cam_rig.aim_pitch = deg_to_rad(AIM_PITCH_DEG)
	await process_frame
	await process_frame
	var sel := _camera_ray_hit(main)
	var physics_before := Engine.get_physics_frames()
	var process_before := Engine.get_process_frames()
	var aim_steps_before: int = actor.aim_phase_steps
	var pose_phys_before: int = main.cam_rig.pose_updates_from_physics
	var pose_render_before: int = main.cam_rig.pose_updates_from_render
	var reads_precise_before: int = main.cam_rig.aim_point_reads_precise
	var reads_pose_before: int = main.cam_rig.aim_point_reads_pose
	var P: Vector3 = main.cam_rig.get_aim_point()
	var read_used_precise := int(main.cam_rig.aim_point_reads_precise) > reads_precise_before
	print("[r3a] load_ms=%d ray_hit=%s P=%s truth_clock=%s" % [load_ms,str(sel.get("collider",null)!=null),str(P),"precise(physics)" if read_used_precise else "camera-pose(render)"])
	# The convergence loop, copied from tests/run_checks.gd _stable_converge so the numbers are comparable.
	main.turret.rotation.y = 1.0
	main.turret.barrel_pivot.rotation.x = 0.0
	var first_cross := -1
	var hold_time := 0.0
	var max_err := 0.0
	var final_err := 0.0
	var samples := 0
	var P_first := Vector3.ZERO
	for i in 900:
		await physics_frame
		samples += 1
		if pause_at >= 0 and i == pause_at:
			paused = true
			print("[r3a] PAUSED at frame %d (the world is frozen from here)" % i)
		if focus_at >= 0 and i == focus_at:
			main._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
			print("[r3a] FOCUS_OUT delivered at frame %d -> tree paused=%s (main._paused=%s)" % [i,str(paused),str(main.get("_paused"))])
		var bdir: Vector3 = main.turret.barrel_direction()
		var want: Vector3 = (P - main.turret.barrel_pivot.global_position).normalized()
		var err: float = rad_to_deg(bdir.angle_to(want))
		if i == 0: P_first = main.cam_rig.get_aim_point()
		max_err = maxf(max_err,err)
		final_err = err
		if i % 60 == 0:
			print("[stab] frame=%d err=%.3fdeg first_cross=%d paused=%s" % [i,err,first_cross,str(paused)])
		if first_cross < 0:
			if err <= 0.5:
				first_cross = i
				hold_time = 0.0
			continue
		hold_time += 1.0/Engine.physics_ticks_per_second
		if err > 0.5: break
	var physics_after := Engine.get_physics_frames()
	var process_after := Engine.get_process_frames()
	var physics_frames := physics_after-physics_before
	var process_frames := process_after-process_before
	var aim_steps: int = actor.aim_phase_steps-aim_steps_before
	var stale_deg := rad_to_deg((P-main.turret.barrel_pivot.global_position).normalized().angle_to((P_first-main.turret.barrel_pivot.global_position).normalized()))
	print("[r3a] RESULT load_ms=%d first_cross=%d hold=%.2f max_err=%.2f final_err=%.2f samples=%d" % [load_ms,first_cross,hold_time,max_err,final_err,samples])
	print("[r3a] CLOCKS load_ms=%d physics_frames=%d process_frames=%d ratio=%.2f aim_phase_steps=%d steps_per_physics_frame=%.3f max_steps_in_one_physics_frame=%d" % [load_ms,physics_frames,process_frames,float(process_frames)/maxf(1.0,float(physics_frames)),aim_steps,float(aim_steps)/maxf(1.0,float(physics_frames)),actor.aim_steps_max_per_physics_frame])
	print("[r3a] POSE load_ms=%d from_physics=%d from_render=%d aim_reads_precise=%d aim_reads_pose=%d truth_moved_by=%.3fdeg" % [load_ms,main.cam_rig.pose_updates_from_physics-pose_phys_before,main.cam_rig.pose_updates_from_render-pose_render_before,main.cam_rig.aim_point_reads_precise-reads_precise_before,main.cam_rig.aim_point_reads_pose-reads_pose_before,stale_deg])
	check(actor.aim_steps_max_per_physics_frame<=1,
		"R3-A H1: the aim phase advances at most once per physics frame (measured max=%d)" % actor.aim_steps_max_per_physics_frame)
	check(read_used_precise,
		"R3-A H2: the convergence truth is answered from the physics-derived precise intent, not the camera pose")
	check(first_cross>=0 and final_err<=0.5,
		"R3-A convergence with load_ms=%d (first_cross=%d final_err=%.2f)" % [load_ms,first_cross,final_err])
	quit(0 if fail==0 else 1)
