class_name LocalizationService
extends RefCounted
## Text-only service. No dependency on scenes, controls or simulation state.
const RESOURCE := "res://assets/localization/zh_CN.json"
static var locale := "zh_CN"
static var _strings: Dictionary = {}
static var missing: Dictionary = {}

static func ensure_loaded() -> void:
	if not _strings.is_empty(): return
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(RESOURCE)) == OK and parser.data is Dictionary:
		_strings = parser.data
	else:
		push_error("Localization resource unavailable: "+RESOURCE)

static func set_locale(value: String) -> void:
	# This release ships Simplified Chinese. Other locale requests safely fall back.
	locale = "zh_CN"
	if value in ["zh","zh_CN","zh_Hans"]: locale = "zh_CN"
	ensure_loaded()

static func text(key: String) -> String:
	ensure_loaded()
	if _strings.has(key):
		var value := str(_strings[key])
		var start := value.find("{key:")
		while start >= 0:
			var end := value.find("}",start)
			if end < 0: break
			var action := value.substr(start+5,end-start-5)
			value = value.substr(0,start)+InputBindingService.hint(action)+value.substr(end+1)
			start = value.find("{key:",start)
		return value
	missing[key] = true
	return "["+key+"]"

static func all_strings() -> Dictionary:
	ensure_loaded()
	return _strings.duplicate()

static func status(value: String) -> String:
	ensure_loaded()
	return str(_strings.get("status_"+value,value))
