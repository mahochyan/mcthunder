class_name ChallengeSelection
extends Control
signal chosen(id: String, difficulty: String)
var profile: ProfileStore
var task_choice: OptionButton
var level_choice: OptionButton
var description: Label
var best_label: Label
var start_button: Button
var close_button: Button
func _ready() -> void:
	theme = CoreUI.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new(); dim.color = Color(0.025,0.04,0.05,0.96); add_child(dim); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new(); add_child(center); center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new(); center.add_child(panel)
	var content := VBoxContainer.new(); panel.add_child(content); content.custom_minimum_size.x = 620
	content.add_theme_constant_override("separation",12)
	CoreUI.label(content,"挑战任务",28)
	task_choice = OptionButton.new(); content.add_child(task_choice)
	for id in ChallengeCatalog.IDS: task_choice.add_item(ChallengeCatalog.create(id).title)
	level_choice = OptionButton.new(); content.add_child(level_choice)
	level_choice.add_item("标准"); level_choice.add_item("困难 · 减少配弹 / 时间，交战AI使用困难档")
	description = CoreUI.label(content,"",18); description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(600,220)
	best_label = CoreUI.label(content,"",18)
	start_button = CoreUI.button(content,"开始挑战",func() -> void: chosen.emit(ChallengeCatalog.IDS[task_choice.selected],ChallengeCatalog.LEVELS[level_choice.selected]))
	close_button = CoreUI.button(content,"返回战前准备",queue_free)
	task_choice.item_selected.connect(func(_i: int) -> void: refresh())
	level_choice.item_selected.connect(func(_i: int) -> void: refresh())
	refresh()
func refresh() -> void:
	var c := ChallengeCatalog.create(ChallengeCatalog.IDS[task_choice.selected],ChallengeCatalog.LEVELS[level_choice.selected])
	description.text = ("固定车辆：M36 · " if c.vehicle == ChallengeCatalog.M36 else "固定车辆：M4A3(75)W · ")+MapRegistry.ENTRIES[c.map].title+"\n"+ChallengeCatalog.rules_text(c)
	best_label.text = ChallengeScore.describe_best(profile.snapshot().challenge_bests.get(ChallengeCatalog.key(c),{}))
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		queue_free()
