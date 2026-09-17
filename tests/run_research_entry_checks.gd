extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var keys := ["branch_medium","branch_heavy","branch_light","branch_destroyer","branch_spaa","branch_other","research_heading","research_back","research_routes","research_search_hint","research_filter_models","research_counts","research_tree_footnote","research_thumb_missing","research_content_ready","research_content_waiting","research_owned","research_locked","research_not_admitted","research_identity","research_family","research_variants","research_variants_count","research_variant_reference","research_empty_title","research_empty_hint","research_model_ready","research_model_pending","research_model_failed","research_trial","research_select","research_select_blocked","research_select_open"]
	var missing := 0
	for key in keys:
		if LocalizationService.text(key) == "["+key+"]": print("[FAIL] missing entry: ",key); missing += 1
	print("=== research entries: %d keys, %d missing ===" % [keys.size(),missing])
	print("RESEARCH_ENTRIES_PASS" if missing==0 else "RESEARCH_ENTRIES_FAIL")
	quit(0 if missing==0 else 1)
