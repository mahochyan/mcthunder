extends SceneTree
const APP_SCENE = preload("res://scenes/app.tscn")
var checks:=0
var failed:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failed+=1
	print(("[PASS] " if ok else "[FAIL] ")+label)
func run() -> void:
	var defs:=VehicleDefs.new(); defs.load_defaults()
	var catalog:=VehicleCatalog.new(); check(catalog.load_all(defs).ok,"actual four-vehicle geometry admitted")
	var world:=Node3D.new(); root.add_child(world)
	var snapshots: Array=[]
	for index in VehicleCatalog.IDS.size():
		var actor:=VehicleActor.new(); world.add_child(actor)
		check(actor.setup(defs,VehicleCatalog.IDS[index],"target%d"%index,2,Transform3D(Basis.IDENTITY,Vector3(index*10,100,0)),4,null).ok,"actual vehicle instantiated "+str(index))
		actor.process_mode=Node.PROCESS_MODE_DISABLED
		snapshots.append(QuerySnapshotBuilder.build_from_vehicle(actor.tank,actor.damage_layout_override))
	await physics_frame
	var requests: Array=[]
	for index in 4:
		for height in [0.6,1.2,2.1,2.8]:
			for yaw in [0.0,0.5,1.2,2.0]:
				var direction:=Vector3(sin(yaw),0,cos(yaw))
				var center:=Vector3(index*10,100+height,0)
				requests.append({"from_world":center-direction*80,"to_world":center+direction*80,"include_modules":true,"include_crew":true})
	var golden: Array=[]
	ShotQueryService.bounds_cache_enabled=false
	ShotQueryService.part_culling_enabled=false
	for request in requests: golden.append(ShotQueryService.query(request,snapshots))
	ShotQueryService.bounds_cache_enabled=true
	ShotQueryService.part_culling_enabled=true
	var equal:=true
	for repetition in 2:
		for index in requests.size(): equal=equal and ShotQueryService.query(requests[index],snapshots)==golden[index]
	check(equal,"64 real four-vehicle rays preserve complete armor/module/crew events with cold and warm caches")
	# Explicit mutable layout fixture: translation after warm-up must invalidate by value.
	var altered: Dictionary=snapshots[0].duplicate(true)
	var layout:=altered.layout.duplicate(true) as VehicleLayoutDefinition
	altered.layout=layout
	for patch in layout.armor_patches:
		for index in patch.vertices_local_m.size(): patch.vertices_local_m[index]+=Vector3(4,0,0)
	var request: Dictionary=requests[0].duplicate(); request.from_world.x+=4; request.to_world.x+=4
	var cached:=ShotQueryService.query(request,[altered])
	ShotQueryService.bounds_cache_enabled=false
	ShotQueryService.part_culling_enabled=false
	var fresh:=ShotQueryService.query(request,[altered])
	ShotQueryService.bounds_cache_enabled=true
	ShotQueryService.part_culling_enabled=true
	check(cached==fresh and not fresh.events.is_empty(),"changed geometry is queried at its new position without stale shared bounds")
	# Warm the same resource, then mutate it in place: identity/revision are unchanged.
	for patch in layout.armor_patches:
		for index in patch.vertices_local_m.size(): patch.vertices_local_m[index]-=Vector3(8,0,0)
	request.from_world.x-=8; request.to_world.x-=8
	cached=ShotQueryService.query(request,[altered])
	ShotQueryService.part_culling_enabled=false
	fresh=ShotQueryService.query(request,[altered])
	ShotQueryService.part_culling_enabled=true
	check(cached==fresh and not fresh.events.is_empty(),"warm part bounds detect in-place geometry edits without revision changes")
	for part_id in altered.part_world_transforms:
		var transform: Transform3D=altered.part_world_transforms[part_id]
		transform.origin+=Vector3(7,0,0); altered.part_world_transforms[part_id]=transform
	request.from_world.x+=7; request.to_world.x+=7
	cached=ShotQueryService.query(request,[altered])
	ShotQueryService.part_culling_enabled=false
	fresh=ShotQueryService.query(request,[altered])
	ShotQueryService.part_culling_enabled=true
	check(cached==fresh and not fresh.events.is_empty(),"part culling uses current transforms after vehicle movement")
	for index in 600:
		ShotQueryService._bounds(PackedVector3Array([Vector3(index,0,0),Vector3(index+1,1,1)]))
	check(ShotQueryService._vertex_bounds.size()<=ShotQueryService.BOUNDS_CACHE_LIMIT,"cache stays bounded after more than its capacity of distinct geometries")
	equal=true
	for index in requests.size(): equal=equal and ShotQueryService.query(requests[index],snapshots)==golden[index]
	check(equal,"eviction and geometry edits preserve original production query results")
	world.free(); await process_frame
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failed])
	print("QUERY_CACHE_CHECKS_PASS" if failed==0 else "QUERY_CACHE_CHECKS_FAIL")
	quit(0 if failed==0 else 1)
