extends SceneTree
# Real second-process lock holder for the 029 save-lock counterexample (GPT ruling):
# a LIVE foreign process holds the lock past the suspect-stale window; the game side
# must refuse without touching the lock, and the holder must finish and release cleanly.
# usage: godot --headless --path <root> -s res://tests/lock_holder_029.gd -- <profile_path> <secs>
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var lock := ProjectSettings.globalize_path(args[0]+".lock")
	var secs := int(args[1]) if args.size() > 1 else 12
	if DirAccess.make_dir_absolute(lock) != OK: print("HELD_FAIL"); quit(2); return
	var stamp := FileAccess.open(lock.path_join("owner.txt"), FileAccess.WRITE)
	stamp.store_string("%d %d" % [OS.get_process_id(), int(Time.get_unix_time_from_system())])
	stamp.close()
	print("HELD %d" % OS.get_process_id())
	var until := Time.get_ticks_msec()+secs*1000
	while Time.get_ticks_msec() < until: await process_frame
	DirAccess.remove_absolute(lock.path_join("owner.txt"))
	DirAccess.remove_absolute(lock)
	print("RELEASED")
	quit(0)
