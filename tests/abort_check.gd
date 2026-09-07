extends SceneTree
## 003-R2：启动失败受控短路验收（父进程注入坏配置 → 子进程真实启动主场景）。
## 用法：godot --headless --path <工程根> -s res://tests/abort_check.gd
## PASS 判据：子进程（真实主场景 main.tscn，非测试脚本）以非零码退出，
## 输出含 003-R2 ABORT 短路记录（受控停止，不访问半初始化组件）；
## 结束后恢复生产配置并校验字节一致（隔离副本原则）。

func _initialize() -> void:
	var cfg := ProjectSettings.globalize_path("res://configs/player_tank_vehicle.tres")
	var backup := "user://abort_check_backup.tres"
	# 自愈：上一次运行若中途崩溃（坏配置已注入未恢复），先从 user:// 备份恢复
	var f := FileAccess.open(cfg, FileAccess.READ)
	if f == null:
		print("[abort-check] FAIL: cannot read production config")
		quit(1)
		return
	var orig := f.get_as_text()
	f.close()
	if FileAccess.file_exists(backup):
		var fb := FileAccess.open(backup, FileAccess.READ)
		var saved := fb.get_as_text()
		fb.close()
		if saved != orig:
			var wr := FileAccess.open(cfg, FileAccess.WRITE)
			wr.store_string(saved)
			wr.close()
			orig = saved
			print("[abort-check] self-heal: restored config left dirty by a previous crashed run")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(backup))
	# 坏配置：verification = verified 但 source_refs 仍是 TEST ONLY → validate 必拒
	var bad := orig.replace('verification = "unknown"', 'verification = "verified"')
	if bad == orig:
		print("[abort-check] FAIL: could not mutate config copy (marker not found)")
		quit(1)
		return
	var w := FileAccess.open(cfg, FileAccess.WRITE)
	w.store_string(bad)
	w.close()
	# 崩溃保险：注入成功后立刻落备份（恢复/自愈都依赖它）
	var wb := FileAccess.open(backup, FileAccess.WRITE)
	wb.store_string(orig)
	wb.close()
	print("[abort-check] bad config injected; launching real main scene in subprocess...")
	var exe := ProjectSettings.globalize_path("res://tools/godot/Godot_v4.7.2-stable_win64_console.exe")
	var out: Array = []
	var code: int = OS.execute(exe, ["--headless", "--path", ProjectSettings.globalize_path("res://")], out, true)
	# 立即恢复生产配置
	var r := FileAccess.open(cfg, FileAccess.WRITE)
	r.store_string(orig)
	r.close()
	var f2 := FileAccess.open(cfg, FileAccess.READ)
	var restored := f2.get_as_text()
	f2.close()
	var text := "".join(out)
	var aborted := text.contains("003-R2 ABORT")
	var clean := restored == orig
	if clean:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(backup))
	print("[abort-check] subprocess exit=%d abort_log=%s config_restored=%s" % [code, str(aborted), str(clean)])
	if code != 0 and aborted and clean:
		print("[abort-check] PASS: bad config → real main scene aborts with nonzero exit; production config intact")
		quit(0)
	else:
		print("[abort-check] FAIL")
		quit(1)