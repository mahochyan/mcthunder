@tool
extends EditorPlugin

var exporter: EditorExportPlugin

func _enter_tree() -> void:
	exporter=preload("res://addons/bound_model_export/source_export.gd").new()
	add_export_plugin(exporter)

func _exit_tree() -> void:
	remove_export_plugin(exporter)
	exporter=null
