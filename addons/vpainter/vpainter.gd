tool
extends EditorPlugin

var ui_sidebar
var ui_activate_button
var brush_cursor

var edit_mode:bool setget _set_edit_mode
var paint_color:Color

enum {MIX, ADD, SUBTRACT, MULTIPLY, DIVIDE}
var blend_mode = MIX

enum {PAINT, BLUR, FILL, SAMPLE, DISPLACE}
var current_tool = PAINT

var pressure_opacity:bool = false
var pressure_size:bool = false
var pen_pressure:float = 0.0
var pen_moving:bool = false

var brush_size:float = 1
var calculated_size:float = 0.0

var brush_opacity:float = 0.5
var calculated_opacity:float = 0.0

var brush_hardness:float = 0.0
var brush_spacing:float = 0.1
var brush_pressure:float = 0.0

var current_mesh:MeshInstance
var editable_object:bool = false

var process_drawing = false
var raycast_hit:bool = false
var hit_position
var hit_normal


func handles(obj) -> bool:
	return editable_object

func forward_spatial_gui_input(camera, event) -> bool:
	if !edit_mode:
		return true

	_raycast(camera, event)
	_calculate_pen_pressure(event)
	_display_brush()
	_user_input(event)
	
	return _handle_godot_ui(event)

func _handle_godot_ui(event) -> bool:
	if event is InputEventMouseButton:
		return true
	else:
		return false

func _user_input(event) -> void:
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT and event.is_pressed(): 
			process_drawing = true
			match current_tool:
				PAINT:
					_paint_tool()
				BLUR:
					_blur_tool()
				FILL:
					_fill_tool()
				SAMPLE:
					_sample_tool()
				DISPLACE:
					_displace_tool()
		else:
			process_drawing = false

func _display_brush() -> void:
	if raycast_hit:
		brush_cursor.translation = hit_position
		brush_cursor.scale = Vector3.ONE * calculated_size

func _calculate_pen_pressure(event):
	if process_drawing:
		brush_pressure = event.pressure

		if pressure_size:
			calculated_size = brush_size * brush_pressure
		else:
			calculated_size = brush_size

		if pressure_opacity:
			calculated_opacity = brush_opacity * brush_pressure
		else:
			calculated_opacity = brush_opacity
 
func _raycast(camera:Camera, event:InputEvent) -> void:
	#RAYCAST FROM CAMERA:
	var ray_origin = camera.project_ray_origin(event.position)
	var ray_dir = camera.project_ray_normal(event.position)
	var ray_distance = camera.far

	var space_state =  get_viewport().world.direct_space_state
	var hit = space_state.intersect_ray(ray_origin, ray_origin + ray_dir * ray_distance, [] , 524288 , true, false)
	#IF RAYCAST HITS A DRAWABLE SURFACE:
	if!hit:
		raycast_hit = false
		return
	if hit:
		raycast_hit = true
		hit_position = hit.position
		hit_normal = hit.normal

func _paint_tool() -> void:
	while process_drawing:
		var data = MeshDataTool.new()
		data.create_from_surface(current_mesh.mesh, 0)
	
		for i in range(data.get_vertex_count()):
			var vertex = current_mesh.to_global(data.get_vertex(i))

			if vertex.distance_to(hit_position) < calculated_size/2:
				#brush hardness:
				var vertex_proximity = vertex.distance_to(hit_position)/(calculated_size/2)
				var calculated_hardness = ((1 + brush_hardness/2) - vertex_proximity)
				
				
				match blend_mode:
					MIX:
						data.set_vertex_color(i, data.get_vertex_color(i).linear_interpolate(paint_color, calculated_opacity * calculated_hardness))
					ADD:
						data.set_vertex_color(i, data.get_vertex_color(i).linear_interpolate(data.get_vertex_color(i) + paint_color, calculated_opacity * calculated_hardness))
					SUBTRACT:
						data.set_vertex_color(i, data.get_vertex_color(i).linear_interpolate(data.get_vertex_color(i) - paint_color, calculated_opacity * calculated_hardness))
					MULTIPLY:
						data.set_vertex_color(i, data.get_vertex_color(i).linear_interpolate(data.get_vertex_color(i) * paint_color, calculated_opacity * calculated_hardness))
					DIVIDE:
						data.set_vertex_color(i, data.get_vertex_color(i).linear_interpolate(data.get_vertex_color(i) / paint_color,calculated_opacity * calculated_hardness))

		current_mesh.mesh.surface_remove(0)
		data.commit_to_surface(current_mesh.mesh)
		yield(get_tree().create_timer(brush_spacing), "timeout")

func _blur_tool() -> void:
	while process_drawing:
		var data = MeshDataTool.new()
		data.create_from_surface(current_mesh.mesh, 0)
	
		for i in range(data.get_vertex_count()):
			var vertex = current_mesh.to_global(data.get_vertex(i))

			if vertex.distance_to(hit_position) < calculated_size/2:
				#brush hardness:
				var vertex_proximity = vertex.distance_to(hit_position)/(calculated_size/2)
				var calculated_hardness = ((1 + brush_hardness/2) - vertex_proximity)
				

				data.set_vertex_color(i, data.get_vertex_color(i).linear_interpolate(paint_color, calculated_opacity * calculated_hardness))

		current_mesh.mesh.surface_remove(0)
		data.commit_to_surface(current_mesh.mesh)
		yield(get_tree().create_timer(brush_spacing), "timeout")

func _displace_tool() -> void:
	while process_drawing:
		var data = MeshDataTool.new()
		data.create_from_surface(current_mesh.mesh, 0)
	
		for i in range(data.get_vertex_count()):
			var vertex = current_mesh.to_global(data.get_vertex(i))

			if vertex.distance_to(hit_position) < calculated_size/2:
				#brush hardness:
				var vertex_proximity = vertex.distance_to(hit_position)/(calculated_size/2)
				var calculated_hardness = ((1 + brush_hardness/2) - vertex_proximity)

				data.set_vertex(i, data.get_vertex(i) + hit_normal * calculated_opacity * calculated_hardness)




		current_mesh.mesh.surface_remove(0)
		data.commit_to_surface(current_mesh.mesh)
		yield(get_tree().create_timer(brush_spacing), "timeout")
	pass

func _fill_tool() -> void:
	var data = MeshDataTool.new()
	data.create_from_surface(current_mesh.mesh, 0)
	
	for i in range(data.get_vertex_count()):
		var vertex = data.get_vertex(i)
		
		match blend_mode:
			MIX:
				data.set_vertex_color(i, data.get_vertex_color(i).linear_interpolate(paint_color, brush_opacity))
			ADD:
				data.set_vertex_color(i, data.get_vertex_color(i).linear_interpolate(data.get_vertex_color(i) + paint_color, brush_opacity))
			SUBTRACT:
				data.set_vertex_color(i, data.get_vertex_color(i).linear_interpolate(data.get_vertex_color(i) - paint_color, brush_opacity))
			MULTIPLY:
				data.set_vertex_color(i, data.get_vertex_color(i).linear_interpolate(data.get_vertex_color(i) * paint_color, brush_opacity))
			DIVIDE:
				data.set_vertex_color(i, data.get_vertex_color(i).linear_interpolate(data.get_vertex_color(i) / paint_color, brush_opacity))

	current_mesh.mesh.surface_remove(0)
	data.commit_to_surface(current_mesh.mesh)

func _sample_tool() -> void:
	var data = MeshDataTool.new()
	data.create_from_surface(current_mesh.mesh, 0)
	
	var closest_distance:float = INF
	var closest_vertex_index:int

	for i in range(data.get_vertex_count()):
		var vertex = current_mesh.to_global(data.get_vertex(i))

		if vertex.distance_to(hit_position) < closest_distance:
			closest_distance = vertex.distance_to(hit_position)
			closest_vertex_index = i
	
	var picked_color = data.get_vertex_color(closest_vertex_index)
	paint_color = Color(picked_color.r, picked_color.g, picked_color.b, 1)
	ui_sidebar._set_paint_color(paint_color)
	
	current_mesh.mesh.surface_remove(0)
	data.commit_to_surface(current_mesh.mesh)

func _set_collision(value:bool) -> void:
	if value:
		current_mesh.create_trimesh_collision()
		var temp_collision:StaticBody = current_mesh.get_node_or_null(current_mesh.name + "_col")
		if (temp_collision != null):
			temp_collision.set_collision_layer(524288)
			temp_collision.set_collision_mask(524288)
			
			temp_collision.hide()
	else:
		var temp_collision = current_mesh.get_node_or_null(current_mesh.name + "_col")
		if (temp_collision != null):
			temp_collision.free()

func _set_edit_mode(value) -> void:
	edit_mode = value
	#Generate temporary collision for vertex painting:
	if !current_mesh:
		return
		if (!current_mesh.mesh):
			return

	if edit_mode:
		_set_collision(true)
	else:
		ui_sidebar.hide()
		_set_collision(false)

func _make_local_copy() -> void:
	current_mesh.mesh = current_mesh.mesh.duplicate(false)

func _selection_changed() -> void:
	ui_activate_button._set_ui_sidebar(false)

	var selection = get_editor_interface().get_selection().get_selected_nodes()
	if selection.size() == 1 and selection[0] is MeshInstance:
		current_mesh = selection[0]
		if current_mesh.mesh == null:
			ui_activate_button._set_ui_sidebar(false)
			ui_activate_button._hide()
			editable_object = false
		else:
			ui_activate_button._show()
			editable_object = true
	else:
		editable_object = false
		ui_activate_button._set_ui_sidebar(false) #HIDE THE SIDEBAR
		ui_activate_button._hide()

func _enter_tree() -> void:
	#SETUP THE SIDEBAR:
	ui_sidebar = preload("res://addons/vpainter/vpainter_ui.tscn").instance()
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_SIDE_LEFT, ui_sidebar)
	ui_sidebar.hide()
	ui_sidebar.vpainter = self
	#SETUP THE EDITOR BUTTON:
	ui_activate_button = preload("res://addons/vpainter/vpainter_activate_button.tscn").instance()
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, ui_activate_button)
	ui_activate_button.hide()
	ui_activate_button.vpainter = self
	ui_activate_button.ui_sidebar = ui_sidebar
	#SELECTION SIGNAL:
	get_editor_interface().get_selection().connect("selection_changed", self, "_selection_changed")
	#LOAD BRUSH:
	brush_cursor = preload("res://addons/vpainter/res/brush_cursor/BrushCursor.tscn").instance()
	brush_cursor.visible = false
	add_child(brush_cursor)

func _exit_tree() -> void:
	#REMOVE THE SIDEBAR:
	remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_SIDE_LEFT, ui_sidebar)
	if ui_sidebar:
		ui_sidebar.free()
	#REMOVE THE EDITOR BUTTON:
	remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, ui_activate_button)
	if ui_activate_button:
		ui_activate_button.free()

