class_name RiverJunctionAtlas
extends Control
signal point_selected(point: Vector2)
var team_size := 16
var camera_xz := Vector2.ZERO
var objective_states: Dictionary = {}
var route := PackedVector2Array()

func _ready() -> void:
	custom_minimum_size=Vector2(240,210); mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND

func project(p: Vector2) -> Vector2:
	return (p-RiverJunctionDefinition.WORLD.position)/RiverJunctionDefinition.WORLD.size*size

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("29372f"))
	for x in range(-1200,1201,200): draw_line(project(Vector2(x,-1000)),project(Vector2(x,1000)),Color("36473b"))
	for z in range(-1000,1001,200): draw_line(project(Vector2(-1200,z)),project(Vector2(1200,z)),Color("36473b"))
	var river := PackedVector2Array()
	for x in range(-1200,1201,20): river.append(project(Vector2(x,RiverJunctionDefinition.river_z(x))))
	draw_polyline(river,Color("5b8f98"),4,true)
	for line in RiverJunctionDefinition.road_lines():
		var points := PackedVector2Array()
		for p in line: points.append(project(p))
		draw_polyline(points,Color("778372"),1,true)
	var config := RiverJunctionDefinition.layout(team_size)
	var bounds: Rect2=config.bounds
	draw_rect(Rect2(project(bounds.position),bounds.size/RiverJunctionDefinition.WORLD.size*size),Color("bfad74"),false,2)
	if route.size()>1:
		var route_pixels := PackedVector2Array()
		for p in route: route_pixels.append(project(p))
		draw_polyline(route_pixels,Color("f2d18b"),2,true)
	for id in config.objectives:
		var p := project(RiverJunctionDefinition.OBJECTIVES[id].xz)
		var color: Color=RiverObjectiveHUD.COLORS[int(objective_states.get(id,{}).get("owner",0))]
		draw_circle(p,8,color); draw_string(ThemeDB.fallback_font,p+Vector2(-4,4),id,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("172425"))
		if objective_states.get(id,{}).get("contested",false): draw_arc(p,10,0,TAU,20,Color("eac76b"),2,true)
	for team in [1,2]:
		for pose in RiverJunctionDefinition.spawns(team_size,team):
			draw_circle(project(Vector2(pose.origin.x,pose.origin.z)),2,Color("85bfd2") if team==1 else Color("d99572"))
	draw_circle(project(camera_xz),4,Color.WHITE)
	draw_string(ThemeDB.fallback_font,Vector2(8,16),"N ↑",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("d9ddce"))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		point_selected.emit(event.position/size*RiverJunctionDefinition.WORLD.size+RiverJunctionDefinition.WORLD.position); accept_event()
