class_name DisplaySettings
extends Node
## A preview never changes the persisted preference until it is confirmed.
signal finished(accepted: bool, error: String)
var active := false
var remaining := 0.0
var previous: Dictionary = {}
var candidate: Dictionary = {}

func _ready() -> void: process_mode = Node.PROCESS_MODE_ALWAYS

static func current() -> Dictionary:
	return {"mode":DisplayServer.window_get_mode(),"size":DisplayServer.window_get_size(),"position":DisplayServer.window_get_position()}

static func apply_preference(value: Dictionary) -> void:
	if DisplayServer.get_name()=="headless": return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(int(value.width),int(value.height)))
	if value.mode=="fullscreen": DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

static func apply_startup() -> void:
	for argument in OS.get_cmdline_args():
		if argument in ["--fullscreen","-f","--windowed","-w","--resolution","--maximized","-m","--position"]: return
	apply_preference(InputBindingService.display)

func begin(value: Dictionary) -> bool:
	if active or not InputBindingService.valid_display(value): return false
	previous = current(); candidate = value.duplicate(); remaining = 10.0; active = true
	apply_preference(candidate)
	return true

func confirm() -> void:
	if not active: return
	var old := InputBindingService.display.duplicate()
	InputBindingService.display = candidate.duplicate()
	var error := InputBindingService.save()
	if not error.is_empty():
		InputBindingService.display = old; rollback(error); return
	active = false
	finished.emit(true,"")

func rollback(error: String = "") -> void:
	if not active: return
	active = false
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(previous.size)
		DisplayServer.window_set_position(previous.position)
		DisplayServer.window_set_mode(previous.mode)
	finished.emit(false,error)

func _process(delta: float) -> void:
	if not active: return
	remaining -= delta
	if remaining<=0: rollback()

func _exit_tree() -> void: rollback()
