class_name ArmorTrainingTargets
extends RefCounted
## Concrete zero-thickness logical plates shared by training and scene tests.
## Dimensions/armor are explicitly designed fixtures, never historical claims.
const CASES := [
	{"title": "THIN PLATE", "thickness": 40.0, "angle": 0.0, "layers": 1},
	{"title": "THICK PLATE", "thickness": 80.0, "angle": 0.0, "layers": 1},
	{"title": "SLOPED PLATE", "thickness": 40.0, "angle": 60.0, "layers": 1},
	{"title": "TWO PLATES", "thickness": 40.0, "angle": 0.0, "layers": 2},
	{"title": "RICOCHET", "thickness": 40.0, "angle": 78.0, "layers": 1},
	{"title": "UNKNOWN ARMOR", "thickness": -1.0, "angle": 0.0, "layers": 1},
]

static func build(plates: Array, entity: String = "armor_target", life: int = 1) -> Dictionary:
	var layout := VehicleLayoutDefinition.new()
	layout.id = "test_armor_plates"
	layout.content_tier = "test"
	var part := LayoutPartDefinition.new()
	part.id = "hull"
	layout.parts.append(part)
	for i in plates.size():
		var spec: Dictionary = plates[i]
		var p := ArmorPatchDefinition.new()
		p.id = str(spec.get("id", "plate_%d" % i))
		p.part_id = "hull"
		var b := Basis(Vector3.UP, deg_to_rad(float(spec.get("angle", 0.0))))
		var center: Vector3 = spec.get("center", Vector3(0, 2.5, -30 - i))
		for v in [Vector3(-4,-2.5,0), Vector3(4,-2.5,0), Vector3(4,2.5,0), Vector3(-4,2.5,0)]:
			p.vertices_local_m.append(b * v + center)
		p.triangles = PackedInt32Array([0,1,2,0,2,3])
		p.outward_normal_local = b * Vector3.BACK
		p.has_thickness = float(spec.get("thickness", -1.0)) >= 0.0
		p.thickness_mm = maxf(0, float(spec.get("thickness", 0.0)))
		p.thickness_status = "estimated" if p.has_thickness else "unknown"
		p.material_kind = "test_steel"
		layout.armor_patches.append(p)
	return QuerySnapshotBuilder.build_identity_snapshot(entity, life, "TEST ONLY", layout, {"hull": Transform3D.IDENTITY})

static func training_case(index: int, life: int) -> Dictionary:
	var c: Dictionary = CASES[index]
	var plates: Array = []
	for i in int(c.layers):
		plates.append({"thickness": c.thickness, "angle": c.angle, "center": Vector3(0, 2.5, -30.0 - i * 1.0)})
	return build(plates, "armor_target", life)
