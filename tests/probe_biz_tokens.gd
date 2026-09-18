extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	print("original_source=",UiTokens.source()," overlay_source=",UiTokens.biz_source())
	print("accent=",UiTokens.color("accent","#E0B46A").to_html(false)," sunken=",UiTokens.biz_color("surface_sunken","#131C21").to_html(false)," scrim=",UiTokens.biz_color("scrim","#0B1013CC").to_html(true))
	print("elev panel=",UiTokens.biz_elevation("panel")," motion page=",UiTokens.biz_motion("page_ms",160.0)," type display_l=",UiTokens.biz_type_size("display_l",34))
	print("icons: original=",BizTheme.icon_texture("ammo",20)!=null," added=",BizTheme.icon_texture("crew",20)!=null," missing=",BizTheme.icon_texture("no_such_key",16)==null)
	print("PROBE_DONE")
	quit(0)