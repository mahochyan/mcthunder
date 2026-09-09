extends SceneTree
## basecolor 主色直方图：量化到 1/32 取 top 颜色
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/art001/m4a3_pilot/basecolor.png"))
	var hist := {}
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var c := img.get_pixel(x, y)
			var key := Vector3i(int(c.r * 32), int(c.g * 32), int(c.b * 32))
			if hist.has(key):
				hist[key] = int(hist[key]) + 1
			else:
				hist[key] = 1
	var items := []
	for k in hist:
		items.append([k, hist[k]])
	items.sort_custom(func(a, b): return a[1] > b[1])
	for i in range(min(8, items.size())):
		var k: Vector3i = items[i][0]
		var n: int = items[i][1]
		print("ART001_HIST rgb=(%.3f,%.3f,%.3f) share=%.1f%%" % [k.x / 32.0, k.y / 32.0, k.z / 32.0, 100.0 * n / 262144.0])
	quit(0)