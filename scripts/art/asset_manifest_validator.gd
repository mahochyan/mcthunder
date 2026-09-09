class_name AssetManifestValidator
extends RefCounted
static func vehicle(id: String, check_source: bool = false) -> Dictionary:
	if id not in VehicleCatalog.IDS: return {"ok":false,"errors":["unknown_vehicle"]}
	var manifest: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://assets/vehicles/"+id+".manifest.json"))
	var errors: Array[String]=[]
	if not manifest is Dictionary: return {"ok":false,"errors":["missing_manifest"]}
	if manifest.get("schema_version",0)!=2 or manifest.get("vehicle_id","")!=id: errors.append("identity")
	if manifest.get("redistribute_source_allowed",false)!=true or str(manifest.get("license_status","")).is_empty() or str(manifest.get("author","")).is_empty(): errors.append("provenance")
	for key in ["source_file","runtime_file","generator","edited_export"]:
		var path:=str(manifest.get(key,""))
		if path.is_empty() or path.is_absolute_path() or path.contains("..") or path.contains("\\"): errors.append("unsafe_path_"+key)
	if manifest.get("runtime_file","")!="assets/vehicles/"+id+".glb" or not ResourceLoader.exists("res://"+str(manifest.get("runtime_file",""))): errors.append("runtime_asset")
	if str(manifest.get("palette_sha256",""))!=FileAccess.get_sha256("res://assets/art_palette.json"): errors.append("palette_hash")
	if check_source:
		for pair in [["source_file","blend_sha256"],["runtime_file","glb_sha256"]]:
			var path:="res://"+str(manifest.get(pair[0],""))
			if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=str(manifest.get(pair[1],"")): errors.append("hash_"+str(pair[0]))
	return {"ok":errors.is_empty(),"errors":errors,"manifest":manifest}

static func world_art(check_source: bool = false) -> Dictionary:
	var manifest: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://assets/world_art.manifest.json"))
	var errors: Array[String]=[]
	if not manifest is Dictionary: return {"ok":false,"errors":["missing_world_manifest"]}
	if manifest.get("schema_version",0)!=1 or manifest.get("redistribute_source_allowed",false)!=true: errors.append("world_provenance")
	for asset in manifest.get("assets",[]):
		for row in asset.get("files",[]):
			var path:=str(row.get("path",""))
			if path.is_empty() or path.is_absolute_path() or path.contains("..") or path.contains("\\"):
				errors.append("unsafe_world_path"); continue
			if check_source and FileAccess.get_file_as_string("res://"+path).replace("\r\n","\n").sha256_text()!=str(row.get("sha256","")): errors.append("world_hash_"+path)
	return {"ok":errors.is_empty(),"errors":errors}
