extends SceneTree
func _initialize() -> void: call_deferred("start")
func start() -> void:
	var args := OS.get_cmdline_user_args()
	var port := int(args[0]) if not args.is_empty() else 19109
	if port<1024 or port>65535: printerr("Server port must be 1024..65535"); quit(1); return
	var server := NetworkBattleServer.new(); root.add_child(server)
	var error := server.start(port)
	if error!=OK: printerr("Local authority server failed: ",error); quit(1); return
	print("LOCAL_AUTHORITY_READY 127.0.0.1:",port," protocol=1 slots=2")
