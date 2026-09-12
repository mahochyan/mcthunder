extends "res://tests/run_damage_checks.gd"
## Replay the real actor damage suite with an explicitly authored long rod.
const RodFixture=preload("res://tests/fixtures/long_rod_profile.gd")

func _layout(kind: String = "engine", thickness: float = 40, external: bool = false) -> VehicleLayoutDefinition:
	var layout := super._layout(kind,thickness,external)
	# The old pure budget fixture had no material. This authored variant declares steel.
	for patch in layout.armor_patches: patch.material_kind="rolled"
	return layout

func _spawn(power: float = 70, offset: Vector3 = Vector3.ZERO) -> ProjectileState:
	# The base suite also builds a rotated plate inline; give only its synthetic
	# test_steel marker an explicit authored material. Never replace unknown data.
	for actor in [a,b]:
		if actor.damage_layout_override!=null:
			for patch in actor.damage_layout_override.armor_patches:
				if patch.material_kind=="test_steel": patch.material_kind="rolled"
	shot+=1
	var origin := b.tank.global_transform*(Vector3(0,1,0)+offset)
	var result := mgr.try_spawn({"round_id":1202,"shooter_id":"test_source","shooter_life_id":1,"shot_id":shot,
		"shell_id":"test_long_rod","armor_policy":"resolve","effect_policy":"long_rod","impact_profile":RodFixture.profile(),"caliber_mm":120,
		"penetration_curve":PackedVector2Array([Vector2(0,power)]),"position_world":origin,"velocity_world":Vector3(0,0,-1200),
		"gravity_world":Vector3.ZERO,"max_age_s":2.0,"max_distance_m":100.0})
	_ok(result.ok,"actual manager accepts long-rod damage shot")
	return mgr.get_projectile_state(result.projectile_id)
