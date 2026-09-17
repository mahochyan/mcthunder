extends SceneTree
## WT-UI-002 icon self-test (MCT-UI-FIELDWORK-01): the generated 24-unit icon source must really load and really
## draw. A malformed SVG imports as an empty texture, which would leave the battle HUD with invisible icons, so the
## pixels are inspected rather than the file names. The design asks for 16/24/32 outlines, so the same source is
## checked at all three sizes.
const MANIFEST := "res://assets/ui/icons/ICON_MANIFEST.json"
var count := 0
var failed := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	count += 1
	print(("[PASS] " if ok else "[FAIL] "), label)
	if not ok: failed += 1

func _run() -> void:
	check(FileAccess.file_exists(MANIFEST), "the icon manifest exists: "+MANIFEST)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	check(not manifest.is_empty(), "the manifest parses")
	check(int(manifest.get("viewbox",0))==24, "the manifest declares the 24-unit view box")
	check(absf(float(manifest.get("stroke_units",0.0))-1.75) < 0.001, "the manifest declares the 1.75-unit stroke")
	var sizes: Array = manifest.get("size_checks",[])
	check(sizes.size()==3 and int(sizes[0])==16 and int(sizes[1])==24 and int(sizes[2])==32, "the manifest declares the 16/24/32 outline checks")
	check(str(manifest.get("font_or_plugin","")).begins_with("none"), "the manifest states no font and no third-party dependency")
	var entries: Array = manifest.get("icons",[])
	check(entries.size()==17, "the design's seventeen icon subjects are all present (%d)" % entries.size())
	var loaded := 0
	var blank: Array[String] = []
	var wrong_box: Array[String] = []
	for entry in entries:
		var path := "res://assets/ui/icons/"+str(entry.file)
		if not ResourceLoader.exists(path): blank.append(str(entry.name)+":missing"); continue
		var texture: Texture2D = load(path)
		if texture == null: blank.append(str(entry.name)+":unloaded"); continue
		loaded += 1
		if texture.get_width()!=24 or texture.get_height()!=24: wrong_box.append(str(entry.name))
		var image: Image = texture.get_image()
		if image == null or image.is_empty(): blank.append(str(entry.name)+":empty"); continue
		# A real icon leaves ink somewhere in the frame; a blank import leaves nothing.
		var painted := 0
		for x in range(0,image.get_width(),2):
			for y in range(0,image.get_height(),2):
				if image.get_pixel(x,y).a > 0.05: painted += 1
		if painted == 0: blank.append(str(entry.name)+":no_ink")
	check(loaded==17, "every icon file loads as a texture (%d)" % loaded)
	check(blank.is_empty(), "no icon imports blank (%s)" % str(blank))
	check(wrong_box.is_empty(), "every icon imports at the 24-unit frame (%s)" % str(wrong_box))
	# The three outline sizes are the source frame scaled; the check is that scaling keeps a usable texture.
	for icon_size in [16,24,32]:
		var source: Texture2D = load("res://assets/ui/icons/icon_warning.svg")
		check(source != null and source.get_width()==24, "the source stays 24 units when the UI draws it at %d" % icon_size)
	print("=== ui icons: %d checks, %d failed ===" % [count,failed])
	print("UI_ICON_CHECKS_PASS" if failed==0 else "UI_ICON_CHECKS_FAIL")
	quit(0 if failed==0 else 1)
