extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("[PASS] " if ok else "[FAIL] ")+label)

func _initialize() -> void:
	for id in VehicleCatalog.IDS:
		var packet: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://configs/vehicles/historical/"+id+".json"))
		var layout := HistoricalVehicleGeometry.build(packet)
		var model := (load("res://assets/vehicles/"+id+".glb") as PackedScene).instantiate()
		var matched := 0
		for patch in layout.armor_patches:
			var mesh := model.find_child("Armor_"+patch.id,true,false) as MeshInstance3D
			if mesh == null: continue
			var actual: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var same := not actual.is_empty()
			var snapped := PackedVector3Array()
			var max_error := 0.0
			for v in actual:
				var nearest := Vector3.INF
				var distance := INF
				for target in patch.vertices_local_m:
					var error := (mesh.transform*v).distance_to(target)
					if error < distance: distance = error; nearest = target
				max_error = maxf(max_error,distance)
				same = same and distance <= 0.0001 # Godot import position compression: <= 0.1 mm.
				snapped.append(nearest)
			var indices: PackedInt32Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
			same = same and indices.size() == patch.triangles.size()
			var exported_faces: Array[String] = []
			var query_faces: Array[String] = []
			for i in range(0,indices.size(),3): exported_faces.append(face_key(snapped,indices,i))
			for i in range(0,patch.triangles.size(),3): query_faces.append(face_key(patch.vertices_local_m,patch.triangles,i))
			exported_faces.sort(); query_faces.sort()
			same = same and exported_faces == query_faces
			if not same: print("[DETAIL] "+patch.id+" imported="+str(actual.size())+" expected="+str(patch.vertices_local_m.size())+" triangles="+str(indices.size()/3)+"/"+str(patch.triangles.size()/3))
			if same: matched += 1
		check(matched == layout.armor_patches.size(),id+": every exported Blender armor surface matches shot-query topology and vertices within 0.1 mm ("+str(matched)+")")
		var turret := model.find_child("turret",true,false) as Node3D
		var barrel := model.find_child("barrel",true,false) as Node3D
		check(turret.position.distance_to(HistoricalVehicleGeometry.vec(packet.geometry.turret_origin)) < 0.00001 and barrel.position.distance_to(HistoricalVehicleGeometry.vec(packet.geometry.gun_origin)) < 0.00001,id+": imported turret and gun pivots preserve meter coordinates")
		check(model.find_child("gun_recoil",true,false) != null and model.find_child("Cosmetic_hull_Olive",true,false) != null,id+": authored detail and recoil assemblies are present")
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vehicles/"+id+".manifest.json"))
		check(FileAccess.get_sha256("res://assets/vehicles/"+id+".glb") == manifest.glb_sha256 and FileAccess.get_sha256("res://authoring/vehicles/"+id+".blend") == manifest.blend_sha256,id+": manifest identifies delivered GLB and editable Blender source")
		model.free()
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	if failures == 0: print("BLENDER_ASSET_CHECKS_PASS")
	quit(0 if failures == 0 else 1)

func face_key(vertices: PackedVector3Array, indices: PackedInt32Array, offset: int) -> String:
	var points: Array[String] = []
	for i in 3:
		var p := vertices[indices[offset+i]]*10000.0
		points.append("%d,%d,%d"%[roundi(p.x),roundi(p.y),roundi(p.z)])
	points.sort()
	return "|".join(points)
