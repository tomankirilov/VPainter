@tool
extends EditorPlugin

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


var process_painting:bool = false
func on_lmb_down():
	if !input.is_ctrl_down:
		if data.active_tool == 0:
			process_painting = true
			paint(data.paint_color, data.brush_opacity, data.brush_spacing, data.brush_falloff)
		else:
			fill(data.paint_color, data.brush_opacity)
			print('Filling meshes with paint color.')
	else: #ctrl is pressed
		if data.active_tool == 0:
			process_painting = true
			paint(data.paint_color, data.brush_opacity, data.brush_spacing, data.brush_falloff)
		else:
			fill(data.erase_color, data.brush_opacity)
			print('Filling meshes with erase color.')

func on_lmb_up():
	process_painting = false



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
func fill(color:Color, opacity:float) -> void:

	for mesh_instance in plugin.selection:
		var mdtool:MeshDataTool = MeshDataTool.new()
		var mesh:Mesh = mesh_instance.mesh as Mesh
		mdtool.create_from_surface(mesh, 0)

		for id in range(mdtool.get_vertex_count()):
			var current_color := mdtool.get_vertex_color(id)
			var desired_color := current_color

			if data.edit_r:
				desired_color.r = color.r
			if data.edit_g:
				desired_color.g = color.g
			if data.edit_b:
				desired_color.b = color.b
			if data.edit_a:
				desired_color.a = color.a

			var result_color  := lerp(current_color, desired_color, opacity)

			mdtool.set_vertex_color(id, result_color)
		
		mesh.clear_surfaces()
		mdtool.commit_to_surface(mesh)


func paint(color:Color, opacity:float, spacing:float, falloff:float) -> void:
	while process_painting:
		for mesh_instance in plugin.selection:
			var mdtool:MeshDataTool = MeshDataTool.new()
			var mesh:Mesh = mesh_instance.mesh as Mesh
			mdtool.create_from_surface(mesh, 0)

			for id in range(mdtool.get_vertex_count()):
				
				var vertex = mdtool.to_global(data.get_vertex(id))
				var current_color := mdtool.get_vertex_color(id)
				var desired_color := current_color

				if data.edit_r:
					desired_color.r = color.r
				if data.edit_g:
					desired_color.g = color.g
				if data.edit_b:
					desired_color.b = color.b
				if data.edit_a:
					desired_color.a = color.a

				var result_color  := lerp(current_color, desired_color, opacity)

				mdtool.set_vertex_color(id, result_color)
			
			mesh.clear_surfaces()
			mdtool.commit_to_surface(mesh)
		print("PAINTING..")
		await get_tree().create_timer(spacing).timeout


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
