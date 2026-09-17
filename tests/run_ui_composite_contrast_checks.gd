extends SceneTree
## WT-UI-007 follow-up: the design asks for the HUD's contrast to be checked on the FINAL COMPOSITED background -
## bright sky, dark buildings, fire - and not only against the colour swatches. The token pairs were measured
## earlier; this check samples the real rendered pixels of the ammunition panel out of actual match captures, takes
## the panel's own composite colour from them (median, so the text stays a minority), and contrasts the token text
## colour against that measured background.
##
## The sampling region is derived from the panel rectangle the HUD verifier measured at 1280x720
## (position 495,517 size 556x155), expressed as fractions so the same check works on the other capture sizes.
## A background this repository has no capture for - a burning vehicle - is deliberately NOT_RUN rather than
## claimed, and the reason is printed.
const CAPTURES := [
	{"path":"res://logs/WT-UI-FIELDWORK-01/wt-ui-012-hud/hud_10_normal_compact.png","label":"river, sky and terrain behind the HUD"},
	{"path":"res://logs/WT-UI-FIELDWORK-01/wt-ui-012-hud/hud_11_optics.png","label":"optics view background"},
	{"path":"res://logs/WT-UI-FIELDWORK-01/wt-ui-012-hud/hud_12_wide.png","label":"wide capture background"},
]
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

## Median colour of the sampled region: the panel composite dominates and the glyphs stay a minority.
static func median_color(image: Image, x0: int, x1: int, y0: int, y1: int) -> Color:
	var reds: Array[float] = []
	var greens: Array[float] = []
	var blues: Array[float] = []
	for x in range(x0,x1,2):
		for y in range(y0,y1,2):
			var pixel := image.get_pixel(x,y)
			reds.append(pixel.r); greens.append(pixel.g); blues.append(pixel.b)
	if reds.is_empty(): return Color.BLACK
	reds.sort(); greens.sort(); blues.sort()
	var middle := int(reds.size()/2)
	return Color(reds[middle],greens[middle],blues[middle])

func _run() -> void:
	var text := UiTokens.color("text_primary")
	var target := UiTokens.metric("contrast_targets.readable_text",4.5)
	var measured := 0
	for capture in CAPTURES:
		var path := str(capture.path)
		if not FileAccess.file_exists(path):
			print("[NOT_RUN] capture missing: %s" % path)
			continue
		var image := Image.load_from_file(path)
		if image == null or image.is_empty():
			check(false, "capture loads as an image: %s" % path)
			continue
		# Fractional region of the measured ammunition panel (495,517 556x155 at 1280x720), inset slightly so the
		# panel border does not dominate the sample.
		var x0 := int(float(image.get_width())*0.395)
		var x1 := int(float(image.get_width())*0.815)
		var y0 := int(float(image.get_height())*0.735)
		var y1 := int(float(image.get_height())*0.925)
		var composite := median_color(image,x0,x1,y0,y1)
		var ratio := contrast(text,composite)
		measured += 1
		print("  %s: composite=%s ratio=%.2f (%s)" % [path.get_file(),composite.to_html(false),ratio,str(capture.label)])
		check(ratio >= target, "HUD text clears the readable target on the real composited background of %s (%.2f >= %.1f)" % [path.get_file(),ratio,target])
	# Honest coverage statement: two of the three backgrounds the design names are present in this repository's
	# captures; a burning vehicle is not, so that one stays NOT_RUN with its reason.
	print("[NOT_RUN] fire background: no capture in this repository shows a burning vehicle behind the HUD, so that background stays NOT_RUN; sky and terrain backgrounds are measured above")
	check(measured >= 2, "at least two composited backgrounds were measured (%d)" % measured)
	print("=== ui composite contrast: %d checks, %d failed ===" % [count,failed])
	print("UI_COMPOSITE_CONTRAST_CHECKS_PASS" if failed==0 else "UI_COMPOSITE_CONTRAST_CHECKS_FAIL")
	quit(0 if failed==0 else 1)
