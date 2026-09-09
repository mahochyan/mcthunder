extends SceneTree
## basecolor 编码诊断：找单次编码橄榄(0.649,0.680,0.566) vs 双重编码(0.837,0.853,0.777)的像素量
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/art001/m4a3_pilot/basecolor.png"))
	var once := 0
	var twice := 0
	var white := 0
	var total := 0
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var c := img.get_pixel(x, y)
			total += 1
			if c.r > 0.98 and c.g > 0.98:
				white += 1
			var d1 := Vector3(0.649 - c.r, 0.680 - c.g, 0.566 - c.b).length()
			var d2 := Vector3(0.837 - c.r, 0.853 - c.g, 0.777 - c.b).length()
			if d1 < 0.05:
				once += 1
			if d2 < 0.05:
				twice += 1
	print("ART001_ENC once_olive=%.1f%% twice_olive=%.1f%% white=%.1f%% total=%d" % [100.0 * once / total, 100.0 * twice / total, 100.0 * white / total, total])
	quit(0)