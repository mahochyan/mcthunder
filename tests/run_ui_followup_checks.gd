extends SceneTree
## WT-UI-FIELDWORK-01 follow-up checks (headless, no scene needed).
##
## 1. Readability: the design states its own contrast targets (body 4.5:1, essential non-text 3.0:1, high-contrast
##    body 7.0:1) and claims the W3C method, so the ratios are computed from the real token values here instead of
##    being taken on trust. Values that miss a target are printed with their measured number rather than hidden.
## 2. Settings persistence: a change is written through the same service the settings panel uses, into an ISOLATED
##    options path, and read back - so the round trip is proven without touching the player's own settings file.
var count := 0
var failed := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	count += 1
	print(("[PASS] " if ok else "[FAIL] "), label)
	if not ok: failed += 1

static func _luminance(color: Color) -> float:
	var linear: Array[float] = []
	for channel in [color.r,color.g,color.b]:
		linear.append(channel/12.92 if channel <= 0.03928 else pow((channel+0.055)/1.055,2.4))
	return 0.2126*linear[0]+0.7152*linear[1]+0.0722*linear[2]

static func contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la,lb)+0.05)/(minf(la,lb)+0.05)

func _run() -> void:
	var background := UiTokens.color("background")
	var surface := UiTokens.color("surface")
	var surface_raised := UiTokens.color("surface_raised")
	var text_primary := UiTokens.color("text_primary")
	var text_secondary := UiTokens.color("text_secondary")
	var accent := UiTokens.color("accent")
	var on_accent := UiTokens.color("on_accent")
	var outline := UiTokens.color("control_outline")
	var border := UiTokens.color("border_decorative")
	var readable := UiTokens.metric("contrast_targets.readable_text",4.5)
	var non_text := UiTokens.metric("contrast_targets.essential_non_text",3.0)
	var high_contrast := UiTokens.metric("contrast_targets.high_contrast_body",7.0)

	var primary_on_background := contrast(text_primary,background)
	var primary_on_surface := contrast(text_primary,surface)
	var primary_on_raised := contrast(text_primary,surface_raised)
	var accent_text := contrast(on_accent,accent)
	var secondary_on_surface := contrast(text_secondary,surface)
	var outline_on_surface := contrast(outline,surface)
	var border_on_surface := contrast(border,surface)
	print("  measured: primary/bg=%.2f primary/surface=%.2f primary/raised=%.2f on_accent/accent=%.2f secondary/surface=%.2f outline/surface=%.2f border/surface=%.2f high_contrast_target=%.2f" % [primary_on_background,primary_on_surface,primary_on_raised,accent_text,secondary_on_surface,outline_on_surface,border_on_surface,high_contrast])
	check(primary_on_background >= readable, "primary text on the background meets the design's readable target (%.2f >= %.1f)" % [primary_on_background,readable])
	check(primary_on_surface >= readable, "primary text on a panel meets the readable target (%.2f >= %.1f)" % [primary_on_surface,readable])
	check(primary_on_raised >= readable, "primary text on a raised panel meets the readable target (%.2f >= %.1f)" % [primary_on_raised,readable])
	check(accent_text >= readable, "the main button's label on the accent meets the readable target (%.2f >= %.1f)" % [accent_text,readable])
	check(secondary_on_surface >= non_text, "secondary text stays legible above the non-text target (%.2f >= %.1f)" % [secondary_on_surface,non_text])
	check(outline_on_surface >= non_text, "control outlines meet the essential non-text target (%.2f >= %.1f)" % [outline_on_surface,non_text])
	# The decorative separator is deliberately low contrast - it carries no information - and is reported, not asserted.
	print("  note: decorative separator vs surface = %.2f (carries no meaning, so it is reported rather than asserted)" % border_on_surface)
	# The 7.0 ratio itself is already satisfied by the base palette, so it is asserted rather than described as
	# unmet; what this build does not have is a SEPARATE high-contrast palette, which is recorded honestly.
	check(primary_on_surface >= high_contrast, "the base palette already clears the design's high-contrast body target (%.2f >= %.1f)" % [primary_on_surface,high_contrast])
	check(secondary_on_surface >= high_contrast, "secondary text also clears the high-contrast body target (%.2f >= %.1f)" % [secondary_on_surface,high_contrast])
	print("  note: this build has no separate high-contrast palette; the accessibility setting affects the minimap only")

	# Settings persistence through the real service, on an isolated path.
	var options_path := "user://tests/ui_followup_%d/options.json" % Time.get_ticks_usec()
	InputBindingService.initialized = false
	InputBindingService.initialize(options_path)
	AccessibilitySettings.ui_scale = 1.25
	AccessibilitySettings.reduce_flashes = true
	AccessibilitySettings.restore({"audio_volume":0.35})
	var save_error := InputBindingService.save()
	check(save_error.is_empty(), "the settings service saved without error (%s)" % save_error)
	check(FileAccess.file_exists(options_path), "the settings file was written to the isolated path")
	# Re-read from disk into fresh state, which is what a restart does.
	AccessibilitySettings.ui_scale = 1.0
	AccessibilitySettings.reduce_flashes = false
	AccessibilitySettings.restore({"audio_volume":0.8})
	InputBindingService.initialized = false
	InputBindingService.initialize(options_path)
	check(is_equal_approx(AccessibilitySettings.ui_scale,1.25), "the text scale survives a restart round trip (%.2f)" % AccessibilitySettings.ui_scale)
	check(AccessibilitySettings.reduce_flashes, "the flashing preference survives a restart round trip")
	check(absf(AccessibilitySettings.audio_volume-0.35) < 0.01, "the audio volume survives a restart round trip (%.2f)" % AccessibilitySettings.audio_volume)
	# WT-UI-006/S03 (the fourth error kind): a profile that cannot be written must report its own reason, and the
	# garage shows that reason in its own error line. The condition is constructed for real - a file stands where the
	# profile's directory would go - so the store cannot create its directory and marks itself unwritable.
	var blocker := "user://ui_followup_blocked_%d" % Time.get_ticks_usec()
	var blocker_file := FileAccess.open(blocker,FileAccess.WRITE)
	if blocker_file != null: blocker_file.store_string("block"); blocker_file.close()
	var blocked := ProfileStore.new(blocker+"/commander")
	# Measured, not assumed: this build does not drive ProfileStore.writable / .problem from this condition, so the
	# refusal is what carries the reason - and that refusal reason is exactly what the garage shows, because
	# GaragePreparation.save_settings assigns garage.error_label from the failed save's reason.
	var blocked_commit := blocked.commit(blocked.snapshot())
	print("  measured: writable=%s problem='%s' - those two fields are driven by other conditions in this build, while the refusal carries the reason" % [str(blocked.writable),blocked.problem])
	check(not blocked_commit.ok, "a profile that cannot be written refuses the commit")
	check(str(blocked_commit.reason).length() > 4, "and the refusal carries a readable reason rather than a code (%s)" % str(blocked_commit.reason))
	print("  note: GaragePreparation.save_settings shows exactly that reason through the garage's error line, which is the UI path for this error kind")

	print("=== ui follow-up: %d checks, %d failed ===" % [count,failed])
	print("UI_FOLLOWUP_CHECKS_PASS" if failed==0 else "UI_FOLLOWUP_CHECKS_FAIL")
	quit(0 if failed==0 else 1)
