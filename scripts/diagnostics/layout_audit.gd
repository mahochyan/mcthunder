class_name LayoutAudit
extends RefCounted
## UI-BIZ-01 stage 3: a reusable layout audit, extracted from the manual comparison that found the challenge screen's
## orphaned column. It walks one live screen and reports three defect classes:
##
##   narrow  - a text-bearing control whose width has collapsed below a legible minimum. The challenge screen's third
##             label was one pixel wide and five hundred tall, which is how a wrapped label looks when its minimum
##             width collapses inside a container with horizontal scrolling disabled.
##   outside - a visible control drawn outside the viewport. Content inside a ScrollContainer is exempt, because being
##             outside the visible rectangle is exactly what scrolling means.
##   stacked - two visible controls sharing one rectangle, which is how three labels looked while they were all added
##             to a ScrollContainer that had laid them out on top of each other.
##
## The audit only reads geometry; it changes nothing.

const NARROW_MIN_WIDTH := 40.0
const NARROW_MIN_CHARS := 4
const EDGE_TOLERANCE := 1.0

static func collect(root: Node, view: Vector2) -> Dictionary:
	var narrow: Array[String] = []
	var outside: Array[String] = []
	var stacked: Array[String] = []
	var seen: Dictionary = {}
	if root == null:
		return {"narrow":narrow,"outside":outside,"stacked":stacked}
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Control:
			var control := node as Control
			var in_scroll := false
			var walk: Node = control.get_parent()
			while walk != null:
				if walk is ScrollContainer:
					in_scroll = true
					break
				walk = walk.get_parent()
			var text := ""
			if control is Label: text = (control as Label).text
			elif control is Button: text = (control as Button).text
			if not text.strip_edges().is_empty() and control.is_visible_in_tree():
				var rect := control.get_global_rect()
				var tag := "%s(%s)" % [control.name,text.strip_edges().substr(0,12)]
				if rect.size.x < NARROW_MIN_WIDTH and text.length() >= NARROW_MIN_CHARS:
					narrow.append(tag)
				if not in_scroll and (rect.position.x < -EDGE_TOLERANCE or rect.position.y < -EDGE_TOLERANCE or rect.end.x > view.x + EDGE_TOLERANCE or rect.end.y > view.y + EDGE_TOLERANCE):
					outside.append(tag)
				if not in_scroll:
					var key := str(rect)
					if seen.has(key):
						stacked.append("%s ~ %s" % [str(seen[key]),tag])
					else:
						seen[key] = tag
		for child in node.get_children():
			stack.append(child)
	return {"narrow":narrow,"outside":outside,"stacked":stacked}

## Human-readable summary for an assertion label, capped so a label never becomes a wall of text.
static func describe(report: Dictionary, key: String, limit: int = 3) -> String:
	var values: Array = report.get(key,[])
	if values.is_empty():
		return "none"
	var head: Array = values.slice(0,limit)
	return "%d: %s" % [values.size(),", ".join(head.map(func(value: Variant) -> String: return str(value)))]
