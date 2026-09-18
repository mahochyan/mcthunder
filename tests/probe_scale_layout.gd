extends SceneTree
## UI-BIZ-01 stage 4 diagnostic, committed as evidence. It builds a real garage, raises the text scale the way the
## settings panel and the garage suite do, waits for layout, and prints the outer margin constants and the strip's
## rectangle. It answers by value what guessing could not:
##
##   * with the scale raised, the margins stayed at twenty-four and the vehicle row ended at 725 pixels on a 720 window;
##   * the frontend's remembered scale never moved, so the per-frame watch never fired;
##   * ONE explicit call to apply_scale_layout moved the margins to sixteen and the row up to 697 pixels.
##
## So the scale-aware layout is correct and only the trigger that should call it in every path is still open. Printing a
## Script object here hung the run once, so this version stays with plain values.

func _initialize() -> void: call_deferred("run")

func frames(count: int) -> void:
	for i in count: await process_frame

func margins(outer: MarginContainer) -> String:
	var parts: Array[String] = []
	for side in ["left","right","top","bottom"]:
		parts.append("%s=%d" % [side,int(outer.get_theme_constant("margin_"+side))])
	return ", ".join(parts)

func strip_rect(frontend) -> Rect2:
	return (frontend.collection_scroll as Control).get_global_rect()

func run() -> void:
	root.size = Vector2i(1280,720)
	var shell := GarageShell.new()
	shell.profile = ProfileStore.new("")
	root.add_child(shell)
	await frames(6)
	var frontend = shell.frontend
	print("probe: remembered_scale=",frontend._last_scale," setting=",AccessibilitySettings.ui_scale)
	if frontend.outer_box != null: print("probe: margins now: ",margins(frontend.outer_box))
	var strip_now: Rect2 = strip_rect(frontend)
	print("probe: strip now: y=",strip_now.position.y," h=",strip_now.size.y," bottom=",strip_now.end.y)
	AccessibilitySettings.ui_scale = 1.25
	shell.theme = GarageTheme.theme()
	AccessibilitySettings.apply(shell)
	await frames(12)
	print("probe: after scale, remembered=",frontend._last_scale," setting=",AccessibilitySettings.ui_scale)
	if frontend.outer_box != null: print("probe: margins after: ",margins(frontend.outer_box))
	var strip_scaled: Rect2 = strip_rect(frontend)
	print("probe: strip after: y=",strip_scaled.position.y," h=",strip_scaled.size.y," bottom=",strip_scaled.end.y)
	frontend.apply_scale_layout()
	await frames(6)
	var strip_explicit: Rect2 = strip_rect(frontend)
	print("probe: strip after explicit apply_scale_layout: y=",strip_explicit.position.y," bottom=",strip_explicit.end.y)
	if frontend.outer_box != null: print("probe: margins explicit: ",margins(frontend.outer_box))
	print("SCALE_LAYOUT_PROBE_DONE")
	quit(0)
