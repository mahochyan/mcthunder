class_name DamageTrainingLayout
extends RefCounted
## Five-person, low-poly engineering fixture. All dimensions and armor are designed values.
static func build(with_recovery: bool = false) -> VehicleLayoutDefinition:
	var layout: VehicleLayoutDefinition = load("res://configs/layouts/test_player_vehicle_layout.tres").duplicate(true)
	layout.id = "test_damage_vehicle"
	layout.content_tier = "test"
	layout.recovery_enabled = with_recovery
	for patch in layout.armor_patches:
		patch.has_thickness = true
		patch.thickness_mm = 20.0
		patch.thickness_status = "estimated"
		patch.material_kind = "rolled"
	layout.modules.clear()
	var specs := [
		["engine","engine","hull",Vector3(0,0.9,0.9),Vector3(1.0,0.6,0.7),false],
		["track_left","track","hull",Vector3(-1.25,0.3,0),Vector3(0.55,0.6,3.9),true],
		["track_right","track","hull",Vector3(1.25,0.3,0),Vector3(0.55,0.6,3.9),true],
		["breech","breech","turret",Vector3(0,0.22,-0.35),Vector3(0.42,0.3,0.5),false],
		["turret_drive","turret_drive","hull",Vector3(0,1.27,0),Vector3(0.55,0.12,0.55),false],
		["ammo_rack","ammo","hull",Vector3(0.72,0.8,0.35),Vector3(0.3,0.5,0.7),false],
		["transmission","transmission","hull",Vector3(0,0.5,-1.3),Vector3(0.8,0.4,0.55),false],
		["fuel","fuel","hull",Vector3(-0.78,0.8,1.05),Vector3(0.3,0.5,0.4),false],
	]
	for spec in specs:
		var m := ModuleVolumeDefinition.new()
		m.id = spec[0]
		m.kind = spec[1]
		m.part_id = spec[2]
		m.local_box_transform = Transform3D(Basis.IDENTITY,spec[3])
		m.size_m = spec[4]
		m.external = spec[5]
		m.geometry_status = "estimated"
		layout.modules.append(m)
	layout.crew_stations.clear()
	var crew := [
		["driver","driver","hull",Vector3(-0.5,0.85,-0.95)],
		["assistant_driver","assistant_driver_bow_gunner","hull",Vector3(0.5,0.85,-0.95)],
		["gunner","gunner","turret",Vector3(-0.46,0.28,-0.2)],
		["loader","loader","turret",Vector3(0.46,0.28,-0.05)],
		["commander","commander","turret",Vector3(-0.15,0.32,0.52)],
	]
	for spec in crew:
		var person := CrewStationDefinition.new()
		person.id = spec[0]
		person.role = spec[1]
		person.part_id = spec[2]
		person.local_box_transform = Transform3D(Basis.IDENTITY,spec[3])
		person.size_m = Vector3(0.26,0.32,0.3)
		person.position_status = "estimated"
		person.volume_status = "estimated"
		person.role_placement_status = "estimated"
		layout.crew_stations.append(person)
	for module in layout.modules:
		if module.kind == "engine":
			module.fire_module_targets = PackedStringArray(["engine","fuel"])
			module.fire_crew_targets = PackedStringArray(["driver","assistant_driver","gunner","loader","commander"])
	return layout

static func part_node(actor: VehicleActor, part: String) -> Node3D:
	match part:
		"turret": return actor.turret
		"barrel": return actor.turret.barrel_pivot
	return actor.tank
