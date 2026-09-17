extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var keys := ["hud_chamber_line","hud_carrying_line","hud_carrying_none","hud_next_line","hud_stock_line","hud_ammo_overview"]
	var missing := 0
	for key in keys:
		if LocalizationService.text(key) == "["+key+"]": print("[FAIL] missing: ",key); missing += 1
	print("=== hud entries: %d keys, %d missing ===" % [keys.size(),missing])
	print("HUD_ENTRIES_PASS" if missing==0 else "HUD_ENTRIES_FAIL")
	quit(0 if missing==0 else 1)
