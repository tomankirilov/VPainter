@tool
extends Control

var plugin


func _enter_tree():
	hide()
	plugin.edit_mode_changed.connect(on_edit_mode_changed)
	plugin.selection_editable.connect(on_selection_is_editable)


func on_selection_is_editable(value):
	if value:
		show()
	else:
		hide()

func on_edit_mode_changed(value:bool) -> void:
	if value:
		show()
	else:
		hide()
