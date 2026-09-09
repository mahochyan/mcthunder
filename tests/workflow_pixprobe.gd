extends SceneTree
## 工作流包截图客观验证：车辆覆盖率 / 主色 / 剪影比例
const DIR := "docs/evidence/workflow-v1/"
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	for f in ["us_m4a3_75w_vvss_1944", "us_m24_m6_t85e1_1951", "us_m26_m3_1945", "us_m36_m4a1_1945"]:
		for v in ["side", "front", "rear3q"]:
			var img := Image.load_from_file(ProjectSettings.globalize_path(DIR + f + "_" + v + ".png"))
			var bg := Color(0.5, 0.55, 0.6)
			var n := 0
			var minx := 1e9; var maxx := -1e9; var miny := 1e9; var maxy := -1e9
			var rsum := 0.0; var gsum := 0.0; var bsum := 0.0
			for y in range(0, img.get_height(), 4):
				for x in range(0, img.get_width(), 4):
					var c := img.get_pixel(x, y)
					var d: float = absf(c.r - bg.r) + absf(c.g - bg.g) + absf(c.b - bg.b)
					if d > 0.08:
						n += 1
						rsum += c.r; gsum += c.g; bsum += c.b
						minx = min(minx, x); maxx = max(maxx, x)
						miny = min(miny, y); maxy = max(maxy, y)
			var cov := float(n) / float((img.get_width() / 4) * (img.get_height() / 4))
			var w := maxx - minx; var h := maxy - miny
			print("WF_PIX %s_%s cov=%.1f%% mean=(%.2f,%.2f,%.2f) bbox=%dx%d aspect=%.2f" % [
				f, v, cov * 100.0, rsum / n, gsum / n, bsum / n, w, h, float(w) / float(h)])
	quit(0)