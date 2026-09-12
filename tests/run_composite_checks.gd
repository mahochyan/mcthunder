extends "res://tests/run_chemical_checks.gd"
const CompositeFixture=preload("res://tests/fixtures/composite_profile.gd")
const RodFixture=preload("res://tests/fixtures/long_rod_profile.gd")
const SpallFixture=preload("res://tests/fixtures/spall_profile.gd")

func composite_compartment() -> VehicleLayoutDefinition:
	var layout := compartment()
	var front: ArmorPatchDefinition = layout.armor_patches[4]
	front.material_kind="composite"; front.response_profile=CompositeFixture.profile()
	return layout

func chemical_cases() -> void:
	var st := launch_chemical(composite_compartment()); complete(st)
	check(st.contacts.size()==1 and is_equal_approx(st.contacts[0].effective_mm,40) and is_equal_approx(st.contacts[0].path_thickness_mm,20),"20 physical mm composite consumes40 chemical game mm")
	check(st.damage_records.size()==1 and is_equal_approx(st.chemical_effect.remaining_mm,20),"independent jet residual reaches actual engine through composite")
	replay_sample=record_for(st)
	for thickness in [50.0,51.0,-1.0]:
		var guarded := composite_compartment()
		guarded.armor_patches[4].thickness_mm=maxf(0,thickness)
		guarded.armor_patches[4].has_thickness=thickness>=0
		guarded.armor_patches[4].thickness_status="estimated" if thickness>=0 else "unknown"
		st=launch_chemical(guarded); complete(st)
		check(st.contacts[0].result==("unknown_armor" if thickness<0 else ("perforated_stop" if thickness==50 else "stopped")) and st.damage_records.is_empty(),"composite equal/stopped/unknown boundary blocks actual interior damage: "+str(thickness))
		record_for(st)
	for gap in [0.5,1.5]:
		var layout := composite_compartment()
		layout.modules.clear() # Isolate gap loss; actual engine consumption is asserted above.
		var sheet: ArmorPatchDefinition=ArmorTrainingTargets.build([{"center":Vector3(0,2,2-gap),"thickness":10}]).layout.armor_patches[0]
		sheet.id="inner_composite"; sheet.material_kind="composite"; sheet.response_profile=CompositeFixture.profile()
		layout.armor_patches.insert(0,sheet) # Deliberately opposite storage order.
		st=launch_chemical(layout); complete(st)
		check(st.contacts.size()==2 and st.contacts[0].surface_id!="inner_composite" and st.contacts[1].surface_id=="inner_composite","geometry determines layer order independently of array order")
		check(is_equal_approx(st.contacts[1].before_mm,60-gap*10) and is_equal_approx(st.contacts[1].effective_mm,20),"actual gap and separate second chemical resistance consume shared jet budget")
		record_for(st)
	for defect in ["contact_profile","frame_profile","layer_version","layer_channel","coefficient","moved_layer"]:
		var bad := replay_sample.duplicate(true)
		match defect:
			"contact_profile": bad.contacts[0].response_profile.coefficients.chemical=1
			"frame_profile":
				for patch in bad.frames[0].patches:
					if patch.id==bad.contacts[0].surface_id: patch.response_profile.coefficients.chemical=1
			"layer_version": bad.contacts[0].layer_profile_version="fake"
			"layer_channel": bad.contacts[0].layer_channel="kinetic"
			"coefficient": bad.contacts[0].material_multiplier=1
			"moved_layer":
				for patch in bad.frames[0].patches:
					if patch.id==bad.contacts[0].surface_id:
						for i in patch.vertices_world.size(): patch.vertices_world[i].x+=10
		check(not ShotRecordBuilder.validate(bad).ok,"replay rejects mismatched frozen composite response: "+defect)
	var event := {"has_thickness":true,"thickness_mm":20,"thickness_status":"estimated","material_kind":"composite","response_profile":CompositeFixture.profile(),"normal_world":Vector3.BACK}
	for kind in ["long_rod","chemical","fragment","kinetic","internal_burst"]:
		var impact: Dictionary = RodFixture.profile() if kind=="long_rod" else (HeatFixture.impact() if kind=="chemical" else SpallFixture.profile().fragment_impact_profile)
		if kind in ["kinetic","internal_burst"]:
			impact.family="AP" if kind=="kinetic" else "APHE"; impact.normalization_deg=4.0; impact.overmatch_ratio=3.0
		var budget := {"base_mm":100,"impact_profile":impact,"effect_policy":kind if kind!="fragment" else "kinetic","fragment":kind=="fragment","caliber_mm":120}
		var result := ArmorResolver.resolve(event,Vector3.FORWARD,budget)
		var expected: float=40 if kind=="chemical" else (30 if kind=="fragment" else 10)
		check(is_equal_approx(result.effective_mm,expected) and not result.overmatch,"separate composite channel without full-bore overmatch: "+kind)
		var inclined := event.duplicate(true); inclined.normal_world=Vector3(0,sin(PI/3),cos(PI/3))
		result=ArmorResolver.resolve(inclined,Vector3.FORWARD,budget)
		check(absf(result.effective_mm-(16 if kind=="long_rod" else expected*2))<0.001,"composite angle rule retains geometry without steel normalization: "+kind)
	check(ArmorResolver.resolve(event,Vector3.FORWARD,{"base_mm":100}).result=="unknown_material","legacy shell cannot silently borrow composite rules")
	for bad_profile in [{},null,[],CompositeFixture.profile().merged({"coefficients":{"kinetic":1,"chemical":1}},true),CompositeFixture.profile().merged({"era_charges":1},true)]:
		check(not ArmorLayerProfile.validate(bad_profile,"composite").is_empty(),"reject missing/mixed passive material rules")
	for value in [0,-1,INF,"2",true]:
		var bad := CompositeFixture.profile(); bad.coefficients.chemical=value
		check(not ArmorLayerProfile.validate(bad,"composite").is_empty(),"reject invalid composite channel "+str(value))
	# Real long rod sees10 material cost and continues to the actual internal engine.
	st=launch_chemical(composite_compartment(),2,600,{"effect_policy":"long_rod","impact_profile":RodFixture.profile(),"chemical_profile":{}}); complete(st)
	check(st.contacts.size()>=1 and is_equal_approx(st.contacts[0].effective_mm,10) and st.damage_records.size()==1,"real APFSDS carrier penetrates composite and disables actual module")
	record_for(st)
	var spall_layout := composite_compartment()
	var screen: ArmorPatchDefinition=ArmorTrainingTargets.build([{"center":Vector3(0,2,1.5),"thickness":1}]).layout.armor_patches[0]
	screen.id="spall_liner"; screen.material_kind="composite"; screen.response_profile=CompositeFixture.profile(); spall_layout.armor_patches.append(screen)
	st=launch_chemical(spall_layout,2,600,{"effect_policy":"long_rod","impact_profile":RodFixture.profile(),"chemical_profile":{},"post_penetration_profile":SpallFixture.profile()}); complete(st)
	var fragment_contacts := 0
	for fragment in st.fragments:
		for contact in fragment.contacts:
			if contact.get("surface_id")=="spall_liner":
				fragment_contacts+=1
				check(contact.layer_channel=="fragment" and is_equal_approx(contact.material_multiplier,1.5),"actual spall ray resolves separately authored composite fragment channel")
	check(fragment_contacts>0,"real inward long-rod impact produces spall that reaches separate liner geometry")
	record_for(st)
	# Live layout edits after capture cannot rewrite the already frozen replay's nested rule.
	var layout := composite_compartment(); st=launch_chemical(layout); complete(st)
	var frozen := record_for(st); layout.armor_patches[4].response_profile.coefficients.chemical=9
	check(frozen.contacts[0].response_profile.coefficients.chemical==2 and ShotRecordBuilder.validate(frozen).ok,"shot evidence deep-copies nested armor rule")
