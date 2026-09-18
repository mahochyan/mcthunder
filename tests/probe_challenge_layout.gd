extends SceneTree
## UI-BIZ-01 stage 3 diagnostic: the challenge screen draws a column of orphaned text at the left edge, which the
## stage 0 baseline shows was already true before this pass. This probe instantiates the screen, waits for layout and
## prints every control whose rectangle is suspiciously narrow or that sits outside the screen, together with its
## parent chain, so the offender is named by measurement instead of guessed at.

func _initialize() -> void:
	root.size = Vector2i(1280,720)
	var screen := ChallengeSelection.new()
	screen.profile = ProfileStore.new("user://ui_biz_probe/profile")
	root.add_child(screen)
	call_deferred("_report",screen)

func _report(screen: Control) -> void:
	for i in 8: await process_frame
	print("=== challenge layout probe ===")
	print("screen rect=",screen.get_global_rect())
	var stack: Array[Node] = [screen]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Control:
			var control := node as Control
			var rect := control.get_global_rect()
			var text := str(control.text) if "text" in control else ""
			var narrow := rect.size.x < 40.0 and text.length() > 3
			var outside := rect.position.x < -1.0 or rect.position.y < -1.0 or rect.end.x > 1282.0 or rect.end.y > 722.0
			var empty_size := rect.size.x <= 0.5 or rect.size.y <= 0.5
			if narrow or outside or empty_size:
				var chain := ""
				var walk: Node = control
				while walk != null and walk != screen.get_parent():
					chain = walk.name + (("/" + chain) if not chain.is_empty() else "")
					walk = walk.get_parent()
				print("  %s rect=%s text=%s%s%s chain=%s" % [
					control.get_class(), rect, text.substr(0,24),
					"" if not narrow else " NARROW", "" if not outside else " OUTSIDE", chain])
		for child in node.get_children(): stack.append(child)
	# Which nodes actually own the labels the screen declares.
	for name in ["description","rules_label","rounds_label","current_label","best_label"]:
		var node: Node = screen.get(name)
		if node is Control:
			var control := node as Control
			print("  %s: rect=%s parent=%s parent_rect=%s" % [
				name, control.get_global_rect(), control.get_parent().name,
				(control.get_parent() as Control).get_global_rect() if control.get_parent() is Control else Rect2()])
	print("CHALLENGE_PROBE_DONE")
	quit(0)
