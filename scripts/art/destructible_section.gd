class_name DestructibleSection
extends StaticBody3D
## Authored structural states. Called only by the actual nearest world-hit branch.
## No notifications here: commit physics/visuals first, ProjectileManager publishes the record.
const MAX_HITS := 2
const MIN_IMPACT_SPEED := 30.0 # Explicit game-design threshold, not structural engineering.
var structure_id := ""
var section_id := ""
var style := "brick"
var dimensions := Vector3(5.2,2.8,0.7)
var hits := 0
var last_change: Dictionary = {}
var _seen: Dictionary = {}
var _visual: Node3D
var _shape: CollisionShape3D
var _ruin_shapes: Array[CollisionShape3D] = []

func setup(id: String, part: String, kind: String, size: Vector3) -> void:
	structure_id = id; section_id = part; style = kind; dimensions = size
	name = part
	collision_layer = GameConfig.LAYER_WORLD; collision_mask = 0
	WorldCollisionRules.tag(self,"building" if style == "wood" else "stone_wall")
	set_meta("destructible",true)
	_shape = CollisionShape3D.new(); _shape.shape = BoxShape3D.new(); _shape.shape.size = dimensions
	_shape.position.y = dimensions.y/2; add_child(_shape)
	_rebuild_visual()

func apply_shell_impact(impact: Dictionary) -> Dictionary:
	if hits >= MAX_HITS or not is_inside_tree() or is_queued_for_deletion(): return {}
	var velocity: Variant = impact.get("velocity")
	var point: Variant = impact.get("point")
	if not velocity is Vector3 or not velocity.is_finite() or velocity.length() < MIN_IMPACT_SPEED: return {}
	if not point is Vector3 or not point.is_finite(): return {}
	for key in ["manager_id","projectile_id","shot_id"]:
		if int(impact.get(key,0)) <= 0: return {}
	if str(impact.get("shooter_id","")).is_empty(): return {}
	var identity := JSON.stringify([impact.manager_id,impact.get("round_id",0),impact.shooter_id,impact.get("shooter_life_id",0),impact.shot_id,impact.projectile_id])
	if _seen.has(identity): return {}
	_seen[identity] = true
	var before := hits; hits += 1
	if hits == MAX_HITS:
		# Safe in ProjectileManager's physics callback; no deferred old full-size blocker.
		_shape.disabled = true
		_build_ruin_collision()
		var collapse:=StructureCollapse.new(); add_child(collapse); collapse.start(dimensions,style)
	_rebuild_visual()
	last_change = {"event_id":identity,"structure_id":structure_id,"section_id":section_id,
		"before":before,"after":hits,"collapsed":hits==MAX_HITS,"point_world":point,"rules_version":"structure-025-v1"}
	var dust := StructureDust.new(); add_child(dust); dust.start(to_local(point),style)
	return last_change.duplicate(true)

func _build_ruin_collision() -> void:
	for side in [-1,1]:
		var shape := CollisionShape3D.new(); shape.shape = BoxShape3D.new()
		shape.shape.size = Vector3(0.3,0.35,dimensions.z)
		shape.position = Vector3(side*(dimensions.x/2-0.15),0.175,0)
		add_child(shape); _ruin_shapes.append(shape)

func _rebuild_visual() -> void:
	if is_instance_valid(_visual):
		_visual.visible = false; _visual.queue_free()
	var batch := StaticArtBatch.new()
	if hits == MAX_HITS:
		if style=="wood":
			for side in [-1,1]:
				batch.box(Vector3(side*1.8,0.035,0),Vector3(2.0,0.07,dimensions.z*0.7),"wood_dark",Vector3(0,side*0.12,0))
		for side in [-1,1]:
			batch.box(Vector3(side*(dimensions.x/2-0.15),0.175,0),Vector3(0.3,0.35,dimensions.z),"wood_dark" if style=="wood" else "brick")
		# Thin scattered splinters/rubble are decoration, entirely within the former footprint.
		for i in 12:
			var x := sin(i*2.4)*(dimensions.x/2-0.5)
			var z := cos(i*1.7)*(dimensions.z/2-0.15)
			batch.box(Vector3(x,0.035,z),Vector3(0.24,0.07,0.3),"wood" if style=="wood" else "mortar",Vector3(0,i*0.8,0))
	elif style == "wood":
		batch.box(Vector3(0,dimensions.y/2,0),dimensions,"wood" if hits==0 else "wood_dark")
		# Roof is within the same closed collision envelope; no hollow door painted as a passage.
		batch.box(Vector3(0,dimensions.y-0.08,0),Vector3(dimensions.x,0.16,dimensions.z),"dark")
		for side in [-1,1]:
			for x in [-dimensions.x/2+0.15,dimensions.x/2-0.15]:
				batch.box(Vector3(x,dimensions.y/2,side*(dimensions.z/2+0.015)),Vector3(0.15,dimensions.y,0.025),"wood_dark")
			batch.box(Vector3(0,1.25,side*(dimensions.z/2+0.015)),Vector3(2.1,2.5,0.025),"wood_dark")
			for i in 7:
				batch.box(Vector3(0,0.5+i*0.45,side*(dimensions.z/2+0.018)),Vector3(dimensions.x,0.025,0.012),"wood_dark")
		if hits==1: _cracks(batch)
	else:
		batch.box(Vector3(0,dimensions.y/2,0),dimensions,"brick")
		for side in [-1,1]:
			var z: float = side*(dimensions.z/2+0.008)
			for row in 7:
				batch.box(Vector3(0,0.2+row*0.4,z),Vector3(dimensions.x,0.018,0.01),"mortar")
				for column in 6:
					var x := -dimensions.x/2+0.35+column*0.85+0.25*(row%2)
					batch.box(Vector3(x,0.4+row*0.4,z),Vector3(0.018,0.38,0.01),"mortar")
		if hits==1: _cracks(batch)
	_visual = batch.finish(self,"StructureState_%d"%hits)

func _cracks(batch: StaticArtBatch) -> void:
	for side in [-1,1]:
		for i in 5:
			batch.box(Vector3(sin(i*2.0)*0.25,0.4+i*0.48,side*(dimensions.z/2+0.032)),Vector3(0.055,0.58,0.015),"charcoal",Vector3(0,0,0.4 if i%2==0 else -0.45))
