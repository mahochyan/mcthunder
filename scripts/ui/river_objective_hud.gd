class_name RiverObjectiveHUD
extends Control
var rows: Array[Dictionary] = []
var status := ""
const COLORS := {0:Color("d3bc77"),1:Color("85bfd2"),2:Color("d99572")}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	offset_left=-240; offset_right=240; offset_top=12; offset_bottom=100

func _draw() -> void:
	var width := size.x/3.0
	for i in rows.size():
		var row: Dictionary = rows[i]
		var rect := Rect2(i*width,0,width-6,60)
		var color: Color = COLORS[row.owner]
		if row.contested: color=Color("eac76b")
		draw_rect(rect,Color("10191de8"))
		draw_rect(Rect2(rect.position,Vector2(3,60)),color)
		var title := "%s  %s"%[row.id,RiverJunctionDefinition.OBJECTIVES[row.id].title]
		draw_string(CoreUI.FONT,rect.position+Vector2(12,23),title,HORIZONTAL_ALIGNMENT_LEFT,width-22,15,color)
		var label := "争夺中" if row.contested else ("中立" if row.owner==0 else ("友军控制" if row.owner==1 else "敌军控制"))
		draw_string(CoreUI.FONT,rect.position+Vector2(12,44),"%s  %d%%"%[label,roundi(absf(row.progress)*100)],HORIZONTAL_ALIGNMENT_LEFT,width-22,12,Color("dce1de"))
		draw_rect(Rect2(rect.position+Vector2(12,52),Vector2(width-30,3)),Color("394347"))
		draw_rect(Rect2(rect.position+Vector2(12,52),Vector2((width-30)*absf(row.progress),3)),COLORS[1 if row.progress>=0 else 2])
	draw_rect(Rect2(0,65,size.x-6,23),Color("10191de8"))
	draw_string(CoreUI.FONT,Vector2(10,81),status,HORIZONTAL_ALIGNMENT_LEFT,size.x-20,12,Color("c4cdcb"))
