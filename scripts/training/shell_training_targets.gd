class_name ShellTrainingTargets
extends RefCounted
## Explicit TEST ONLY closed compartment for observable AP/APHE comparisons.
static func build(thickness: float = 20.0, length: float = 4.0, internals: bool = true) -> VehicleLayoutDefinition:
	var layout := VehicleLayoutDefinition.new()
	layout.id = "test_shell_compartment"; layout.content_tier = "test"
	var part := LayoutPartDefinition.new(); part.id = "hull"; layout.parts.append(part)
	var half := Vector3(2,1.5,length*0.5)
	var center := Vector3(0,2,0)
	for normal in [Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN,Vector3.BACK,Vector3.FORWARD]:
		var u := Vector3.UP if absf(normal.y)<0.5 else Vector3.RIGHT
		var v: Vector3 = normal.cross(u)
		var patch := ArmorPatchDefinition.new()
		patch.id = "wall_%d"%layout.armor_patches.size(); patch.part_id = "hull"
		for sign_pair in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
			patch.vertices_local_m.append(center+(normal+u*sign_pair.x+v*sign_pair.y)*half)
		patch.triangles = PackedInt32Array([0,1,2,0,2,3]); patch.outward_normal_local = normal
		patch.has_thickness = thickness>=0; patch.thickness_mm = maxf(0,thickness); patch.thickness_status = "estimated" if thickness>=0 else "unknown"
		layout.armor_patches.append(patch)
	if internals:
		for i in 4:
			var module := ModuleVolumeDefinition.new()
			module.id = "component_%d"%i; module.kind = "turret_drive"; module.part_id = "hull"
			module.local_box_transform.origin = Vector3(-0.65 if i==0 else (0.65 if i==1 else 0.0),2.0+(-0.8 if i==2 else (0.8 if i==3 else 0.0)),0.5)
			module.size_m = Vector3(0.6,1.8,2.0) if i<2 else Vector3(0.7,0.5,2.0)
			layout.modules.append(module)
	return layout
