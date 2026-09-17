extends SceneTree
## Exercise the same diagnostic shipped in the independent package.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var app: AppFlow=load("res://scenes/app.tscn").instantiate()
	app.profile=ProfileStore.new("user://tests/modern_life_%d/profile" % Time.get_ticks_usec())
	root.add_child(app); current_scene=app
	var verifier: Node=load("res://scripts/diagnostics/modern_life_verifier.gd").new()
	root.add_child(verifier)
	await verifier.run(app)
