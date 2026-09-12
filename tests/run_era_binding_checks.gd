extends "res://tests/run_composite_binding_checks.gd"
const EraFixture=preload("res://tests/fixtures/reactive_profile.gd")
const HeatFixture=preload("res://tests/fixtures/chemical_profile.gd")
const SpallFixture=preload("res://tests/fixtures/spall_profile.gd")

func _shell(index: int) -> Dictionary:
	var shell := super._shell(index)
	shell.impact_profile=SpallFixture.profile().fragment_impact_profile
	shell.impact_profile.family=shell.family; shell.impact_profile.normalization_deg=4.0; shell.impact_profile.overmatch_ratio=3.0
	shell.evidence.impact=_claim(shell.impact_profile.duplicate(true),"structured")
	return shell

func fixture_asset(packet: Dictionary, unit: float, include_tube: bool = true) -> Dictionary:
	var registry := super.fixture_asset(packet,unit,include_tube)
	packet.sources.fixture.artifact="res://tests/run_era_binding_checks.gd"
	packet.sources.fixture.sha256=FileAccess.get_sha256(packet.sources.fixture.artifact)
	for layer in packet.armor_layers:
		layer["reactive_profile"]=EraFixture.profile()
		packet.facts["protection.layer."+str(layer.id)].value=layer.duplicate(true)
		packet.facts["protection.layer."+str(layer.id)].location="fixture_asset(): independently authored test tile, tests/fixtures/reactive_profile.gd"
	if include_tube:
		for defect in ["missing_evidence","changed_threshold","missing_channel","legacy_shell","wrong_origin","oversized_id"]:
			var bad := packet.duplicate(true)
			match defect:
				"missing_evidence": bad.facts.erase("protection.layer.attached_hull")
				"changed_threshold": bad.armor_layers[0].reactive_profile.channels.chemical.trigger_min_mm=40
				"missing_channel": bad.armor_layers[0].reactive_profile.channels.erase("fragment")
				"legacy_shell": bad.shell_catalog.shells[0].erase("impact_profile"); bad.shell_catalog.shells[0].evidence.erase("impact")
				"wrong_origin": bad.facts["protection.layer.attached_hull"].origin="warthunder_reference"
				"oversized_id":
					bad.armor_layers[0].id="x".repeat(129)
					var claim: Dictionary=bad.facts["protection.layer.attached_hull"].duplicate(true)
					claim.value=bad.armor_layers[0].duplicate(true)
					bad.facts.erase("protection.layer.attached_hull")
					bad.facts["protection.layer."+str(bad.armor_layers[0].id)]=claim
			check(not VehicleContentPipeline.validate_package(bad,registry).ok,"complete ERA package rejects incomplete proof or shell policy: "+defect)
	return registry

func capture_bound(actor: VehicleActor, unit: float) -> void:
	var layout: VehicleLayoutDefinition=actor.damage_layout_override
	var snapshots: Array=[QuerySnapshotBuilder.build_from_vehicle(actor.tank,layout)]
	for part in ["hull","turret","barrel"]:
		var parent := DamageTrainingLayout.part_node(actor,part)
		var point: Vector3=parent.global_transform*Vector3(0,1.2,3.5)
		var normal: Vector3=parent.global_basis*Vector3.BACK
		var query := ShotQueryService.query({"query_id":"era_visual_"+part,"physics_tick":Engine.get_physics_frames(),"from_world":point+normal*0.1,"to_world":point-normal*0.1},snapshots)
		var event := {}
		for candidate in query.get("events",[]):
			if candidate.get("surface_id")=="attached_"+part: event=candidate.duplicate(true); break
		check(not event.is_empty(),"actual query finds attached ERA tile on "+part)
		if event.is_empty(): continue
		event.event_id="era_visual_"+part
		var committed := actor.apply_projectile_armor(event,-normal,{"base_mm":100,"effect_policy":"chemical","impact_profile":HeatFixture.impact(),"caliber_mm":120})
		var mesh := parent.get_node("Protection_attached_"+part) as MeshInstance3D
		check(committed.ok and committed.result.reactive_triggered and actor.state.reactive_armor["attached_"+part]==0,"actual armor transaction consumes only that mounted tile")
		check(mesh.visible and mesh.material_override.albedo_color.is_equal_approx(Color(0.14,0.13,0.12)),"spent casing remains visible with damaged material")
	await super.capture_bound(actor,unit)
	actor.reset_vehicle()
	for part in ["hull","turret","barrel"]:
		var mesh := DamageTrainingLayout.part_node(actor,part).get_node("Protection_attached_"+part) as MeshInstance3D
		check(actor.state.reactive_armor["attached_"+part]==1 and mesh.material_override.albedo_color.is_equal_approx(Color(0.34,0.39,0.25)),"real reset restores both mounted tile state and appearance")
