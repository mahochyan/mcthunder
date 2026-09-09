extends SceneTree
## 证据文件探针：orm_mask_tmp / ao_tmp 覆盖率
const DIR := "res://assets/art001/m4a3_pilot/"
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	for f in ["orm_mask_tmp.png", "ao_tmp.png"]:
		var img := Image.load_from_file(ProjectSettings.globalize_path(DIR + f))
		if img == null:
			print("ART001_PROBE %s MISSING" % f)
			continue
		var w := img.get_width()
		var nonzero := 0
		var gsum := 0.0
		var rsum := 0.0
		var total := 0
		for y in range(0, img.get_height(), 2):
			for x in range(0, w, 2):
				var c := img.get_pixel(x, y)
				total += 1
				if c.r > 0.01 or c.g > 0.01:
					nonzero += 1
				rsum += c.r
				gsum += c.g
		print("ART001_PROBE %s %dx%d nonzero=%.1f%% R_mean=%.3f G_mean=%.3f" % [f, w, img.get_height(), 100.0 * nonzero / total, rsum / total, gsum / total])
	quit(0)