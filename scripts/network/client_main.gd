extends SceneTree
func _initialize() -> void: call_deferred("start")
func start() -> void:
	var view := NetworkClientView.new()
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): view.port=int(args[0])
	root.add_child(view)
