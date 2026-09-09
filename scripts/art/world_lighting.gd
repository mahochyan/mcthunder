class_name WorldLighting
extends RefCounted
static func build(parent: Node3D) -> void:
	var sun := DirectionalLight3D.new(); sun.name = "SharedDaylight"
	sun.rotation_degrees = Vector3(-48,-32,0)
	sun.light_color = Color("f6eedf"); sun.light_energy = 0.85
	sun.shadow_enabled = true; sun.directional_shadow_max_distance = 240
	parent.add_child(sun)
	var world := WorldEnvironment.new(); world.name = "SharedAtmosphere"; world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR; world.environment.background_color = Color("afbdc1")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("d6dfd9"); world.environment.ambient_light_energy = 0.42
	parent.add_child(world)
