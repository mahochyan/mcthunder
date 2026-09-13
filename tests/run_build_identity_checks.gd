extends SceneTree
# WT-001-R2 verification entry: the build identity must agree with project.godot,
# must be wired into the menu display points, and must never claim release_ready.
var count := 0
var failed := 0
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func _run() -> void:
	var version: String = str(ProjectSettings.get_setting("application/config/version"))
	_check(BuildIdentity.VERSION == version,"BuildIdentity.VERSION matches project.godot config/version (%s)" % version)
	_check(BuildIdentity.BUILD_ID == "continuation-20260913","build id is the fixed continuation build id")
	_check(BuildIdentity.SOURCE_BASE_COMMIT.length() == 40,"source base commit is a full 40-character SHA")
	_check(BuildIdentity.RELEASE_READY == false,"candidate never claims release_ready")
	var described := BuildIdentity.describe()
	_check(described.contains(BuildIdentity.BUILD_ID) and described.contains(BuildIdentity.SOURCE_BASE_COMMIT.substr(0,7)) and described.contains("开发候选"),"describe() carries version, build id, base SHA and the non-release state")
	_check(described.length() > 30,"describe() is informative enough for the menu line")
	for path in ["res://scripts/core/garage_shell.gd","res://scripts/ui/garage_frontend.gd"]:
		var text := FileAccess.get_file_as_string(path)
		_check(text.contains("BuildIdentity.describe()"),"menu identity wired into %s" % path)
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("BUILD_IDENTITY_CHECKS_PASS" if failed == 0 else "BUILD_IDENTITY_CHECKS_FAIL")
	quit(1 if failed else 0)
