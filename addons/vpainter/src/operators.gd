@tool
extends Node3D

var data:VPainterData
var collision_mask:int
var collision_parent:StaticBody3D

var plugin:EditorPlugin
var raycast
var input

func _init(plugin:EditorPlugin):
	self.plugin = plugin
	data = load("res://addons/vpainter/data.tres")
	data.collision_mask_changed.connect(on_collision_mask_changed)
	input = plugin.user_input
	raycast = plugin.raycast

	input.lmb_down.connect(on_lmb_down)
	input.lmb_up.connect(on_lmb_up)
	plugin.edit_mode_changed.connect(on_edit_mode_changed)


func on_lmb_down():
	if input.is_ctrl_down:
		print('start paint process')
	else:
		print('start paint process')

func on_lmb_up():
	print('stop brush process')



func on_collision_mask_changed(value:int) -> void:
	collision_mask = value

func on_edit_mode_changed(value):
	if value:
		generate_collider()
	else:
		clean_colliders()

func _enter_tree():
	pass


#OPERATORS:

func fill() -> void:
	pass

func paint() -> void:
	pass

func erase() -> void:
	pass

func generate_collider() -> void:

	collision_parent = StaticBody3D.new()
	collision_parent.set_collision_layer(data.collision_mask)
	collision_parent.name = "CollisionParent"
	plugin.add_child(collision_parent)
	collision_parent.set_owner(plugin)

	var selection = plugin.get_editor_interface().get_selection().get_selected_nodes()
	for node in selection:
		if not node is MeshInstance3D:
			return
		if node.mesh == null:
			return

		node.create_trimesh_collision()
		var static_body = node.get_node(node.name + "_col")
		var collider    = static_body.get_child(0)
		var node_transform = node.transform
		
		static_body.remove_child(collider)

		collision_parent.add_child(collider)
		collider.set_owner(collision_parent)
		collider.transform = node_transform
		static_body.queue_free()


func clean_colliders() -> void:
	if collision_parent == null:
		return

	for child in collision_parent.get_children():
		print(child.name)
		child.queue_free()

	collision_parent.queue_free()


func copy_color_data() -> void:
	pass

func paste_color_data() -> void:
	pass
