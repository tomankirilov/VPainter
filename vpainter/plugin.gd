@tool
extends EditorPlugin

var raycast = load("res://addons/vpainter/src/raycast.gd").new()
var user_input = load("res://addons/vpainter/src/user_input.gd").new()


func _handles(object):
	if object is MeshInstance3D:
		return true
	else:
		return false

func _forward_3d_gui_input(viewport_camera, event):
	print("...")
	return


func _enter_tree():
	pass

func _exit_tree():
	pass
