extends SceneTree
## MCT-COMBAT-DEEPEN-01 CD07: why the engineering HE packet fails admission, asked directly instead of guessed.
## A previous attempt broke three suites and I reverted it; this probe reads a copy of the modified packet from an untracked
## fixture path and asks the production shell catalogue to build it, so the ERRORS it returns name the missing field.

const FIXTURE := "res://assets/vehicles/test_cd007_he_fixture/ussr_t_80b_he.json"

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("[PASS] " if ok else "[FAIL] ",label)

func _run() -> void:
	var text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(FIXTURE))
	if text.is_empty(): text = FileAccess.get_file_as_string(FIXTURE)
	check(not text.is_empty(),"CD07 HE diagnostic the fixture packet loads")
	if text.is_empty(): quit(1); return
	var packet: Dictionary = JSON.parse_string(text)
	check(not packet.is_empty(),"CD07 HE diagnostic the fixture packet parses as JSON")
	var shells: Array = packet.get("shell_catalog",{}).get("shells",[])
	print("[CD07 HE diagnostic] shell count=%d ; ids=%s" % [shells.size(),str(shells.map(func(s): return str(s.get("id",""))))])
	# 1) the shell catalogue's own builder, which is the gate that names malformed entries
	var built := VehicleShellCatalog.build(packet)
	print("[CD07 HE diagnostic] VehicleShellCatalog.build ok=%s" % str(built.ok))
	for error in built.get("errors",[]): print("[CD07 HE diagnostic]   shell error: %s" % str(error))
	# 2) the whole-packet content pipeline, which is what the garage suites trip over
	var piped := VehicleContentPipeline.validate_package(packet)
	print("[CD07 HE diagnostic] VehicleContentPipeline.validate_package ok=%s" % str(piped.ok))
	for error in piped.get("errors",[]): print("[CD07 HE diagnostic]   pipeline error: %s" % str(error))
	check(not built.ok or not piped.ok,
		"CD07 HE diagnostic the fixture is expected to fail here, because that failure is the thing being measured")
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	quit(0)
