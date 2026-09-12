extends "res://tests/run_long_rod_content_checks.gd"
const SpallFixture=preload("res://tests/fixtures/spall_profile.gd")

func _shell(index: int) -> Dictionary:
	var data := super._shell(index)
	if index>0:
		data.post_penetration_profile=SpallFixture.profile()
		data.evidence.post_penetration=_claim(data.post_penetration_profile.duplicate(true),"structured")
		data.evidence.post_penetration.source_refs=["spall_fixture"]
		data.evidence.post_penetration.location="tests/fixtures/spall_profile.gd: profile()"
	return data

func _fixture(count: int = 1) -> Dictionary:
	var packet := super._fixture(count)
	var source: Dictionary=packet.sources.fixture.duplicate(true)
	source.artifact="res://tests/fixtures/spall_profile.gd"
	source.sha256=FileAccess.get_sha256(source.artifact)
	packet.sources.spall_fixture=source
	return packet

func inspect_modern_shot(rod: ProjectileState, record: Dictionary) -> void:
	check(rod.post_penetration_profile==SpallFixture.profile(),"ordinary Gunner launch freezes separately evidenced spall rules")
	check(rod.spall_events.size()==1 and rod.fragments.size()==6 and rod.burst.is_empty(),"ordinary APFSDS shot emits real directional spall at its first plate")
	check(not record.is_empty() and record.rules_versions.get("post_penetration")==SpallProfile.VERSION,"normally fired modern replay retains separate post-penetration version")

func _run() -> void:
	var packet := _fixture(2)
	check(VehicleShellCatalog.build(packet).ok,"complete separate spall evidence admitted")
	for defect in ["missing_evidence","changed_value","historical_verified","wrong_effect","wrong_fragment_family"]:
		var bad := packet.duplicate(true); var shell: Dictionary=bad.shell_catalog.shells[1]
		match defect:
			"missing_evidence": shell.evidence.erase("post_penetration")
			"changed_value": shell.post_penetration_profile.count=3
			"historical_verified": shell.evidence.post_penetration.status="verified"
			"wrong_effect": shell.effect_policy="internal_burst"; shell.evidence.effect.value="internal_burst"
			"wrong_fragment_family": shell.post_penetration_profile.fragment_impact_profile.family="AP"; shell.evidence.post_penetration.value=shell.post_penetration_profile.duplicate(true)
		check(not VehicleShellCatalog.build(bad).ok,"reject inconsistent spall source/profile: "+defect)
	await super._run()
