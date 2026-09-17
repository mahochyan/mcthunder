class_name RiverCaptureMarkers
extends RefCounted
## Visual-only footprint of the same three zones used by capture rules.
static func build(parent: Node3D) -> Dictionary:
	var materials := {}
	for row in RiverJunctionDefinition.capture_definitions():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in 128:
			var corners: Array[Vector3] = []
			for pair in [[i,row.radius-.65],[i+1,row.radius-.65],[i+1,row.radius+.65],[i,row.radius+.65]]:
				var angle: float = float(pair[0])*TAU/128
				var p := Vector2(row.center.x,row.center.z)+Vector2(cos(angle),sin(angle))*float(pair[1])
				corners.append(RiverJunctionDefinition.point(p,.20))
			for index in [0,1,2,0,2,3]: st.add_vertex(corners[index])
		st.generate_normals()
		var mesh := MeshInstance3D.new()
		mesh.mesh = st.commit()
		mesh.name = "CaptureZone_"+row.id
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_color = RiverObjectiveHUD.COLORS[0]
		mesh.material_override = mat
		parent.add_child(mesh)
		materials[row.id] = mat
		var label := Label3D.new()
		label.name = "CaptureLabel_"+row.id
		label.text = str(row.id)
		label.font = CoreUI.FONT
		label.font_size = 80
		label.pixel_size = .03
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = row.center+Vector3.UP*5
		parent.add_child(label)
	return materials
