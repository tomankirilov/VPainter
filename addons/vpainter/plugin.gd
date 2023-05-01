@tool
extends EditorPlugin


var selection:Array

signal selection_editable(value:bool)
var is_selection_editable:bool = false:
	set(value):
		is_selection_editable = value
		selection_editable.emit(value)

signal edit_mode_changed(value:bool)
var is_edit_mode:bool = false:
	set(value):
		is_edit_mode = value
		edit_mode_changed.emit(value)




var raycast    = load("res://addons/vpainter/src/raycast.gd").new(self)
var user_input = load("res://addons/vpainter/src/user_input.gd").new(self)
var operators  = load("res://addons/vpainter/src/operators.gd").new(self)


var brush_cursor
var ui_enable_button
var ui_sidebar


func _handles(object):
	if object is MeshInstance3D:
		return true
	else:
		return false


func _forward_3d_gui_input(viewport_camera:Camera3D, event:InputEvent) -> int:
	if is_selection_editable and is_edit_mode:
		raycast.run(viewport_camera, event)
		return user_input.run(event)
	else:
		return EditorPlugin.AFTER_GUI_INPUT_PASS

func on_selection_changed():
	selection = get_editor_interface().get_selection().get_selected_nodes()

	if selection.size() == 0:
		is_selection_editable = false
		#Selection is empty.
		return

	for node in selection:
		if not node is MeshInstance3D:
			is_selection_editable = false
			is_edit_mode = false
			#Selection contains a node that is not a MeshInstance3D.
			break
		else:
			is_selection_editable = true
			is_edit_mode = false
			#Selection is editable.


func _enter_tree():
	get_editor_interface().get_selection().selection_changed.connect(on_selection_changed)

	ui_enable_button = load("res://addons/vpainter/res/ui/ui_enable_btn.tscn").instantiate()
	ui_enable_button.plugin = self
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, ui_enable_button)

	ui_sidebar = load("res://addons/vpainter/res/ui/ui_sidebar.tscn").instantiate()
	ui_sidebar.plugin = self
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_SIDE_LEFT, ui_sidebar)

	operators.name = "Operators"
	add_child(operators)

	brush_cursor = load("res://addons/vpainter/res/brush_cursor/brush_cursor.tscn").instantiate()
	add_child(brush_cursor)

func _exit_tree():
	print_tree()
	remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, ui_enable_button)
	remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_SIDE_LEFT, ui_sidebar)
