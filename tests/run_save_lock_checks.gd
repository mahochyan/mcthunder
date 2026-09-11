extends SceneTree
var count := 0
var failed := 0
func check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func _initialize() -> void:
	var path := ProjectSettings.globalize_path("user://tests/rc3-lock-"+str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(path)
	var lock := path.path_join("fixture.lock")
	var a := ProfileStore.new()
	var b := ProfileStore.new()
	check(a._acquire_lock(lock).ok,"first isolated store acquires lock")
	var original := FileAccess.get_file_as_string(lock.path_join("owner.txt"))
	check(not b._acquire_lock(lock).ok,"second same-PID store cannot steal lock")
	check(not a._acquire_lock(lock).ok,"reentrant acquisition is rejected")
	b._release_lock(lock)
	check(FileAccess.get_file_as_string(lock.path_join("owner.txt"))==original,"non-owner release preserves owner")
	a._release_lock(lock)
	check(not DirAccess.dir_exists_absolute(lock),"owner releases its own lock")
	check(a._acquire_lock(lock).ok,"new acquisition succeeds")
	check(FileAccess.get_file_as_string(lock.path_join("owner.txt"))!=original,"each acquisition has a unique nonce")
	var f := FileAccess.open(lock.path_join("owner.txt"),FileAccess.WRITE)
	f.store_string(original); f.close()
	a._release_lock(lock)
	check(FileAccess.get_file_as_string(lock.path_join("owner.txt"))==original,"replaced disk owner survives stale in-memory ownership")
	DirAccess.remove_absolute(lock.path_join("owner.txt"))
	DirAccess.remove_absolute(lock)
	DirAccess.remove_absolute(path)
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("SAVE_LOCK_CHECKS_PASS" if failed==0 else "SAVE_LOCK_CHECKS_FAIL")
	quit(0 if failed==0 else 1)
