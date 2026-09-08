class_name HistoricalVehicleGeometry
extends RefCounted
## Original faceted reconstructions. Packet dimensions are estimates; armor facts are independent.

static func vec(a: Array) -> Vector3:
	return Vector3(float(a[0]),float(a[1]),float(a[2]))

static func build(packet: Dictionary) -> VehicleLayoutDefinition:
	var out := VehicleLayoutDefinition.new()
	out.id = str(packet.id)+"_layout"
	out.historical_identity_id = packet.id
	out.display_name = packet.display_name
	out.content_tier = "production"
	out.recovery_enabled = true
	var g: Dictionary = packet.geometry
	for row in [["hull","","fixed",[0,0,0]],["turret","hull","yaw",g.turret_origin],["barrel","turret","pitch",g.gun_origin]]:
		var part := LayoutPartDefinition.new()
		part.id = row[0]; part.parent_id = row[1]; part.joint_kind = row[2]
		part.bind_local.origin = vec(row[3])
		if part.id == "turret": part.min_angle_deg = packet.runtime.get("yaw_min",-180); part.max_angle_deg = packet.runtime.get("yaw_max",180)
		if part.id == "barrel": part.min_angle_deg = packet.runtime.pitch_min; part.max_angle_deg = packet.runtime.pitch_max
		out.parts.append(part)
	var rings: Array = []
	for row in g.hull_rings:
		# Eight vertices preserve edges where forward/aft side armor differs.
		var y: float = row[0]; var w: float = row[1]; var f: float = row[2]; var r: float = row[3]
		rings.append([Vector3(-w,y,f),Vector3(w,y,f),Vector3(w,y,0),Vector3(w,y,r),Vector3(0,y,r),Vector3(-w,y,r),Vector3(-w,y,0),Vector3(-w,y,f)])
		# Replace the redundant final corner with the front midpoint, keeping perimeter order.
		rings[-1].remove_at(7)
		rings[-1].insert(1,Vector3(0,y,f))
	var center := Vector3(0,float(g.hull_rings[1][0]),0)
	for level in 2:
		for i in 8:
			var j := (i+1)%8
			var zone := "hull_front_"+("lower" if level == 0 else "upper") if i < 2 else "hull_sides_front"
			if i in [3,6]: zone = "hull_sides_rear"
			if i in [4,5]: zone = "hull_rear_"+("lower" if level == 0 else "upper")
			if level == 0 and i in [2,3,6,7]: zone = "hull_sides_lower"
			if level == 0 and i in [3,6]: zone = "hull_sides_lower_rear"
			face(out,packet,"hull_%d_%d"%[level,i],"hull",[rings[level][i],rings[level][j],rings[level+1][j],rings[level+1][i]],center,zone)
	# Roof has an actual turret-ring opening; the inside is not covered by another armor plane.
	var opening: Array = []
	var ring_half: float = g.ring_half
	var z: float = g.turret_origin[2]
	var roof_y: float = g.hull_rings[2][0]
	for p in [[-1,-1],[0,-1],[1,-1],[1,0],[1,1],[0,1],[-1,1],[-1,0]]:
		opening.append(Vector3(p[0]*ring_half,roof_y,z+p[1]*ring_half))
	for i in 8:
		var j := (i+1)%8
		face(out,packet,"hull_roof_%d"%i,"hull",[rings[2][i],rings[2][j],opening[j],opening[i]],center,"hull_roof_front" if i in [0,1,2,7] else "hull_roof_rear")
	declare_opening(out,"hull","turret_ring",opening)
	# Split the floor on the existing side midpoints so front and rear evidence stays distinct.
	face(out,packet,"floor_front","hull",[rings[0][0],rings[0][1],rings[0][2],rings[0][3],rings[0][7]],center,"hull_floor_front")
	face(out,packet,"floor_rear","hull",[rings[0][3],rings[0][4],rings[0][5],rings[0][6],rings[0][7]],center,"hull_floor_rear")
	var lower: Array = []; var upper: Array = []
	for p in g.turret_outline:
		lower.append(Vector3(p[0],g.turret_bottom,p[1]))
		upper.append(Vector3(p[0]*g.turret_taper,g.turret_top,p[1]*g.turret_taper))
	var tc := Vector3(0,(float(g.turret_bottom)+float(g.turret_top))*0.5,0)
	for i in lower.size():
		var j := (i+1)%lower.size()
		var outer := [lower[i],lower[j],upper[j],upper[i]]
		var edge: Vector3 = lower[j]-lower[i]
		var side_normal := Vector3(edge.z,0,-edge.x).normalized()
		var zone := "turret_front" if i == 0 else ("turret_rear" if side_normal.z > 0.40 else "turret_sides")
		if i == 0:
			# A hole in the front casting behind the separately moving gun shield.
			var inner: Array = []
			for uv in [[0.24,0.2],[0.76,0.2],[0.76,0.80],[0.24,0.80]]:
				inner.append((outer[0] as Vector3).lerp(outer[1],uv[0]).lerp((outer[3] as Vector3).lerp(outer[2],uv[0]),uv[1]))
			annulus(out,packet,"turret_front","turret",outer,inner,tc,zone)
			declare_opening(out,"turret","gun_aperture",inner)
		else: face(out,packet,"turret_wall_%d"%i,"turret",outer,tc,zone)
	if g.open_top: declare_opening(out,"turret","open_fighting_compartment",upper)
	else: face(out,packet,"turret_roof","turret",upper,tc,"turret_roof")
	declare_opening(out,"turret","turret_floor_ring",lower)
	var hw: float = g.mantlet_half_width; var hh: float = g.mantlet_half_height
	var outer := [Vector3(-hw,-hh,-0.10),Vector3(hw,-hh,-0.10),Vector3(hw,hh,-0.10),Vector3(-hw,hh,-0.10)]
	var bore := float(packet.assembly.caliber_mm)/2000.0
	var inner := [Vector3(-bore,-bore,-0.10),Vector3(bore,-bore,-0.10),Vector3(bore,bore,-0.10),Vector3(-bore,bore,-0.10)]
	if g.get("separate_rotor_shield",false):
		var offset := vec(g.gun_origin)
		var fixed_outer: Array = []; var aperture: Array = []
		for p in outer: fixed_outer.append(p+offset)
		for xy in [[-0.32,-0.23],[0.32,-0.23],[0.32,0.23],[-0.32,0.23]]: aperture.append(Vector3(xy[0],xy[1],-0.10)+offset)
		annulus(out,packet,"fixed_gun_shield","turret",fixed_outer,aperture,offset+Vector3(0,0,0.4),"gun_shield")
		declare_opening(out,"turret","fixed_shield_perimeter",fixed_outer)
		declare_opening(out,"turret","rotor_aperture",aperture)
		var rotor := [Vector3(-0.43,-0.29,-0.02),Vector3(0.43,-0.29,-0.02),Vector3(0.43,0.29,-0.02),Vector3(-0.43,0.29,-0.02)]
		var rotor_bore: Array = []
		for p in inner: rotor_bore.append(p+Vector3(0,0,0.08))
		annulus(out,packet,"rotor_shield","barrel",rotor,rotor_bore,Vector3(0,0,0.4),"rotor_shield")
		declare_opening(out,"barrel","rotor_perimeter",rotor)
		declare_opening(out,"barrel","gun_bore",rotor_bore)
	else:
		annulus(out,packet,"mantlet","barrel",outer,inner,Vector3(0,0,0.4),"gun_shield")
		declare_opening(out,"barrel","shield_perimeter",outer)
		declare_opening(out,"barrel","gun_bore",inner)
	for row in packet.modules:
		var m := ModuleVolumeDefinition.new()
		m.id = row.id; m.kind = row.kind; m.part_id = row.part
		m.local_box_transform.origin = vec(row.position); m.size_m = vec(row.size)
		m.external = row.get("external",false); m.geometry_status = "estimated"
		m.ammo_capacity = int(row.get("ammo_capacity",0))
		m.evidence_keys = PackedStringArray(["geometry.modules"])
		out.modules.append(m)
	for row in packet.crew:
		var c := CrewStationDefinition.new()
		c.id = row.id; c.role = row.role; c.part_id = row.part
		c.local_box_transform.origin = vec(row.position); c.size_m = vec(row.size)
		c.position_status = "estimated"; c.volume_status = "estimated"
		c.role_placement_status = packet.facts["crew.placement"].status
		c.evidence_keys = PackedStringArray(["crew.placement","geometry.crew"])
		out.crew_stations.append(c)
	return out

static func declare_opening(out: VehicleLayoutDefinition, part: String, id: String, loop: Array) -> void:
	out.declared_openings.append({"id":id,"part":part,"boundary_loop":loop.duplicate(),"reason":"Explicit reconstructed structural aperture; dimensions estimated"})

static func annulus(out: VehicleLayoutDefinition, packet: Dictionary, id: String, part: String, outer: Array, inner: Array, center: Vector3, zone: String) -> void:
	for i in outer.size():
		var j := (i+1)%outer.size()
		face(out,packet,id+"_%d"%i,part,[outer[i],outer[j],inner[j],inner[i]],center,zone)

static func face(out: VehicleLayoutDefinition, packet: Dictionary, id: String, part: String, points: Array, center: Vector3, zone: String) -> void:
	var vertices := points.duplicate()
	var n: Vector3 = (vertices[1]-vertices[0]).cross(vertices[2]-vertices[0]).normalized()
	# Collinear perimeter subdivisions are triangulated from the face centroid.
	if n.length_squared() < 0.5:
		for i in range(2,vertices.size()):
			n = (vertices[1]-vertices[0]).cross(vertices[i]-vertices[0]).normalized()
			if n.length_squared() > 0.5: break
	for v in vertices:
		if absf(n.dot(v-vertices[0])) > 0.00001:
			for i in range(1,vertices.size()-1): face(out,packet,id+"_t%d"%i,part,[vertices[0],vertices[i],vertices[i+1]],center,zone)
			return
	if n.dot(vertices[0]-center) < 0: vertices.reverse(); n = -n
	var p := ArmorPatchDefinition.new()
	p.id = id; p.plate_group_id = zone; p.part_id = part
	var centroid := Vector3.ZERO
	for v in vertices: centroid += v
	centroid /= vertices.size()
	p.vertices_local_m = PackedVector3Array(vertices)
	p.vertices_local_m.append(centroid)
	for i in vertices.size(): p.triangles.append_array(PackedInt32Array([vertices.size(),i,(i+1)%vertices.size()]))
	p.outward_normal_local = n
	var armor: Dictionary = packet.armor[zone]
	var evidence: Dictionary = packet.facts[armor.fact]
	p.has_thickness = evidence.status != "unknown"
	p.thickness_mm = float(armor.get("local_mm",evidence.value)) if p.has_thickness else 0.0
	p.thickness_status = "estimated" if armor.has("local_mm") else evidence.status
	p.geometry_status = "estimated"; p.material_kind = armor.get("material","rolled")
	p.evidence_keys = PackedStringArray([armor.fact,"geometry.exterior"])
	out.armor_patches.append(p)
