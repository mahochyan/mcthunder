extends "res://tests/run_bound_model_package_checks.gd"
const CompositeFixture=preload("res://tests/fixtures/composite_profile.gd")

func fixture_asset(packet: Dictionary, unit: float, include_tube: bool = true) -> Dictionary:
	# Export base skin first: the supplementary meshes must be installed by the runtime.
	var registry := super.fixture_asset(packet,unit,include_tube)
	packet.sources.fixture.artifact="res://tests/run_composite_binding_checks.gd"
	packet.sources.fixture.sha256=FileAccess.get_sha256(packet.sources.fixture.artifact)
	packet.armor_layers=[]
	for part in ["hull","turret","barrel"]:
		var sheet := CompositeFixture.sheet("attached_"+part,3.5)
		sheet.part=part; packet.armor_layers.append(sheet)
		var claim := _claim(sheet.duplicate(true),"structured"); claim.location="fixture_asset(): explicit composite supplement based on tests/fixtures/composite_profile.gd"
		packet.facts["protection.layer."+str(sheet.id)]=claim
	return registry

func capture_bound(actor: VehicleActor, unit: float) -> void:
	var layout: VehicleLayoutDefinition=actor.damage_layout_override
	var original := actor.turret.rotation
	actor.turret.rotation.y=0.6
	var snapshot := QuerySnapshotBuilder.build_from_vehicle(actor.tank,layout)
	for part in ["hull","turret","barrel"]:
		var parent := DamageTrainingLayout.part_node(actor,part)
		var mesh := parent.get_node_or_null("Protection_attached_"+part) as MeshInstance3D
		check(mesh!=null and mesh.layers==actor.tank.visual_layer,"bound model installs visible supplementary "+part+" on actual gameplay frame")
		if mesh==null: continue
		var vertices: PackedVector3Array=mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var expected: Vector3=snapshot.part_world_transforms[part]*Vector3(-0.8,0.8,3.5)
		check((mesh.global_transform*vertices[0]).distance_to(expected)<0.001,"rotated supplementary layer render/query coordinates agree without double unit conversion: "+part)
		check(mesh.scale==Vector3.ONE and vertices.size()==4,"supplement remains authored metres on "+str(unit)+" source scale")
	actor.turret.rotation=original
	await super.capture_bound(actor,unit)
