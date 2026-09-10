class_name ModalNavigation
extends Node
## Keeps keyboard focus inside a visible modal and preserves a fixed Esc exit.
var close_action: Callable
var capture_guard: Callable
var previous_focus: WeakRef
var container: Control
var shown_order := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("modal_navigation")
	container = get_parent() as Control
	container.visibility_changed.connect(_visibility_changed)
	_visibility_changed()

func _visibility_changed() -> void:
	if container.is_visible_in_tree():
		shown_order = int(get_tree().get_meta("modal_navigation_order",0))+1
		get_tree().set_meta("modal_navigation_order",shown_order)
		var focused := get_viewport().gui_get_focus_owner()
		if focused != null and not container.is_ancestor_of(focused): previous_focus = weakref(focused)
		call_deferred("focus_first")
	else:
		_restore_focus()

func controls(root: Node, output: Array[Control]) -> void:
	for child in root.get_children():
		if child is Control:
			if not child.is_visible_in_tree(): continue
			if child.focus_mode == Control.FOCUS_ALL and not (child is BaseButton and child.disabled): output.append(child)
		controls(child,output)

func focus_first() -> void:
	if not _is_top_modal(): return
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and container.is_ancestor_of(focused): return
	var choices: Array[Control] = []
	controls(container,choices)
	if not choices.is_empty(): choices[0].grab_focus()

func _input(event: InputEvent) -> void:
	if not _is_top_modal(): return
	if capture_guard.is_valid() and capture_guard.call(): return
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE and close_action.is_valid():
		get_viewport().set_input_as_handled()
		close_action.call()
	elif event.keycode == KEY_TAB:
		var choices: Array[Control] = []
		controls(container,choices)
		if choices.is_empty(): return
		var current := choices.find(get_viewport().gui_get_focus_owner())
		var step := -1 if event.shift_pressed else 1
		choices[posmod(current+step,choices.size())].grab_focus()
		get_viewport().set_input_as_handled()

func _is_top_modal() -> bool:
	if not is_instance_valid(container) or not container.is_visible_in_tree() or container.is_queued_for_deletion(): return false
	for node in get_tree().get_nodes_in_group("modal_navigation"):
		var candidate := node as ModalNavigation
		if candidate.shown_order > shown_order and is_instance_valid(candidate.container) and candidate.container.is_visible_in_tree() and not candidate.container.is_queued_for_deletion(): return false
	return true

func _restore_focus() -> void:
	if previous_focus == null: return
	var previous := previous_focus.get_ref() as Control
	if previous != null and previous.is_inside_tree() and previous.is_visible_in_tree(): previous.call_deferred("grab_focus")
	previous_focus = null

func _exit_tree() -> void:
	_restore_focus()

static func attach(root: Control, close: Callable = Callable(), guard: Callable = Callable()) -> ModalNavigation:
	var navigation := ModalNavigation.new()
	navigation.close_action = close
	navigation.capture_guard = guard
	root.add_child(navigation)
	return navigation
