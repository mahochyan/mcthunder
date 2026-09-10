extends "res://tests/fixtures/balance_village.gd"
func _init() -> void: definition=IndustrialDefinition.create()
func _build_world() -> void: terrain=IndustrialWorld.build(self,definition,graybox)
