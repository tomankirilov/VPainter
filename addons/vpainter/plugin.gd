@tool
extends EditorPlugin


var selection:Array
var is_selection_editable:bool = false
var edit_mode:bool = true

var raycast    = load("res://addons/vpainter/src/raycast.gd").new(self)
var user_input = load("res://addons/vpainter/src/user_input.gd").new(self)
var operators  = load("res://addons/vpainter/src/operators.gd").new(self)


func _handles(object):
	if !is_selection_editable:
		return false
	if !edit_mode:
		return false

	if object is MeshInstance3D:
		return true
	else:
		return false


func _forward_3d_gui_input(viewport_camera:Camera3D, event:InputEvent) -> int:
	raycast.run(viewport_camera, event)
	return user_input.run(event)


func on_selection_changed():
	var selection :Array = get_editor_interface().get_selection().get_selected_nodes()

	if selection.size() == 0:
		#Selection is empty.
		return

	for node in selection:
		if not node is MeshInstance3D:
			is_selection_editable = false
			#Selection contains a node that is not a MeshInstance3D.
			break
		else:
			is_selection_editable = true
			#Selection is editable.


func _enter_tree():
	get_editor_interface().get_selection().selection_changed.connect(on_selection_changed)

func _exit_tree():
	raycast.queue_free()
	user_input.queue_free()
