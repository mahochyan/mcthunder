class_name AIDifficulty
extends RefCounted
## Perception and skill only. Never changes vehicle or weapon definitions.
static func profile(level: String) -> Dictionary:
	match level:
		"easy": return {"id":level,"reaction":1.2,"period":0.4,"error_degrees":1.1}
		"hard": return {"id":level,"reaction":0.35,"period":0.12,"error_degrees":0.12}
		_: return {"id":"normal","reaction":0.7,"period":0.25,"error_degrees":0.4}
