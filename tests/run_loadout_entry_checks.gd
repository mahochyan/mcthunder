extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var keys := ["loadout_group_ammo","loadout_group_lineup","loadout_group_check","loadout_estimated","loadout_no_packet","loadout_config_summary","loadout_shell_meta","loadout_summary_line"]
	var missing := 0
	for key in keys:
		if LocalizationService.text(key) == "["+key+"]": print("[FAIL] missing: ",key); missing += 1
	print("=== loadout entries: %d keys, %d missing ===" % [keys.size(),missing])
	print("LOADOUT_ENTRIES_PASS" if missing==0 else "LOADOUT_ENTRIES_FAIL")
	quit(0 if missing==0 else 1)
