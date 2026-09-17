class_name VehicleDamageDiagram
extends Control
## Project the actual owner layout into a compact cutaway; no second vehicle/physics scene.
var snapshot: Dictionary = {}
var _remaining := 0.0
var _actor_id := 0
var _scale := 1.0
var _offset := Vector2.ZERO

func _ready() -> void:
	custom_minimum_size=Vector2(300,202)
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func observe(actor: VehicleActor, delta: float) -> void:
	_remaining-=delta
	var identity := actor.get_instance_id() if is_instance_valid(actor) else 0
	if identity==_actor_id and _remaining>0: return
	_actor_id=identity; _remaining=.1
	set_snapshot(VehicleDamageView.sample(actor))

func set_snapshot(value: Dictionary) -> void:
	snapshot=value
	queue_redraw()

static func project(point: Vector3) -> Vector2:
	return Vector2(.82*point.x-.57*point.z,.30*point.x+.43*point.z-.85*point.y)

func screen(point: Vector3) -> Vector2: return project(point)*_scale+_offset

func _text(position: Vector2, text: String, color: Color, font_size: int = 12) -> void:
	draw_string(get_theme_default_font(),position,text,HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(font_size*AccessibilitySettings.ui_scale),color)

func _draw() -> void:
	var muted := Color("90a3ad")
	_text(Vector2(0,13),LocalizationService.text("damage_cutaway_title"),muted,12)
	draw_line(Vector2(0,21),Vector2(size.x,21),Color("32464f"),1)
	if snapshot.is_empty():
		_text(Vector2(12,74),LocalizationService.text("damage_cutaway_missing"),muted,14)
		return
	var points := PackedVector2Array()
	for polygon in snapshot.shell:
		for point in polygon: points.append(project(point))
	for item in snapshot.items:
		for point in item.points: points.append(project(point))
	points.append(project(snapshot.gun_base)); points.append(project(snapshot.muzzle))
	if points.is_empty(): return
	var bounds := Rect2(points[0],Vector2.ZERO)
	for p in points: bounds=bounds.expand(p)
	var canvas := Rect2(14,28,size.x-28,size.y-77)
	_scale=minf(canvas.size.x/maxf(.1,bounds.size.x),canvas.size.y/maxf(.1,bounds.size.y))
	_offset=canvas.get_center()-bounds.get_center()*_scale
	# Ghost armor surfaces establish the real hull/turret silhouette without hiding internals.
	for polygon in snapshot.shell:
		var projected := PackedVector2Array()
		for p in polygon: projected.append(screen(p))
		if projected.size()<3: continue
		projected.append(projected[0])
		draw_polyline(projected,Color(.49,.64,.69,.23),1,true)
	var faces: Array=[]
	for item in snapshot.items:
		for face in VehicleDamageView.BOX_FACES:
			var vertices := PackedVector2Array(); var depth := 0.0
			for index in face:
				var p: Vector3=item.points[index]
				vertices.append(screen(p)); depth+=p.dot(Vector3(.48,.70,.68))
			faces.append({"vertices":vertices,"depth":depth/4,"item":item})
	faces.sort_custom(func(a: Dictionary,b: Dictionary)->bool: return a.depth<b.depth)
	for face in faces:
		var item: Dictionary=face.item
		var color: Color=VehicleDamageView.COLORS[item.condition]
		color.a=.70 if item.condition in ["intact","crew"] else .94
		if item.empty or item.condition=="vacant": color.a=.13
		if Geometry2D.triangulate_polygon(face.vertices).is_empty(): continue
		draw_colored_polygon(face.vertices,color)
		var edge: PackedVector2Array=face.vertices.duplicate(); edge.append(edge[0])
		var outline := Color("f06759") if item.condition=="disabled" else Color(color.lightened(.2),.75)
		draw_polyline(edge,outline,1,true)
	draw_line(screen(snapshot.gun_base),screen(snapshot.muzzle),Color("a2bbc0"),2,true)
	for item in snapshot.items:
		var center := screen(item.center)
		if item.condition=="disabled":
			draw_line(center-Vector2(3,3),center+Vector2(3,3),Color("ff7365"),1.5,true)
			draw_line(center-Vector2(3,-3),center+Vector2(3,-3),Color("ff7365"),1.5,true)
		elif item.crew:
			draw_circle(center,2,Color("e0f6ec"))
		if item.burning: _text(center+Vector2(5,-3),LocalizationService.text("damage_cutaway_fire"),Color("ff984d"),13)
		if item.repairing: draw_arc(center,7,0,TAU,18,Color("7ad2eb"),1.5,true)
	var keys := ["intact","light","heavy","critical","disabled"]
	for i in keys.size():
		var x := float(i)*size.x/5
		draw_rect(Rect2(x,size.y-28,7,7),VehicleDamageView.COLORS[keys[i]])
		if keys[i]=="disabled": draw_rect(Rect2(x,size.y-28,7,7),Color("f06759"),false,1)
		_text(Vector2(x+10,size.y-21),LocalizationService.text("damage_cutaway_"+keys[i]),muted,11)
	_text(Vector2(0,size.y-3),LocalizationService.text("damage_cutaway_legend"),muted,11)
	if snapshot.destroyed: _text(Vector2(size.x-65,13),LocalizationService.text("damage_cutaway_destroyed"),Color("ff7365"),12)
