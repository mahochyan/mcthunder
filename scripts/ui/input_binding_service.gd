class_name InputBindingService
extends RefCounted
## One binding per semantic action. Esc is reserved for navigation everywhere.
const PATH := "user://settings/input027.json"
const ACTIONS := {
	"move_forward": ["前进", KEY_W, "all"], "move_back": ["后退", KEY_S, "all"],
	"turn_left": ["车体左转", KEY_A, "all"], "turn_right": ["车体右转", KEY_D, "all"],
	"fire": ["开火", -MOUSE_BUTTON_LEFT, "all"], "aim": ["炮镜", -MOUSE_BUTTON_RIGHT, "all"],
	"pause": ["暂停", KEY_ESCAPE, "all"], "reset": ["重开训练", KEY_R, "training"],
	"repair": ["维修", KEY_T, "combat"], "extinguish": ["灭火", KEY_F, "combat"],
	"replace_crew": ["乘员替补", KEY_C, "combat"], "cancel_recovery": ["取消恢复动作", KEY_G, "combat"],
	"shell_1": ["选择第一弹种", KEY_1, "combat"], "shell_2": ["选择第二弹种", KEY_2, "combat"],
	"toggle_target": ["切换训练射道", KEY_T, "range"],
	"scoreboard": ["战况", KEY_TAB, "combat"],
	"spectate_previous": ["观察上一友军", KEY_Q, "combat"], "spectate_next": ["观察下一友军", KEY_E, "combat"],
	"replay_toggle": ["回放开关", KEY_V, "all"], "replay_previous": ["上一条回放", KEY_COMMA, "all"],
	"replay_next": ["下一条回放", KEY_PERIOD, "all"], "replay_step": ["回放单步", KEY_N, "all"],
	"replay_export": ["导出回放记录", KEY_J, "all"]
}
static var initialized := false
static var bindings: Dictionary = {}
static var storage_path := ""
static var problem := ""

static func initialize(path: String = "") -> void:
	if initialized: return
	initialized = true
	storage_path = path
	problem = ""
	restore_defaults(false)
	if path.is_empty() or not FileAccess.file_exists(path): return
	var parser := JSON.new()
	var parsed: Variant = null
	if parser.parse(FileAccess.get_file_as_string(path)) == OK: parsed = parser.data
	if not parsed is Dictionary or parsed.get("schema",0) != 1 or not parsed.get("bindings") is Dictionary:
		problem = "按键设置损坏，已恢复默认。"
		return
	var candidate: Dictionary = parsed.bindings
	if candidate.size() != ACTIONS.size():
		problem = "按键设置不完整，已恢复默认。"
		return
	for action in ACTIONS:
		if not candidate.has(action) or not valid_code(candidate[action],action) or not conflicts(action,int(candidate[action]),candidate).is_empty():
			problem = "按键设置无效或冲突，已恢复默认。"
			return
	bindings = candidate.duplicate()
	_apply_all()
	if parsed.get("accessibility") is Dictionary: AccessibilitySettings.restore(parsed.accessibility)

static func valid_code(code: Variant, action: String) -> bool:
	if not (code is int or code is float) or float(code) != floor(float(code)): return false
	var value := int(code)
	if value == KEY_ESCAPE: return action == "pause"
	if value == KEY_TAB: return action == "scoreboard"
	if value in [KEY_ENTER,KEY_KP_ENTER,KEY_TAB] and action != "scoreboard": return false
	return value in [-1,-2,-3,-8,-9] or (value >= KEY_SPACE and value <= KEY_ASCIITILDE) or (value >= KEY_F1 and value <= KEY_F12)

static func conflicts(action: String, code: int, candidate: Dictionary = {}) -> Array[String]:
	var found: Array[String] = []
	if candidate.is_empty(): candidate = bindings
	if not ACTIONS.has(action): return found
	for other in candidate:
		if other == action or not ACTIONS.has(other) or int(candidate[other]) != code: continue
		var first: String = ACTIONS[action][2]
		var second: String = ACTIONS[other][2]
		if first == second or first == "all" or second == "all" or (first == "training" and second != "range") or (second == "training" and first != "range"):
			found.append(other)
	return found

static func apply_binding(action: String, code: int) -> String:
	if not ACTIONS.has(action) or not valid_code(code,action): return "此按键不可用；Esc和确认键保留给菜单。"
	var collisions := conflicts(action,code)
	if not collisions.is_empty(): return "按键已用于："+str(ACTIONS[collisions[0]][0])
	bindings[action] = code
	_apply_action(action)
	return save()

static func restore_defaults(persist: bool = true) -> void:
	bindings.clear()
	for action in ACTIONS: bindings[action] = int(ACTIONS[action][1])
	_apply_all()
	if persist: save()

static func _apply_all() -> void:
	for action in bindings: _apply_action(action)

static func _apply_action(action: String) -> void:
	if not InputMap.has_action(action): InputMap.add_action(action)
	Input.action_release(action)
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action,event_for(int(bindings[action])))

static func event_for(code: int) -> InputEvent:
	if code < 0:
		var event := InputEventMouseButton.new()
		event.button_index = -code
		return event
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event

static func code_for(event: InputEvent) -> int:
	if event is InputEventMouseButton: return -event.button_index
	if event is InputEventKey and not (event.ctrl_pressed or event.alt_pressed or event.meta_pressed or event.shift_pressed):
		return event.physical_keycode if event.physical_keycode != 0 else event.keycode
	return 0

static func hint(action: String) -> String:
	var code := int(bindings.get(action,ACTIONS.get(action,["",0])[1]))
	if code < 0: return {-1:"鼠标左键",-2:"鼠标右键",-3:"鼠标中键",-8:"鼠标侧键1",-9:"鼠标侧键2"}.get(code,"鼠标键")
	return OS.get_keycode_string(code)

static func is_pause(event: InputEvent) -> bool:
	return event.is_action_pressed("pause") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE)

static func driving_hint() -> String:
	return "%s/%s 驾驶 · %s/%s 转向 · %s 炮镜 · %s 开火"%[hint("move_forward"),hint("move_back"),hint("turn_left"),hint("turn_right"),hint("aim"),hint("fire")]

static func recovery_hint() -> String:
	return "%s 维修 · %s 灭火 · %s 替补 · %s 取消"%[hint("repair"),hint("extinguish"),hint("replace_crew"),hint("cancel_recovery")]

static func save() -> String:
	if storage_path.is_empty(): return ""
	var error := DirAccess.make_dir_recursive_absolute(storage_path.get_base_dir())
	if error != OK: return "无法创建设置目录；本次改绑仅在当前会话有效。"
	var temporary := storage_path+".tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null: return "无法保存按键设置；本次改绑仅在当前会话有效。"
	file.store_string(JSON.stringify({"schema":1,"bindings":bindings,"accessibility":AccessibilitySettings.snapshot()}))
	file.close()
	if DirAccess.rename_absolute(temporary,storage_path) != OK: return "无法替换按键设置；本次改绑仅在当前会话有效。"
	return ""
