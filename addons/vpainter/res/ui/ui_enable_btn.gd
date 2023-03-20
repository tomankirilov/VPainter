@tool
extends Button

var plugin:EditorPlugin


func _enter_tree() -> void:
	hide()
	button_down.connect(on_button_down)
	plugin.selection_editable.connect(on_selection_is_editable)


func on_selection_is_editable(value):
	if value:
		show()
	else:
		hide()

func on_button_down() -> void:
	plugin.is_edit_mode = !plugin.is_edit_mode
