class_name MinimapPresenter
extends Control
var world_rect := Rect2(-50,-70,100,140)
var obstacles: Array[Rect2] = []
var markers: Array = []
var capture_owner := 0
var has_point := true
var point_position := Vector3.ZERO
var point_radius := 12.0
var high_contrast := false
var map_rect := Rect2()
var _road_segments := PackedVector3Array()
var road_preparations := 0
var roads: Dictionary = {}:
	set(value):
		roads = value.duplicate(true)
		_road_segments.clear()
		road_preparations += 1
		if roads.is_empty(): return
		var nav := DriveNavigator.new()
		if not nav.configure(roads).ok: return
		for edge in roads.edges:
			if not edge.get("road_visual",true): continue
			_road_segments.append(nav.nodes[edge.a])
			_road_segments.append(nav.nodes[edge.b])
func _ready() -> void:
	custom_minimum_size = Vector2(206,206)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func present_observations(intel: Dictionary, point_owner: int) -> void:
	markers = intel.get("markers",[]).duplicate(true)
	capture_owner = point_owner
	queue_redraw()
func project(point: Vector3) -> Vector2:
	return map_rect.position+(Vector2(point.x,point.z)-world_rect.position)/world_rect.size*map_rect.size
func _draw() -> void:
	var scale_factor := minf((size.x-12)/world_rect.size.x,(size.y-12)/world_rect.size.y)
	map_rect = Rect2((size-world_rect.size*scale_factor)/2,world_rect.size*scale_factor)
	draw_rect(map_rect,Color("354738"))
	draw_rect(map_rect,Color("b5c2b3"),false,1)
	for i in range(0,_road_segments.size(),2):
		draw_line(project(_road_segments[i]),project(_road_segments[i+1]),Color("918e70"),2,true)
	for rectangle in obstacles:
		var p := project(Vector3(rectangle.position.x,0,rectangle.position.y))
		draw_rect(Rect2(p,rectangle.size*scale_factor),Color("8b8368"))
	if has_point:
		var center := project(point_position)
		var color: Color = {0:Color("e4dcb0"),1:Color("65c8ff"),2:Color("ffbb6d")}[capture_owner]
		draw_arc(center,point_radius*scale_factor,0,TAU,40,color,2,true)
		draw_string(CoreUI.FONT,center+Vector2(-5,5),"A",HORIZONTAL_ALIGNMENT_LEFT,-1,14,color)
	for marker in markers:
		var point := project(marker.position)
		if not map_rect.has_point(point): continue
		var color := Color("7dd2ff") if marker.kind in ["self","friend"] else Color("ffba76")
		if high_contrast: color = Color.WHITE if marker.kind in ["self","friend"] else Color("ffe135")
		if marker.kind in ["self","friend"]:
			var angle: float = -float(marker.get("heading",0))
			var vertices := PackedVector2Array()
			for v in [Vector2(0,-6),Vector2(4,5),Vector2(-4,5)]: vertices.append(point+v.rotated(angle))
			draw_colored_polygon(vertices,color)
			if marker.kind == "self": draw_arc(point,9,0,TAU,24,Color.WHITE,1.5,true)
		else:
			var vertices := PackedVector2Array([point+Vector2(0,-6),point+Vector2(6,0),point+Vector2(0,6),point+Vector2(-6,0),point+Vector2(0,-6)])
			if marker.kind == "enemy": draw_colored_polygon(vertices,color)
			else:
				draw_polyline(vertices,color,1.5,true)
				draw_string(CoreUI.FONT,point+Vector2(-3,4),"?",HORIZONTAL_ALIGNMENT_LEFT,-1,12,color)
