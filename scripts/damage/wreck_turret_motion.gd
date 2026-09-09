class_name WreckTurretMotion
extends CharacterBody3D
## Actual TurretRig is moved, so the visible and query geometry share the same pose.
var actor: VehicleActor
var generation := 0
var original_transform := Transform3D.IDENTITY
var elapsed := 0.0
var settled := false
var spin := 0.0

func launch(vehicle: VehicleActor) -> void:
	actor=vehicle; generation=vehicle.state.generation; original_transform=vehicle.turret.transform
	name="DetachedTurretWreck"; process_mode=Node.PROCESS_MODE_PAUSABLE; process_physics_priority=50
	global_transform=vehicle.turret.global_transform
	collision_layer=GameConfig.LAYER_VEHICLE; collision_mask=GameConfig.LAYER_WORLD|GameConfig.LAYER_VEHICLE
	add_collision_exception_with(vehicle.tank)
	var layout := vehicle.damage_layout_override
	var origin := global_transform.affine_inverse()
	for part in ["turret","barrel"]:
		var points := PackedVector3Array()
		var part_node := DamageTrainingLayout.part_node(vehicle,part)
		var transform: Transform3D=origin*part_node.global_transform
		for patch in layout.armor_patches:
			if patch.part_id==part:
				for point in patch.vertices_local_m: points.append(transform*point)
		if points.size()<4: continue
		var shape:=CollisionShape3D.new(); var convex:=ConvexPolygonShape3D.new(); convex.points=points
		shape.shape=convex; add_child(shape)
	vehicle.turret.reparent(self,true)
	# Bounded authored impulse, not a claim to simulate explosive pressure.
	var side := 1.0 if vehicle.life_id%2==0 else -1.0
	velocity=vehicle.tank.global_basis*Vector3(side*2.8,8.0,1.0)
	spin=side*0.65
	floor_stop_on_slope=true

func _physics_process(delta: float) -> void:
	if not is_instance_valid(actor): return
	if actor.state.generation!=generation or not actor.state.destroyed:
		restore(); return
	if settled: return
	elapsed+=delta
	if not is_on_floor(): rotate_object_local(Vector3.FORWARD,spin*delta)
	velocity.y-=9.8*delta
	if is_on_floor():
		velocity.x=move_toward(velocity.x,0,6*delta); velocity.z=move_toward(velocity.z,0,6*delta)
	move_and_slide()
	if is_on_floor() and Vector2(velocity.x,velocity.z).length()<0.05 or elapsed>=5.0:
		settled=true; velocity=Vector3.ZERO

func freeze() -> void:
	velocity=Vector3.ZERO; set_physics_process(false)

func restore() -> void:
	if is_instance_valid(actor) and is_instance_valid(actor.turret) and actor.turret.get_parent()==self:
		actor.turret.reparent(actor.tank,false); actor.turret.transform=original_transform
		actor.turret.set_process(true)
	collision_layer=0; collision_mask=0; set_physics_process(false); queue_free()
