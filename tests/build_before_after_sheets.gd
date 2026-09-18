extends SceneTree
## UI-BIZ-01 stage 4: build the before-and-after sheets. Stage 0 captured a baseline of every screen before any styling
## and this pass captured the same screens on the new skin, so each pair is composed side by side - baseline on the left,
## current on the right - into one sheet per set. It uses only Godot's own Image API, so the deliverable needs no external
## image tool and the repository gains no dependency.
##
## Usage: godot --headless --path <root> -s res://tests/build_before_after_sheets.gd -- --baseline <dir> --current <dir> --out <file>

func _initialize() -> void: call_deferred("run")

func argument(name: String, fallback: String) -> String:
	var args := OS.get_cmdline_user_args()
	var index := args.find(name)
	return args[index+1] if index >= 0 and index+1 < args.size() else fallback

func run() -> void:
	var baseline_dir := argument("--baseline","res://logs/UI-BIZ-01/baseline/nav")
	var current_dir := argument("--current","res://logs/UI-BIZ-01/stage4/acceptance/nav")
	var out_path := argument("--out","res://logs/UI-BIZ-01/stage4/compare/BEFORE_AFTER_nav.png")
	var thumb := Vector2i(int(argument("--width","640")),int(argument("--height","360")))
	print("=== before/after sheet ===")
	print("baseline=",baseline_dir)
	print("current=",current_dir)
	var names: Array[String] = []
	var listing := DirAccess.open(baseline_dir)
	if listing == null:
		print("BEFORE_AFTER_SHEET_FAIL no baseline directory")
		quit(1)
		return
	for file in listing.get_files():
		if not file.ends_with(".png"): continue
		if FileAccess.file_exists(current_dir.path_join(file)): names.append(file)
	names.sort()
	if names.is_empty():
		print("BEFORE_AFTER_SHEET_FAIL no matching pairs")
		quit(1)
		return
	# Two columns - baseline, current - and one row per screen, with a two pixel separator so the halves stay distinct.
	var gap := 2
	var sheet := Image.create(thumb.x*2+gap,thumb.y*names.size()+gap*(names.size()-1),false,Image.FORMAT_RGBA8)
	sheet.fill(Color(0.06,0.07,0.08,1.0))
	var row := 0
	var missing := 0
	for name in names:
		var before := Image.load_from_file(baseline_dir.path_join(name))
		var after := Image.load_from_file(current_dir.path_join(name))
		if before == null or after == null:
			missing += 1
			row += 1
			continue
		before.resize(thumb.x,thumb.y,Image.INTERPOLATE_BILINEAR)
		after.resize(thumb.x,thumb.y,Image.INTERPOLATE_BILINEAR)
		var y := row*(thumb.y+gap)
		sheet.blit_rect(before,Rect2i(Vector2i.ZERO,thumb),Vector2i(0,y))
		sheet.blit_rect(after,Rect2i(Vector2i.ZERO,thumb),Vector2i(thumb.x+gap,y))
		row += 1
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	var error := sheet.save_png(out_path)
	print("pairs=",names.size()," rows=",row," missing=",missing," out=",out_path," error=",error)
	print("BEFORE_AFTER_SHEET_DONE" if error == OK else "BEFORE_AFTER_SHEET_FAIL")
	quit(0 if error == OK else 1)
