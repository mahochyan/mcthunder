class_name SightGraduations
extends Control
## Angular graduations in milliradians, projected through the actual sight FOV.
var camera_rig: CameraRig

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(_delta: float) -> void:
	visible=is_instance_valid(camera_rig) and is_instance_valid(camera_rig.cam) and camera_rig.cam.current and (camera_rig.sight or camera_rig.binoculars)
	if visible: queue_redraw()

func pixels_for_mils(mils: float) -> float:
	return size.y*0.5*tan(mils*0.001)/tan(deg_to_rad(camera_rig.cam.fov*0.5))

func _draw() -> void:
	if not visible: return
	var center := size*0.5
	var step := 5 if camera_rig.cam.fov<12 else (10 if camera_rig.cam.fov<22 else 20)
	var ink := Color(0.92,0.96,0.9,0.8)
	for index in range(1,5):
		var mils := index*step
		var offset := pixels_for_mils(mils)
		if offset>minf(size.x,size.y)*0.28: break
		for sign_value in [-1,1]:
			var x := center+Vector2(offset*sign_value,0)
			var y := center+Vector2(0,offset*sign_value)
			draw_line(x-Vector2(0,4),x+Vector2(0,4),ink,1,true)
			draw_line(y-Vector2(4,0),y+Vector2(4,0),ink,1,true)
			if index%2==0:
				draw_string(CoreUI.FONT,x+Vector2(-8,18),str(mils),HORIZONTAL_ALIGNMENT_LEFT,-1,12,ink)
	var text := LocalizationService.text("range_help")
	if camera_rig.fire_control!=null:
		draw_string(CoreUI.FONT,Vector2(maxf(12,center.x-350),size.y-62),camera_rig.fire_control.hud_text(),HORIZONTAL_ALIGNMENT_LEFT,-1,14,ink)
	draw_string(CoreUI.FONT,Vector2(maxf(12,center.x-350),size.y-38),text,HORIZONTAL_ALIGNMENT_LEFT,-1,14,ink)
	draw_string(CoreUI.FONT,center+Vector2(12,-14),"mrad",HORIZONTAL_ALIGNMENT_LEFT,-1,12,ink)
