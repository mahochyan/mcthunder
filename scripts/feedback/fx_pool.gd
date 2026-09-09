class_name CombatFXPool
extends Node3D
## Fixed allocation. Pure display meshes; no collision or damage callbacks.
const CAPACITY := 12
var slots: Array[Dictionary] = []
var spawned := 0
var peak_active := 0

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_PAUSABLE
	var mesh:=SphereMesh.new(); mesh.radial_segments=4; mesh.rings=1; mesh.radius=0.035; mesh.height=0.07
	var material:=StandardMaterial3D.new(); material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo=true
	for i in CAPACITY:
		var particles:=MultiMeshInstance3D.new(); particles.multimesh=MultiMesh.new()
		particles.multimesh.transform_format=MultiMesh.TRANSFORM_3D; particles.multimesh.use_colors=true
		particles.multimesh.mesh=mesh; particles.multimesh.instance_count=8
		particles.material_override=material; particles.visible=false
		particles.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(particles); slots.append({"mesh":particles,"age":1.0,"kind":"","origin":Vector3.ZERO})

func spawn_bounded(kind: String, point: Vector3) -> void:
	if AccessibilitySettings.fx_level==0 or get_tree().paused: return
	var slot: Dictionary={}
	for row in slots:
		if row.age>=0.5: slot=row; break
	if slot.is_empty(): return
	slot.age=0.0; slot.kind=kind; slot.origin=point; slot.mesh.visible=true; spawned+=1
	peak_active=maxi(peak_active,active_count())

func active_count() -> int:
	var count:=0
	for slot in slots:
		if slot.age<0.5: count+=1
	return count

func clear() -> void:
	for slot in slots: slot.age=1.0; slot.mesh.visible=false

func _process(delta: float) -> void:
	if AccessibilitySettings.fx_level==0: clear(); return
	for slot in slots:
		slot.age+=delta
		var mesh:=slot.mesh as MultiMeshInstance3D
		mesh.visible=slot.age<0.5
		if not mesh.visible: continue
		mesh.global_position=slot.origin
		mesh.multimesh.visible_instance_count=4 if AccessibilitySettings.fx_level==1 else 8
		for i in 8:
			var t: float=slot.age
			var direction:=Vector3(sin(i*2.4),0.5+fmod(i*0.3,1.0),cos(i*2.4))
			var offset:=direction*t*2.8+Vector3.DOWN*t*t*3
			mesh.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,offset))
			mesh.multimesh.set_instance_color(i,Color("c6b58d") if slot.kind=="world" else Color("ffcc75"))
