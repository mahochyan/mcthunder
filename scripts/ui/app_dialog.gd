class_name AppDialog
extends RefCounted
## Shared bounded dialogs for application navigation, with an always reachable exit.
##
## UI-BIZ-01 stage 3: the dialog is now a real modal card - a scrim derived from the background token, a panel at the
## overlay's modal elevation, the title in the display type scale and the actions from the shared component layer -
## instead of bare text on a flat dim. The optional accept_kind lets a destructive confirmation mark its own button,
## which the danger colour is reserved for; everything else keeps the same signature it always had.

static func show(parent: Node, title: String, body: String, accept_text: String = "", accept: Callable = Callable(), cancel: Callable = Callable(), accept_kind: String = "secondary") -> Control:
	var root := Control.new()
	root.name = "ApplicationDialog"
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = CoreUI.theme()
	var dim := ColorRect.new()
	dim.color = BizTheme.dialog_scrim()
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new(); root.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,32)
	# The card sits inside the safe margin, which is the modal height rule the token file states, expressed as layout.
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel",BizTheme.dialog_box("danger" if accept_kind == "danger" else "modal"))
	margin.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",12)
	card.add_child(box)
	var heading := BizTheme.display_label(box,title,"display_m")
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var rule := ColorRect.new()
	rule.custom_minimum_size.y = 1
	rule.color = BizTheme.hairline()
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(rule)
	var text := RichTextLabel.new()
	text.name = "DialogBody"
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.selection_enabled = true; text.focus_mode = Control.FOCUS_ALL
	text.text = body
	text.add_theme_color_override("default_color",BizTheme.text_secondary())
	box.add_child(text)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation",10)
	footer.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(footer)
	var dismiss := func() -> void:
		root.queue_free()
		if cancel.is_valid(): cancel.call()
	if accept.is_valid():
		var accept_button := CoreUI.button(footer,accept_text,func() -> void: root.queue_free(); accept.call())
		BizTheme.apply_button(accept_button,accept_kind,"warning" if accept_kind == "danger" else "ready")
	var back_button := CoreUI.button(footer,LocalizationService.text("menu_back"),dismiss)
	BizTheme.apply_button(back_button,"ghost","back")
	ModalNavigation.attach(root,dismiss)
	# A fade-only entrance: modulate only, so nothing measured during it changes, and the reduce-flashes preference
	# skips it.
	BizTheme.fade_in(root,"panel_in_ms")
	return root

## WT-UI-011 (S08): a dangerous confirmation must not start focused on its own confirmation button. The body text is
## focusable so it can be selected and copied, and it would otherwise take the first focus, so the caller wraps its
## call in this helper and the cancel button takes focus instead. Esc keeps meaning "go back".
static func focus_cancel(dialog: Control) -> Control:
	if dialog == null: return dialog
	for button in dialog.find_children("*","Button",true,false):
		if str((button as Button).text)==LocalizationService.text("menu_back"):
			(button as Button).call_deferred("grab_focus")
			break
	return dialog
