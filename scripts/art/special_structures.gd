class_name SpecialStructures
extends RefCounted
## Symmetric optional yard structures; permanent spawn screens and authored roads stay intact.
static func placements(map: MapDefinition) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var industrial := map.id == "industrial_edge_023"
	if not industrial and map.id != "hill_village_018": return rows
	for side in [-1,1]:
		rows.append({"id":"shed_%d"%side,"style":"wood","position":Vector3(side*(132 if industrial else 125),0,side*(145 if industrial else 125))})
		rows.append({"id":"brick_screen_%d"%side,"style":"brick","position":Vector3(side*(132 if industrial else 121),0,side*(120 if industrial else 106))})
	return rows

static func build(parent: Node3D, map: MapDefinition) -> void:
	for row in placements(map):
		var assembly := Node3D.new(); assembly.name = "Special_"+str(row.id); assembly.position = row.position
		parent.add_child(assembly)
		var count := 1 if row.style == "wood" else 3
		for i in count:
			var section := DestructibleSection.new(); assembly.add_child(section)
			section.position.x = (i-(count-1)*0.5)*5.2
			section.setup(map.id+"/"+row.id,"Section%d"%i,row.style,Vector3(8,3.8,6) if row.style=="wood" else Vector3(5.2,2.8,0.7))
