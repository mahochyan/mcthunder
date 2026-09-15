extends SceneTree
## WT-040-R1 step 3: the armour draft, prepared so that a ruling can land immediately - and marked
## as awaiting that ruling, because the mapping from the dossiers' War Thunder node names onto the
## project's seventeen zones IS a judgement, not a copy.
##
## Every zone names the dossier node it came from, that node's line, its thickness and its armour class,
## exactly as the two mapping documents record. Facts are emitted with the line reference the dossier
## provides, material_kind is mapped onto the project's vocabulary, and anything whose class has no
## honest project equivalent becomes "unknown" rather than being forced. Nothing is registered, no
## config is touched, and the fact status says so: reference_pending_review.
##
## Deliberately absent: dimensions. The dossiers have none, and my own measurement must not serve as
## the reference for the validator's envelope cross-check.
##
## Usage: -s res://tests/build_modern_armor_draft.gd
const OUT := "res://logs/WT-040-R1/modern_armor_draft.json"
const SOURCE_LABEL := "warthunder_reference"
const SOURCE_VERSION := "2.57.1.137"
## zone -> [dossier node, line, mm, armour class, note]
const MAP_T80B := {
	"hull_front_upper": ["body_front_dm", 51, 80, "", "the dossier does not split upper from lower front, so both take this value"],
	"hull_front_lower": ["body_front_dm", 51, 80, "", "same node as the upper front (no split in the dossier)"],
	"hull_sides_front": ["body_side_dm", 53, 80, "", ""],
	"hull_sides_rear": ["body_side_dm", 53, 80, "", "the dossier does not split front from rear side"],
	"hull_sides_lower": ["body_side_dm", 53, 80, "", "the dossier does not split upper from lower side"],
	"hull_sides_lower_rear": ["body_side_dm", 53, 80, "", "same as the other side zones"],
	"hull_rear_upper": ["body_back_dm", 58, 60, "", "superstructure_back_dm (50 mm, line 59) also exists"],
	"hull_rear_lower": ["body_back_dm", 58, 60, "", "same node as the upper rear"],
	"hull_roof_front": ["body_top_dm", 54, 30, "", ""],
	"hull_roof_rear": ["body_top_dm", 54, 30, "", "the dossier does not split front from rear roof"],
	"hull_floor_front": ["body_bottom_dm", 56, 20, "", ""],
	"hull_floor_rear": ["body_bottom_dm", 56, 20, "", "the dossier does not split front from rear floor"],
	"turret_front": ["turret_front_dm", 91, 250, "CHA_tank_modern", "turret_01_front_dm (250 mm, line 89) carries the same figure"],
	"turret_sides": ["turret_side_dm", 90, 157, "CHA_tank_modern", "multi-segment in the dossier (125/160/90); a representative value had to be chosen - this is the reviewable part"],
	"turret_rear": ["turret_back_dm", 88, 90, "CHA_tank_modern", "turret_01_back_dm (65 mm, line 82) also exists"],
	"turret_roof": ["turret_03_top_dm", 80, 90, "CHA_tank_modern", "multi-segment (45/60/140/30); representative value chosen"],
	"gun_shield": ["gun_mask_01_dm", 94, 50, "CHA_tank_modern", "gun_mask_02_dm (90 mm, line 95) also exists"],
}
const MAP_LEOPARD := {
	"hull_front_upper": ["body_front_dm", 44, 400, "leopard_2a5_turret_nera", "node name says body but the class says turret NERA - flagged for review rather than smoothed over"],
	"hull_front_lower": ["superstructure_front_dm", 48, 35, "RHAHH_tank", ""],
	"hull_sides_front": ["superstructure_side_dm", 49, 40, "RHAHH_tank", ""],
	"hull_sides_rear": ["body_side_dm", 55, 35, "RHA_tank_modern", ""],
	"hull_sides_lower": ["body_side_dm", 55, 35, "RHA_tank_modern", ""],
	"hull_sides_lower_rear": ["body_side_dm", 55, 35, "RHA_tank_modern", ""],
	"hull_rear_upper": ["superstructure_back_dm", 60, 20, "RHA_tank_modern", ""],
	"hull_rear_lower": ["body_back_dm", 61, 20, "RHA_tank_modern", ""],
	"hull_roof_front": ["superstructure_top_dm", 50, 35, "RHA_tank_modern", ""],
	"hull_roof_rear": ["body_top_dm", 62, 20, "RHA_tank_modern", ""],
	"hull_floor_front": ["superstructure_bottom_dm", 56, 20, "RHA_tank_modern", ""],
	"hull_floor_rear": ["body_bottom_dm", 58, 20, "RHA_tank_modern", ""],
	"turret_front": ["turret_09_front_dm", 113, 250, "CHA_tank_modern", "effective maximum 250"],
	"turret_sides": ["turret_07_side_dm", 99, 160, "CHA_tank_modern", "effective maximum 160; multi-segment, representative value chosen"],
	"turret_rear": ["turret_07_back_dm", 76, 40, "RHA_tank_modern", "turret_01_back_dm (25 mm, line 74) also exists"],
	"turret_roof": ["turret_07_top_dm", 75, 40, "RHA_tank_modern", ""],
	"gun_shield": ["gun_mask_05_dm", 139, 50, "RHA_tank_modern", "the mask group holds seven rows"],
}
## dossier armourClass -> the project's material_kind; anything without an honest equivalent is unknown
const MATERIAL := {
	"RHA_tank_modern": "rolled",
	"RHAHH_tank": "rolled",
	"CHA_tank_modern": "cast",
	"t_80b_composite_armor": "composite",
	"leopard_2a5_turret_nera": "composite",
}
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var rows: Array[Dictionary] = [_build("ussr_t_80b",MAP_T80B),_build("germ_leopard_2a4",MAP_LEOPARD)]
	var file := FileAccess.open(OUT,FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"schema":1,
			"note":"armour draft AWAITING REVIEW: the seventeen-zone mapping is a judgement from War Thunder node names onto the project's zones; status is reference_pending_review and nothing is registered or admitted",
			"rows":rows}, "  ")+"\n")
		file.close()
		print("[armor] wrote ",OUT)
	print("MODERN_ARMOR_DRAFT_DONE")
	quit(0)

func _build(id: String, table: Dictionary) -> Dictionary:
	var out := {"id":id,"armor":{},"facts":{},"notes":[],"zones":0}
	var unknown_material := 0
	for zone in table.keys():
		var row: Array = table[zone]
		var node := str(row[0])
		var line := int(row[1])
		var mm := float(row[2])
		var klass := str(row[3])
		var note := str(row[4])
		var material := str(MATERIAL.get(klass,"unknown"))
		if material == "unknown": unknown_material += 1
		out.armor[zone] = {"fact":"armor."+zone, "material":material}
		out.facts["armor."+zone] = {
			"value": mm,
			"status": "reference_pending_review",
			"origin": SOURCE_LABEL,
			"source_refs": ["wt-%s#L%d" % [SOURCE_VERSION,line]],
			"location": "%s line %d: %s armorThickness=%s%s" % [SOURCE_LABEL,line,node,str(mm),("" if klass.is_empty() else " armorClass="+klass)],
		}
		if not note.is_empty(): out.armor[zone]["mapping_note"] = note
		out.zones += 1
	out.notes.append("%d zones mapped, each with the dossier node and line it came from" % out.zones)
	out.notes.append("%d zone(s) got material 'unknown' because their armour class has no honest project equivalent; nothing was forced" % unknown_material)
	out.notes.append("the mapping is AWAITING REVIEW: the dossier is coarser than the project in places and multi-segment for the turret sides and roof, so representative values were chosen and named")
	out.notes.append("dimensions are deliberately absent: the dossiers have none and my own measurement must not be the reference for the envelope cross-check")
	return out
