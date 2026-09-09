extends SceneTree
## 引擎侧原始像素统计：Image.load 直接读文件字节（无色彩管理）
const DIR := "res://assets/art001/m4a3_pilot/"
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	for f in ["basecolor.png", "orm.png", "normal_gl.png"]:
		var img := Image.load_from_file(ProjectSettings.globalize_path(DIR + f))
		var w := img.get_width()
		var sum := Vector3.ZERO
		var p95r := 0.0
		var rs := []
		var n := w * img.get_height()
		for y in range(0, img.get_height(), 4):
			for x in range(0, w, 4):
				var c := img.get_pixel(x, y)
				sum += Vector3(c.r, c.g, c.b)
				rs.append(c.r)
		var cnt := float(rs.size())
		rs.sort()
		print("ART001_RAW %s %dx%d R_mean=%.3f G_mean=%.3f B_mean=%.3f R_p95=%.3f" % [f, w, img.get_height(), sum.x / cnt, sum.y / cnt, sum.z / cnt, rs[int(cnt * 0.95)]])
	quit(0)