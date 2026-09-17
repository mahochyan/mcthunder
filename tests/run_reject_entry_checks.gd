extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var keys := ["loadout_reject_capacity","loadout_reject_first_stock"]
	var missing := 0
	for key in keys:
		if LocalizationService.text(key) == "["+key+"]": print("[FAIL] missing: ",key); missing += 1
		else: print("[PASS] ",key," = ",LocalizationService.text(key))
	print("=== reject entries: %d keys, %d missing ===" % [keys.size(),missing])
	print("REJECT_ENTRIES_PASS" if missing==0 else "REJECT_ENTRIES_FAIL")
	quit(0 if missing==0 else 1)
