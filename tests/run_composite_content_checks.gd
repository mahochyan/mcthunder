extends "res://tests/run_chemical_content_checks.gd"
const CompositeFixture=preload("res://tests/fixtures/composite_profile.gd")

func _fixture(count: int = 1) -> Dictionary:
	var packet := super._fixture(count)
	packet.armor_layers=[CompositeFixture.sheet("test_outer_composite",3.5),CompositeFixture.sheet("test_inner_steel",3.0,"rolled")]
	var source: Dictionary=packet.sources.fixture.duplicate(true)
	source.artifact="res://tests/fixtures/composite_profile.gd"; source.sha256=FileAccess.get_sha256(source.artifact)
	packet.sources.composite_fixture=source
	for layer in packet.armor_layers:
		var claim := _claim(layer.duplicate(true),"structured"); claim.source_refs=["composite_fixture"]; claim.location="sheet(): explicit local metre geometry and physical thickness"
		packet.facts["protection.layer."+str(layer.id)]=claim
	return packet

func _run() -> void:
	var packet := _fixture(2)
	var result := VehicleContentPipeline.validate_package(packet)
	check(result.ok,"complete reference packet admits independently evidenced supplementary composite sheets")
	if not result.ok: print(result.errors); quit(1); return
	var outer: ArmorPatchDefinition=result.layout.armor_patches[-2]
	var inner: ArmorPatchDefinition=result.layout.armor_patches[-1]
	check(outer.id=="test_outer_composite" and inner.id=="test_inner_steel" and outer.vertices_local_m[0].z-inner.vertices_local_m[0].z==0.5,"admitted layout preserves exact ids, geometry and half-metre gap")
	check(outer.response_profile==CompositeFixture.profile() and inner.response_profile.is_empty(),"separate composite and steel policies retained")
	for defect in ["missing_evidence","changed_position","changed_coefficient","missing_channel","wrong_source","duplicate","unknown_part","nonplanar","nonunit_normal","empty","null_row","bad_id","negative_thickness","unknown_rule"]:
		var bad := packet.duplicate(true)
		match defect:
			"missing_evidence": bad.facts.erase("protection.layer.test_outer_composite")
			"changed_position": bad.armor_layers[0].vertices_m[0][2]+=1
			"changed_coefficient": bad.armor_layers[0].response_profile.coefficients.chemical=0.1
			"missing_channel": bad.armor_layers[0].response_profile.coefficients.erase("fragment")
			"wrong_source": bad.facts["protection.layer.test_outer_composite"].origin="warthunder_reference"
			"duplicate": bad.armor_layers.append(bad.armor_layers[0].duplicate(true))
			"unknown_part": bad.armor_layers[0].part="missing"
			"nonplanar": bad.armor_layers[0].vertices_m[0][2]+=0.1
			"nonunit_normal": bad.armor_layers[0].normal=[0,0,2]
			"empty": bad.armor_layers=[]
			"null_row": bad.armor_layers=[null]
			"bad_id": bad.armor_layers[0].erase("id")
			"negative_thickness": bad.armor_layers[0].thickness_mm=-1
			"unknown_rule": bad.armor_layers[0].era=true
		check(not VehicleContentPipeline.validate_package(bad).ok,"reject incomplete/malformed actual protection package: "+defect)
	var zone := packet.duplicate(true)
	zone.armor.hull_front_upper.material="composite"; zone.armor.hull_front_upper.response_profile=CompositeFixture.profile()
	check(not VehicleContentPipeline.validate_package(zone).ok,"existing zone cannot acquire unevidenced composite protection")
	zone.facts["protection.zone.hull_front_upper"]=_claim({"material":"composite","response_profile":CompositeFixture.profile()},"structured")
	check(VehicleContentPipeline.validate_package(zone).ok,"existing physical face can carry separately registered composite rule")
	await super._run() # Actual catalog, actor setup, normal AP/HEAT selection, reload and firing.
