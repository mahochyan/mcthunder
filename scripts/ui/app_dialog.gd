class_name AppDialog
extends RefCounted
## Shared bounded dialogs for application navigation, with an always reachable exit.
static func show(parent: Node, title: String, body: String, accept_text: String = "", accept: Callable = Callable(), cancel: Callable = Callable()) -> Control:
	var root := Control.new()
	root.name = "ApplicationDialog"
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = CoreUI.theme()
	var dim := ColorRect.new(); dim.color = Color(0.025,0.04,0.05,0.98)
	root.add_child(dim); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new(); root.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,32)
	var box := VBoxContainer.new(); margin.add_child(box)
	CoreUI.label(box,title,26)
	var text := RichTextLabel.new()
	text.name = "DialogBody"
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.selection_enabled = true; text.focus_mode = Control.FOCUS_ALL
	text.text = body
	box.add_child(text)
	var footer := HBoxContainer.new(); box.add_child(footer)
	var dismiss := func() -> void:
		root.queue_free()
		if cancel.is_valid(): cancel.call()
	CoreUI.button(footer,LocalizationService.text("menu_back"),dismiss)
	if accept.is_valid(): CoreUI.button(footer,accept_text,func() -> void: root.queue_free(); accept.call())
	ModalNavigation.attach(root,dismiss)
	return root
