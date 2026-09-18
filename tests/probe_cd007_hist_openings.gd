extends SceneTree
## MCT-COMBAT-DEEPEN-01 CD07: the historical class's declared openings, read through the PRODUCTION catalog's own loading
## rather than through a hand-built file read, because the hand-built read never worked and the catalog is the path the
## historical suite already proves.
##
## Judgments:
##   H1 the production catalog loads all four historical packages and their packets carry the open-top contrast itself: the
##      M36 the order names declares it, the M26 of the same class does not.
##   H2 whatever the catalog exposes of the rebuilt layout is reported, and if it exposes the declared openings then the M36
##      must carry an open fighting compartment aperture that the M26 does not - connectivity from declared geometry rather
##      than from a vehicle_type label.

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("[PASS] " if ok else "[FAIL] ",label)

func _run() -> void:
	var defs := VehicleDefs.new()
	check(defs.load_defaults().ok,"CD07 hist the legacy definitions load")
	var catalog := VehicleCatalog.new()
	var result := catalog.load_all(defs)
	for error in result.errors: print("[DETAIL] ",error)
	check(result.ok,"CD07 hist H1 the production catalog loads every historical package")
	check(catalog.packages.size()==4,"CD07 hist H1 four historical packages are registered: %d" % catalog.packages.size())
	var readings := {}
	for id in VehicleCatalog.IDS:
		if not catalog.packages.has(id): continue
		var entry: Variant = catalog.packages[id]
		var packet: Dictionary = entry.packet
		var keys: Array = []
		for key in entry: keys.append(str(key))
		var open_top := false
		if packet.has("geometry"): open_top = bool(packet.geometry.get("open_top",false))
		var layout_found := ""
		var opening_ids: Array = []
		var compartment := 0
		for candidate in ["layout","damage_layout","vehicle_layout"]:
			if entry.has(candidate) and entry[candidate] != null:
				var lay: VehicleLayoutDefinition = entry[candidate]
				layout_found = candidate
				for opening in lay.declared_openings:
					var oid := str(opening.get("id",""))
					opening_ids.append(oid)
					if oid.contains("open_fighting_compartment"): compartment += 1
				break
		readings[str(id)] = {"open_top":open_top,"layout_key":layout_found,"openings":opening_ids.size(),
			"compartment":compartment,"keys":keys}
		print("[CD07 hist] H2 %s => open_top=%s ; entry keys=%s ; layout via=%s ; declared_openings=%d ; open_fighting_compartment=%d %s" % [
			str(id),str(open_top),str(keys),("(none)" if layout_found=="" else layout_found),opening_ids.size(),compartment,str(opening_ids)])
	check(readings.size()==4,"CD07 hist H1 all four packages were read")
	var m36: Dictionary = readings.get("us_m36_m4a1_1945",{})
	var m26: Dictionary = readings.get("us_m26_m3_1945",{})
	check(bool(m36.get("open_top",false)) and not bool(m26.get("open_top",false)),
		"CD07 hist H1 the production packets carry the contrast themselves: M36 open_top=%s, M26 open_top=%s" % [
			str(m36.get("open_top","")),str(m26.get("open_top",""))])
	var any_layout := false
	for id in readings: if str(readings[id].get("layout_key",""))!="": any_layout = true
	print("[CD07 hist] H2 a rebuilt layout is exposed by the catalog entry: %s" % str(any_layout))
	if any_layout:
		check(int(m36.get("compartment",0))>int(m26.get("compartment",0)),
			"CD07 hist H2 MEASURED: the open-top representative declares an open fighting compartment aperture and the closed one does not (%d vs %d)" % [int(m36.get("compartment",0)),int(m26.get("compartment",0))])
	else:
		print("[CD07 hist] H2 NOTE: the catalog entry exposes no layout under the names probed, so the historical openings are NOT yet measured here and that stays named work rather than being claimed")
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD07_HIST_OPENINGS_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)