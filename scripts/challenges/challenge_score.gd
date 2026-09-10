class_name ChallengeScore
extends RefCounted
static func evaluate(c: Dictionary, stats: Dictionary, passed: bool) -> Dictionary:
	var economy: bool = int(stats.shots) <= int(c.economy)
	var repaired: bool = int(stats.repairs) > 0
	var quick: bool = float(stats.elapsed) <= float(c.quick)+0.000001
	var bonus: bool = repaired if c.id == "hold_ground" else economy
	var stars := (1+int(bonus)+int(quick)) if passed else 0
	var score := stars*10000+maxi(0,int((c.limit-stats.elapsed)*10))+maxi(0,c.rounds-stats.shots)*100 if passed else 0
	return {"stars":stars,"score":score,"elapsed_ms":roundi(stats.elapsed*1000),"shots":int(stats.shots),"repairs":int(stats.repairs),
		"explanation":LocalizationService.text("ui_78d4d3f8abc6")%[LocalizationService.text("ui_e7ab170a1a9b") if passed else LocalizationService.text("ui_0a163bc2be36"),"★" if passed and bonus else "☆",LocalizationService.text("ui_a5e0bb0d903d") if c.id == "hold_ground" else LocalizationService.text("ui_08d7fa81abe6")%[c.economy,stats.shots],"★" if passed and quick else "☆",c.quick,stats.elapsed]}
static func best_row(result: Dictionary) -> Dictionary:
	var out := {}
	for field in ["stars","score","elapsed_ms","shots","repairs"]: out[field] = result[field]
	return out
static func validate_bests(rows: Variant) -> bool:
	if not rows is Dictionary or rows.size() > ChallengeCatalog.IDS.size()*ChallengeCatalog.LEVELS.size(): return false
	var configs := {}
	for id in ChallengeCatalog.IDS:
		for level in ChallengeCatalog.LEVELS:
			var c := ChallengeCatalog.create(id,level)
			configs[ChallengeCatalog.key(c)] = c
	for key in rows:
		if not configs.has(key) or not rows[key] is Dictionary: return false
		var row: Dictionary = rows[key]
		if row.size() != 5: return false
		for field in ["stars","score","elapsed_ms","shots","repairs"]:
			if not row.get(field) is int or row[field] < 0: return false
		var c: Dictionary = configs[key]
		if row.stars < 1 or row.stars > 3 or row.elapsed_ms > roundi(c.limit*1000) or row.shots > c.rounds or row.repairs > 256: return false
		# Quantized time is the common source for live scoring and disk validation.
		var evaluated := evaluate(c,{"elapsed":row.elapsed_ms/1000.0,"shots":row.shots,"repairs":row.repairs},true)
		if best_row(evaluated) != row: return false
	return true
static func describe_best(row: Dictionary) -> String:
	if row.is_empty(): return LocalizationService.text("ui_53c6a1ed1647")
	return LocalizationService.text("ui_386640a0d082")%[row.stars,row.score,row.elapsed_ms/1000.0,row.shots]
