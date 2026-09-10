extends SceneTree
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1: quit(2); return
	var file := FileAccess.open(args[0],FileAccess.WRITE)
	if file==null: quit(1); return
	file.store_string(Engine.get_license_text()+"\n\n"+JSON.stringify(Engine.get_copyright_info(),"  ")+"\n\n"+JSON.stringify(Engine.get_license_info(),"  "))
	file.flush(); var error := file.get_error(); file.close()
	quit(0 if error==OK else 1)
