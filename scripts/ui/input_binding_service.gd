class_name InputBindingService
extends RefCounted
## One binding per semantic action. Esc is reserved for navigation everywhere.
const PATH := "user://settings/input027.json"
static var ACTIONS := {
	"free_look": [LocalizationService.text("free_look"), KEY_B, "all"],
	"binoculars": [LocalizationService.text("optics_binoculars"), KEY_L, "all"],
	"optic_zoom": [LocalizationService.text("optics_zoom"), KEY_Z, "all"],
	"rangefinder": [LocalizationService.text("range_action_measure"), KEY_Y, "all"],
	"apply_range": [LocalizationService.text("range_action_apply"), KEY_H, "all"],
	"zeroing_up": [LocalizationService.text("range_action_up"), KEY_BRACKETRIGHT, "all"],
	"zeroing_down": [LocalizationService.text("range_action_down"), KEY_BRACKETLEFT, "all"],
	"move_forward": [LocalizationService.text("ui_d681c6e2947a"), KEY_W, "all"], "move_back": [LocalizationService.text("ui_2d1d8c1e3895"), KEY_S, "all"],
	"turn_left": [LocalizationService.text("ui_0e9a81204e7d"), KEY_A, "all"], "turn_right": [LocalizationService.text("ui_b61b251950a2"), KEY_D, "all"],
	"fire": [LocalizationService.text("ui_b0c797f7ef9a"), -MOUSE_BUTTON_LEFT, "all"], "aim": [LocalizationService.text("ui_6630e2fefc78"), -MOUSE_BUTTON_RIGHT, "all"],
	"pause": [LocalizationService.text("ui_8d12fc0d4eb2"), KEY_ESCAPE, "all"], "reset": [LocalizationService.text("ui_4f8ab1687891"), KEY_R, "training"],
	"repair": [LocalizationService.text("ui_fede1630f0f8"), KEY_T, "recovery"], "extinguish": [LocalizationService.text("ui_e00a264128bd"), KEY_F, "recovery"],
	"replace_crew": [LocalizationService.text("ui_cd350baf5c61"), KEY_C, "recovery"], "cancel_recovery": [LocalizationService.text("ui_d52a1bfa5f30"), KEY_G, "recovery"],
	"shell_1": [LocalizationService.text("ui_53cbca1a701a"), KEY_1, "shell"], "shell_2": [LocalizationService.text("ui_dfdb963b2395"), KEY_2, "shell"],
	"cycle_shell": [LocalizationService.text("shell_cycle_action"), KEY_M, "shell"],
	"toggle_target": [LocalizationService.text("ui_a59c105384d2"), KEY_T, "range"],
	"scoreboard": [LocalizationService.text("ui_460a00f80c93"), KEY_TAB, "combat"],
	"spectate_previous": [LocalizationService.text("ui_f1e4b95d6143"), KEY_Q, "combat"], "spectate_next": [LocalizationService.text("ui_600d90cea973"), KEY_E, "combat"],
	"replay_toggle": [LocalizationService.text("ui_6edeb17fc538"), KEY_V, "all"], "replay_previous": [LocalizationService.text("ui_df19e1bbbac4"), KEY_COMMA, "all"],
	"replay_next": [LocalizationService.text("ui_fb446291d6b9"), KEY_PERIOD, "all"], "replay_step": [LocalizationService.text("ui_0b1a89d3c560"), KEY_N, "all"],
	"replay_export": [LocalizationService.text("ui_99937ab2f159"), KEY_J, "all"],
	"switch_control": [LocalizationService.text("ui_1be4cd684efb"),KEY_TAB,"lab"], "xray": [LocalizationService.text("ui_592cb4b101fa"),KEY_X,"lab"],
	"path_toggle": [LocalizationService.text("ui_52e7afde472d"),KEY_P,"ai_drive"], "lesson_result": [LocalizationService.text("ui_91aa1e51a313"),KEY_ENTER,"core"],
	"scenario_1": [LocalizationService.text("ui_479bda0bc417"),KEY_1,"scenario"], "scenario_2": [LocalizationService.text("ui_0c50efb473ce"),KEY_2,"scenario"],
	"scenario_3": [LocalizationService.text("ui_6858d7259eb7"),KEY_3,"scenario"], "scenario_4": [LocalizationService.text("ui_66b838c172ce"),KEY_4,"scenario"],
	"scenario_5": [LocalizationService.text("ui_08d50c49e2bd"),KEY_5,"scenario"], "scenario_6": [LocalizationService.text("ui_29dd1cba0c75"),KEY_6,"scenario"],
	"shell_target_thin": [LocalizationService.text("ui_6b8e8334c30b"),KEY_3,"shell_lab"], "shell_target_thick": [LocalizationService.text("ui_d524ff183512"),KEY_4,"shell_lab"],
	"debug_toggle": [LocalizationService.text("ui_cc17a199f266"),KEY_F3,"training"], "query_debug_toggle": [LocalizationService.text("ui_4ba80a84aa64"),KEY_F6,"training"]
}
const CONTEXTS := {
	"all":["range","armor","damage","recovery","core","terrain","ai_drive","ai_combat","shell","battle","challenge"],
	"training":["range","armor","damage","recovery","core","terrain","ai_drive","ai_combat","shell","challenge"],
	"combat":["battle","challenge"], "recovery":["recovery","core","battle","challenge"],
	"shell":["range","shell","core","battle","challenge"], "range":["range"],
	"lab":["damage","recovery","core","terrain","ai_drive","ai_combat","shell"],
	"scenario":["armor","recovery","terrain","ai_drive","ai_combat"],
	"shell_lab":["shell"], "ai_drive":["ai_drive"], "core":["core"]
}
static var initialized := false
static var context := "all"
static var bindings: Dictionary = {}
static var storage_path := ""
static var problem := ""
static var writable := true
static var display := {"mode":"windowed","width":1280,"height":720}
const DISPLAY_DEFAULT := {"mode":"windowed","width":1280,"height":720}
const RESOLUTIONS := [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)]

static func initialize(path: String = "") -> void:
	if initialized: return
	initialized = true
	storage_path = path
	problem = ""
	writable = true
	display = DISPLAY_DEFAULT.duplicate()
	AccessibilitySettings.restore(AccessibilitySettings.DEFAULTS)
	restore_defaults(false)
	if path.is_empty(): return
	var primary := read_settings(path)
	var backup := read_settings(path+".bak")
	if primary.get("future",false) or backup.get("future",false):
		writable = false; problem = LocalizationService.text("settings_future"); return
	var chosen := primary
	if not primary.ok:
		chosen = backup
		if backup.ok: problem = LocalizationService.text("settings_recovered")
		elif FileAccess.file_exists(path) or FileAccess.file_exists(path+".bak"): problem = LocalizationService.text("settings_corrupt")
	if not chosen.ok: return
	bindings = chosen.data.bindings.duplicate()
	_apply_all()
	AccessibilitySettings.restore(chosen.data.accessibility)
	display = chosen.data.display.duplicate()
	LocalizationService.set_locale(chosen.data.language)

static func valid_display(value: Variant) -> bool:
	if not value is Dictionary or value.size()!=3 or value.get("mode") not in ["windowed","fullscreen"]: return false
	for key in ["width","height"]:
		if not (value.get(key) is int or value.get(key) is float): return false
		if not is_finite(float(value[key])) or float(value[key])!=floor(float(value[key])): return false
	return Vector2i(int(value.width),int(value.height)) in RESOLUTIONS

static func read_settings(path: String) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length()>65536: return {"ok":false}
	var parser := JSON.new()
	if parser.parse(file.get_as_text())!=OK or not parser.data is Dictionary: return {"ok":false}
	var data: Dictionary = parser.data
	var schema: Variant = data.get("schema")
	if (schema is int or schema is float) and schema>2: return {"ok":false,"future":true}
	if not (schema is int or schema is float) or not is_finite(float(schema)) or schema!=floor(float(schema)): return {"ok":false}
	if int(schema) not in [1,2] or not data.get("bindings") is Dictionary: return {"ok":false}
	var allowed := ["schema","bindings","accessibility"] if schema==1 else ["schema","bindings","accessibility","display","language"]
	for key in data:
		if key not in allowed: return {"ok":false}
	if schema==2 and data.size()!=5: return {"ok":false}
	var candidate: Dictionary = data.bindings
	# Older settings retain every existing binding; assign the new action an
	# unused key rather than rejecting the entire settings document.
	for action in candidate:
		if not ACTIONS.has(action) or not valid_code(candidate[action],action): return {"ok":false}
	for action in ["free_look","binoculars","optic_zoom","rangefinder","apply_range","zeroing_up","zeroing_down","cycle_shell"]:
		if candidate.has(action): continue
		for code in [ACTIONS[action][1],KEY_U,KEY_H,KEY_K,KEY_F7,KEY_F8,KEY_F9,KEY_F10,KEY_F11,KEY_F12,KEY_I,KEY_O,KEY_M]:
			if conflicts(action,code,candidate).is_empty():
				candidate[action]=code
				break
	if candidate.size()!=ACTIONS.size(): return {"ok":false}
	# Validate all types before conflict detection (which converts other values).
	for action in ACTIONS:
		if not candidate.has(action) or not valid_code(candidate[action],action): return {"ok":false}
	for action in ACTIONS:
		if not conflicts(action,int(candidate[action]),candidate).is_empty(): return {"ok":false}
	if not AccessibilitySettings.valid(data.get("accessibility",{})): return {"ok":false}
	var options := AccessibilitySettings.DEFAULTS.duplicate(); options.merge(data.get("accessibility",{}),true)
	if schema==2 and (not valid_display(data.display) or data.language!="zh_CN"): return {"ok":false}
	return {"ok":true,"data":{"schema":2,"bindings":candidate,"accessibility":options,"display":data.get("display",DISPLAY_DEFAULT),"language":"zh_CN"}}

static func valid_code(code: Variant, action: String) -> bool:
	if not (code is int or code is float) or not is_finite(float(code)) or float(code) != floor(float(code)): return false
	var value := int(code)
	if value == KEY_ESCAPE: return action == "pause"
	if value == KEY_TAB: return action in ["scoreboard","switch_control"]
	if value in [KEY_ENTER,KEY_KP_ENTER]: return action == "lesson_result"
	return value in [-1,-2,-3,-8,-9] or (value >= KEY_SPACE and value <= KEY_ASCIITILDE) or (value >= KEY_F1 and value <= KEY_F12)

static func conflicts(action: String, code: int, candidate: Dictionary = {}) -> Array[String]:
	var found: Array[String] = []
	if candidate.is_empty(): candidate = bindings
	if not ACTIONS.has(action): return found
	for other in candidate:
		if other == action or not ACTIONS.has(other) or int(candidate[other]) != code: continue
		var first: String = ACTIONS[action][2]
		var second: String = ACTIONS[other][2]
		for candidate_context in CONTEXTS[first]:
			if candidate_context in CONTEXTS[second]:
				found.append(other)
				break
	return found

static func apply_binding(action: String, code: int) -> String:
	if not ACTIONS.has(action) or not valid_code(code,action): return LocalizationService.text("ui_d2f1d7d7ba13")
	var collisions := conflicts(action,code)
	if not collisions.is_empty(): return LocalizationService.text("ui_11ba610487e0")+str(ACTIONS[collisions[0]][0])
	var old: int = int(bindings[action])
	bindings[action] = code
	_apply_action(action)
	var error := save()
	if not error.is_empty(): bindings[action] = old; _apply_action(action)
	return error

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
	if context == "all" or context in CONTEXTS[ACTIONS[action][2]] or action == "pause":
		InputMap.action_add_event(action,event_for(int(bindings[action])))

static func set_context(value: String) -> void:
	initialize()
	if context == value: return
	context = value
	_apply_all()

static func scenario_index(event: InputEvent, count: int) -> int:
	for index in mini(count,6):
		if event.is_action_pressed("scenario_%d"%(index+1)): return index
	return -1

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
	if code==KEY_BRACKETLEFT: return "["
	if code==KEY_BRACKETRIGHT: return "]"
	if code < 0: return {-1:LocalizationService.text("ui_2c3c432593de"),-2:LocalizationService.text("ui_12b284d44fff"),-3:LocalizationService.text("ui_43645a86c3b9"),-8:LocalizationService.text("ui_01e583b6d76e"),-9:LocalizationService.text("ui_98ff73996ef7")}.get(code,LocalizationService.text("ui_848955060aa6"))
	return OS.get_keycode_string(code)

static func is_pause(event: InputEvent) -> bool:
	return event.is_action_pressed("pause") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE)

static func driving_hint() -> String:
	return LocalizationService.text("ui_5b792efcb19e")%[hint("move_forward"),hint("move_back"),hint("turn_left"),hint("turn_right"),hint("aim"),hint("fire")]+LocalizationService.text("free_look_hint")

static func recovery_hint() -> String:
	return LocalizationService.text("ui_2c2417b68269")%[hint("repair"),hint("extinguish"),hint("replace_crew"),hint("cancel_recovery")]

static func save() -> String:
	if storage_path.is_empty(): return ""
	if not writable: return LocalizationService.text("settings_future")
	var error := DirAccess.make_dir_recursive_absolute(storage_path.get_base_dir())
	if error != OK: return LocalizationService.text("ui_bc624eb41ffc")
	var lock := storage_path+".lock"
	if DirAccess.make_dir_absolute(lock)!=OK: return LocalizationService.text("settings_locked")
	var result := _save_locked()
	DirAccess.remove_absolute(lock)
	return result

static func _save_locked() -> String:
	var primary := read_settings(storage_path)
	var backup := read_settings(storage_path+".bak")
	if primary.get("future",false) or backup.get("future",false):
		writable = false; return LocalizationService.text("settings_future")
	var temporary := storage_path+".tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null: return LocalizationService.text("ui_c56d11764c0f")
	var value := {"schema":2,"bindings":bindings,"accessibility":AccessibilitySettings.snapshot(),"display":display,"language":LocalizationService.locale}
	var serialized := JSON.stringify(value)
	file.store_string(serialized); file.flush()
	var write_error := file.get_error()
	file.close()
	var verified := read_settings(temporary)
	if write_error!=OK or not verified.ok or FileAccess.get_file_as_string(temporary)!=serialized: return LocalizationService.text("settings_verify_failed")
	if primary.ok:
		var backup_tmp := storage_path+".bak.tmp"
		if not _copy_verified(storage_path,backup_tmp) or not read_settings(backup_tmp).ok: return LocalizationService.text("settings_backup_failed")
		if DirAccess.rename_absolute(backup_tmp,storage_path+".bak")!=OK: return LocalizationService.text("settings_backup_failed")
	elif FileAccess.file_exists(storage_path):
		# Preserve the exact broken bytes before a successful replacement, never load them as a resource.
		var preserved := storage_path+".corrupt-"+str(Time.get_unix_time_from_system()).replace(".","-")+"-"+str(Time.get_ticks_usec())
		if not _copy_verified(storage_path,preserved): return LocalizationService.text("settings_backup_failed")
	if DirAccess.rename_absolute(temporary,storage_path) != OK: return LocalizationService.text("ui_f518e3106f33")
	problem = ""
	return ""

static func _copy_verified(source: String, target: String) -> bool:
	# FileAccess failures return an error without logging private absolute paths.
	var input := FileAccess.open(source,FileAccess.READ)
	if input==null: return false
	var output := FileAccess.open(target,FileAccess.WRITE)
	if output==null: return false
	while input.get_position()<input.get_length():
		output.store_buffer(input.get_buffer(mini(65536,input.get_length()-input.get_position())))
	output.flush()
	var error := output.get_error(); input.close(); output.close()
	return error==OK and FileAccess.get_sha256(source)==FileAccess.get_sha256(target)

static func reset_settings() -> String:
	var old_bindings := bindings.duplicate(); var old_options := AccessibilitySettings.snapshot(); var old_display := display.duplicate()
	restore_defaults(false); AccessibilitySettings.restore(AccessibilitySettings.DEFAULTS); display = DISPLAY_DEFAULT.duplicate()
	var error := save()
	if not error.is_empty():
		bindings = old_bindings; _apply_all(); AccessibilitySettings.restore(old_options); display = old_display
	return error
