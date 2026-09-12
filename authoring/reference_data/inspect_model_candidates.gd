extends SceneTree
## Read frozen authoring snapshots; never writes to the external model workspace.
var output_folder := ""

func _initialize() -> void: call_deferred("run")

func inspect_nodes(node: Node, transform: Transform3D, rows: Array, stats: Dictionary) -> void:
	var local := transform
	if node is Node3D: local=transform*node.transform
	var row := {"path":str(node.get_path()),"type":node.get_class()}
	if node is Node3D:
		row["position"]=[local.origin.x,local.origin.y,local.origin.z]
		row["scale"]=[local.basis.x.length(),local.basis.y.length(),local.basis.z.length()]
		if not local.is_finite(): stats.errors.append("nonfinite transform: "+str(node.get_path()))
	if node is MeshInstance3D and node.mesh!=null:
		var mesh: Mesh=node.mesh
		var triangles := 0
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			if mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES:
				stats.errors.append("nontriangle surface: "+str(node.get_path()))
			else: triangles+=int((indices.size() if not indices.is_empty() else vertices.size())/3)
			for vertex in vertices:
				if not vertex.is_finite(): stats.errors.append("nonfinite vertex: "+str(node.get_path())); break
			stats.surfaces+=1
		var bound: AABB=local*mesh.get_aabb()
		row["bounds_min"]=[bound.position.x,bound.position.y,bound.position.z]
		row["bounds_max"]=[bound.end.x,bound.end.y,bound.end.z]
		stats.bounds=bound if stats.meshes==0 else stats.bounds.merge(bound)
		stats.meshes+=1; stats.triangles+=triangles; row["triangles"]=triangles
	rows.append(row)
	for child in node.get_children(): inspect_nodes(child,local,rows,stats)

func capture_model(scene: Node3D, bounds: AABB, id: String) -> bool:
	var captured := true
	var world := Node3D.new(); root.add_child(world)
	root.remove_child(scene); world.add_child(scene)
	var light := DirectionalLight3D.new(); light.rotation_degrees=Vector3(-45,-35,0); light.light_energy=1.15; world.add_child(light)
	var environment := WorldEnvironment.new(); environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color("78858d")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE; environment.environment.ambient_light_energy=0.6
	world.add_child(environment)
	var camera := Camera3D.new(); world.add_child(camera); camera.current=true
	var size := maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))
	var center := bounds.get_center()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=size*1.4; camera.far=1000
	var directions := {"front":Vector3(0.65,0.4,-1),"side":Vector3(1,0.18,0),"rear":Vector3(-0.65,0.4,1),"top":Vector3(0,1,0.001)}
	for view in directions:
		camera.position=center+directions[view].normalized()*size*2
		camera.look_at(center,Vector3.UP)
		for frame in 3: await process_frame
		await RenderingServer.frame_post_draw
		var error := root.get_texture().get_image().save_png(output_folder+"/"+id+"_"+view+".png")
		if error!=OK:
			captured=false
			push_error("capture failed: "+id+"/"+view)
	world.remove_child(scene); root.add_child(scene); world.free()
	return captured

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()<2: push_error("expected input manifest and output folder"); quit(2); return
	if args.has("--capture") and DisplayServer.get_name()=="headless":
		push_error("capture requires a window renderer"); quit(2); return
	output_folder=args[1]; DirAccess.make_dir_recursive_absolute(output_folder)
	var input: Variant=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	if not input is Dictionary or not input.get("models") is Array: quit(2); return
	var report := {"schema":1,"engine":Engine.get_version_info().string,"admission":"candidate_only","human":"NOT_RUN","models":[]}
	var failed := false
	for candidate in input.models:
		var entry: Dictionary=candidate.duplicate(true)
		entry["errors"]=[]; entry["review_status"]="not_inspected"
		if candidate.get("status")!="snapshot_ready" or FileAccess.get_sha256(candidate.path)!=candidate.sha256:
			entry.errors.append("snapshot missing or changed"); failed=true; report.models.append(entry); continue
		var document := GLTFDocument.new(); var state := GLTFState.new()
		var error := document.append_from_file(candidate.path,state)
		if error!=OK:
			entry.errors.append("GLTF import error %d"%error); failed=true; report.models.append(entry); continue
		var scene := document.generate_scene(state) as Node3D
		if scene==null: failed=true; entry.errors.append("no Node3D scene"); report.models.append(entry); continue
		root.add_child(scene)
		var nodes: Array=[]; var stats := {"triangles":0,"meshes":0,"surfaces":0,"bounds":AABB(),"errors":[]}
		inspect_nodes(scene,Transform3D.IDENTITY,nodes,stats)
		var bound: AABB=stats.bounds
		entry["measured"]={"triangles":stats.triangles,"meshes":stats.meshes,"surfaces":stats.surfaces,"bounds_min":[bound.position.x,bound.position.y,bound.position.z],"dimensions_m":[bound.size.x,bound.size.y,bound.size.z]}
		entry["nodes"]=nodes; entry.errors.append_array(stats.errors)
		if stats.triangles!=int(candidate.triangles_reported): entry.errors.append("actual triangle count differs from source report")
		if stats.meshes<=0 or stats.triangles<=0: entry.errors.append("empty model")
		entry["review_status"]="geometry_inspected_not_admitted"
		entry["remaining"]=["exact variant silhouette and dimensions","explicit hull/turret/gun/muzzle binding","running gear and recoil","matching armor/internal geometry","damage and recovery presentation","normal player combat acceptance"]
		if args.has("--capture") and not await capture_model(scene,bound,candidate.id):
			entry.errors.append("one or more required captures failed")
		failed=failed or not entry.errors.is_empty(); report.models.append(entry)
		print(candidate.id+": triangles="+str(stats.triangles)+" dimensions="+str(bound.size)+" errors="+str(entry.errors))
		scene.free(); await process_frame
	var file := FileAccess.open(output_folder+"/MODEL_INSPECTION.json",FileAccess.WRITE)
	if file==null: quit(2); return
	file.store_string(JSON.stringify(report,"\t",true,true)); file.close()
	print("MODEL_INSPECTION_PASS" if not failed else "MODEL_INSPECTION_FAIL")
	quit(0 if not failed else 1)
