extends SceneTree
## WT-UI-004 self-test: the garage identity line must come from data, and an id whose nation the data does not
## state must never fall back to the old unconditional "美国 · 陆战载具". Real localisation entries are required,
## so a missing key fails here instead of rendering as [key] in the garage.
var count := 0
var failed := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	count += 1
	print(("[PASS] " if ok else "[FAIL] "), label)
	if not ok: failed += 1

func _run() -> void:
	# 1) the curated historical roster: nation from the repository's own id convention, state from TechSegment.
	for id in VehicleCatalog.IDS:
		check(VehicleDisplayMetadata.nation_code(id)=="usa", "%s nation comes from the id convention (usa)" % id)
		check(VehicleDisplayMetadata.state_key(id)=="vehicle_state_first_release", "%s state comes from the TechSegment pool" % id)
		check(VehicleDisplayMetadata.identity_line(id).contains("美国"), "%s identity line shows the US label" % id)
		check(VehicleDisplayMetadata.typology(id)=="historical", "%s typology is historical" % id)

	# 2) the two engineering pilots: nation comes from the explicit PILOTS data field, state from the pool.
	check(VehicleDisplayMetadata.nation_code("ussr_t_80b")=="ussr", "ussr_t_80b nation comes from the explicit PILOTS field")
	check(VehicleDisplayMetadata.nation_code("germ_leopard_2a4")=="germany", "germ_leopard_2a4 nation comes from the explicit PILOTS field")
	for id in VehicleCatalog.ENGINEERING_IDS:
		check(VehicleDisplayMetadata.state_key(id)=="vehicle_state_experimental", "%s state is the experimental pool" % id)
		check(VehicleDisplayMetadata.typology(id)=="engineering", "%s typology is engineering" % id)

	# 3) the training hull is not a country.
	check(VehicleDisplayMetadata.nation_code("player_tank")=="training", "the training hull is labelled as training, not as a country")
	check(VehicleDisplayMetadata.state_key("player_tank")=="vehicle_state_training", "the training hull reports the training state")

	# 4) THE regression this work order calls out: no default country for anything unknown.
	check(VehicleDisplayMetadata.nation_code("no_such_vehicle_xyz")=="", "an unknown id yields NO nation code")
	check(VehicleDisplayMetadata.nation_label("no_such_vehicle_xyz")==LocalizationService.text("nation_unknown"), "an unknown id shows the explicit unknown label")
	check(not VehicleDisplayMetadata.identity_line("no_such_vehicle_xyz").contains("美国"), "an unknown id never shows the old USA fallback")
	check(VehicleDisplayMetadata.state_key("no_such_vehicle_xyz")=="vehicle_state_unknown", "an unknown id reports an unknown content state")
	check(VehicleDisplayMetadata.typology("no_such_vehicle_xyz")=="", "an unknown id reports no typology")

	# 5) every label is a real localisation entry, never a [key] placeholder.
	for key in ["nation_usa","nation_ussr","nation_germany","nation_training","nation_unknown",
		"vehicle_state_first_release","vehicle_state_experimental","vehicle_state_deferred",
		"vehicle_state_engineering","vehicle_state_historical","vehicle_state_training","vehicle_state_unknown",
		"vehicle_role_unknown"]:
		check(LocalizationService.text(key)!="["+key+"]", "localisation entry exists: %s" % key)

	# 6) fields no service exposes are declared, so the garage renders them as unknown instead of inventing them.
	check(VehicleDisplayMetadata.unavailable_fields().has("role_label"), "the role label is declared unavailable rather than invented")
	check(VehicleDisplayMetadata.unavailable_fields().has("blocked_reason"), "the blocked reason is declared unavailable rather than invented")

	print("=== vehicle identity: %d checks, %d failed ===" % [count,failed])
	print("VEHICLE_IDENTITY_CHECKS_PASS" if failed==0 else "VEHICLE_IDENTITY_CHECKS_FAIL")
	quit(0 if failed==0 else 1)
