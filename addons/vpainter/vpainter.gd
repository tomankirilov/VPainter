@tool
extends EditorPlugin

const Painter = preload("res://addons/vpainter/core/mesh_painter.gd")
const PanelScene = preload("res://addons/vpainter/ui/vpainter_panel.tscn")
const ButtonScene = preload("res://addons/vpainter/ui/vpainter_button.tscn")
const DialogScene = preload("res://addons/vpainter/ui/vpainter_dialogs.tscn")
const ColorTransfer = preload("res://addons/vpainter/core/mesh_color_transfer.gd")
const MeshLODs = preload("res://addons/vpainter/core/mesh_lods.gd")
const MultiBrush = preload("res://addons/vpainter/core/multi_mesh_brush.gd")

var ui_activate_button: Button
var ui_sidebar: PanelContainer
var editor_selection: EditorSelection
var current_mesh: MeshInstance3D
var selected_meshes: Array[MeshInstance3D] = []
var stroke_meshes_before: Dictionary = {}
var stroke_tool := "Paint"
var process_drawing := false
var fill_pressed := false
var last_dab_ms: int = 0
var viewport_camera: Camera3D
var preview_mouse := Vector2.INF
var preview_camera_transform := Transform3D.IDENTITY
var ui_dialogs: Node
var color_clipboard: RefCounted
var reload_target: MeshInstance3D
var reload_before: Mesh
var reload_candidates: Array[Mesh] = []


func _get_plugin_icon() -> Texture2D:
	return ui_activate_button.icon if is_instance_valid(ui_activate_button) else null


func _enter_tree() -> void:
	ui_activate_button = ButtonScene.instantiate()
	ui_activate_button.toggled.connect(_on_button_toggled)
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, ui_activate_button)
	ui_sidebar = PanelScene.instantiate()
	ui_sidebar.custom_minimum_size.x *= EditorInterface.get_editor_scale()
	ui_sidebar.brush_preview_changed.connect(update_overlays)
	ui_sidebar.tool_changed.connect(_finish_stroke)
	ui_sidebar.copy_requested.connect(_copy_colors)
	ui_sidebar.paste_requested.connect(_paste_colors)
	ui_sidebar.reload_requested.connect(_open_reload)
	ui_sidebar.rebuild_lods_requested.connect(_rebuild_lods)
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_SIDE_LEFT, ui_sidebar)
	ui_dialogs = DialogScene.instantiate()
	add_child(ui_dialogs)
	ui_dialogs.get_node("MeshFile").file_selected.connect(_reload_file_selected)
	ui_dialogs.get_node("ChooseMesh").confirmed.connect(_reload_choice_confirmed)
	editor_selection = EditorInterface.get_selection()
	editor_selection.selection_changed.connect(_on_selection_changed)
	set_input_event_forwarding_always_enabled()
	_on_selection_changed()


func _exit_tree() -> void:
	_finish_stroke()
	if is_instance_valid(editor_selection):
		editor_selection.selection_changed.disconnect(_on_selection_changed)
	if is_instance_valid(ui_activate_button):
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, ui_activate_button)
		ui_activate_button.queue_free()
	if is_instance_valid(ui_sidebar):
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_SIDE_LEFT, ui_sidebar)
		ui_sidebar.queue_free()
	if is_instance_valid(ui_dialogs):
		ui_dialogs.queue_free()


func _handles(object: Object) -> bool:
	if object is MeshInstance3D:
		return true
	# The inspector uses MultiNodeEdit for a multiple-node selection.
	if object != null and object.get_class() == "MultiNodeEdit":
		for node in EditorInterface.get_selection().get_selected_nodes():
			if node is MeshInstance3D:
				return true
	return false


func _on_selection_changed() -> void:
	_finish_stroke()
	viewport_camera = null
	update_overlays()
	current_mesh = null
	selected_meshes.clear()
	var nodes := editor_selection.get_selected_nodes()
	for node in nodes:
		if node is MeshInstance3D:
			selected_meshes.append(node)
	if selected_meshes.size() == 1:
		current_mesh = selected_meshes[0]
	ui_activate_button.visible = not selected_meshes.is_empty()
	ui_activate_button.set_pressed_no_signal(false)
	ui_sidebar.hide()
	ui_sidebar.reset_tools()
	ui_sidebar.set_selection_actions(nodes.size() == 1 and selected_meshes.size() == 1, color_clipboard != null)


func _on_button_toggled(pressed: bool) -> void:
	_finish_stroke()
	ui_sidebar.visible = pressed
	update_overlays()


func _process(_delta: float) -> void:
	if not is_instance_valid(viewport_camera) or not ui_sidebar.is_painting():
		return
	var mouse := get_viewport().get_mouse_position()
	var camera_transform := viewport_camera.global_transform
	if mouse != preview_mouse or camera_transform != preview_camera_transform:
		preview_mouse = mouse
		preview_camera_transform = camera_transform
		update_overlays()


func _forward_3d_draw_over_viewport(overlay: Control) -> void:
	if not ui_sidebar.is_painting() or selected_meshes.is_empty() or not is_instance_valid(viewport_camera):
		return
	var mouse := overlay.get_local_mouse_position()
	if not Rect2(Vector2.ZERO, overlay.size).has_point(mouse):
		return
	# Convert between the editor overlay and the camera's render resolution.
	var viewport_size := viewport_camera.get_viewport().get_visible_rect().size
	if viewport_size.x <= 0 or viewport_size.y <= 0 or overlay.size.x <= 0 or overlay.size.y <= 0:
		return
	var camera_mouse := mouse * viewport_size / overlay.size
	var hit: Variant = _selection_hit(viewport_camera, camera_mouse)
	if hit == null:
		return
	var points := PackedVector2Array()
	var basis := viewport_camera.global_basis.orthonormalized()
	for segment in range(65):
		var angle := TAU * segment / 64.0
		var point: Vector3 = hit + (basis.x * cos(angle) + basis.y * sin(angle)) * ui_sidebar.brush_radius()
		if viewport_camera.is_position_behind(point):
			return
		points.append(viewport_camera.unproject_position(point) * overlay.size / viewport_size)
	# A dark outline keeps the radius visible against both light and dark meshes.
	overlay.draw_polyline(points, Color(0, 0, 0, 0.85), 4.0, true)
	overlay.draw_polyline(points, Color(1, 1, 1, 0.95), 2.0, true)


func _can_edit_node(node: MeshInstance3D) -> bool:
	if not is_instance_valid(node) or node.mesh == null:
		_show_message("Select a mesh with geometry.")
		return false
	if not (node.mesh is ArrayMesh or node.mesh is PrimitiveMesh):
		_show_message("Painting supports imported ArrayMesh and primitive meshes.")
		return false
	var root := EditorInterface.get_edited_scene_root()
	if root != null and not root.scene_file_path.is_empty() and not root.scene_file_path.ends_with(".tscn") and not root.scene_file_path.ends_with(".scn"):
		_show_message("Create an inherited scene before painting an imported scene.")
		return false
	if root != null and node != root and node.owner != root and not root.is_editable_instance(node.owner):
		_show_message("Enable Editable Children on the imported scene instance before painting.")
		return false
	return true


func _can_edit_selection() -> bool:
	if selected_meshes.is_empty():
		return false
	for node in selected_meshes:
		if not _can_edit_node(node):
			return false
	return true


func _has_single_mesh() -> bool:
	return selected_meshes.size() == 1 and is_instance_valid(current_mesh) and editor_selection.get_selected_nodes().size() == 1


func _can_edit() -> bool:
	if not _has_single_mesh():
		_show_message("This action requires exactly one selected mesh.")
		return false
	return _can_edit_node(current_mesh)


func _selection_hit(camera: Camera3D, mouse: Vector2) -> Variant:
	var origin := camera.project_ray_origin(mouse)
	var direction := camera.project_ray_normal(mouse)
	var nearest: Variant = null
	var distance := INF
	for node in selected_meshes:
		if not is_instance_valid(node) or node.mesh == null or not (node.mesh is ArrayMesh or node.mesh is PrimitiveMesh):
			continue
		var hit: Variant = Painter.hit_position(node.mesh, node.global_transform, origin, direction)
		if hit != null and origin.distance_squared_to(hit) < distance:
			distance = origin.distance_squared_to(hit)
			nearest = hit
	return nearest


func _fill_tool() -> void:
	_finish_stroke()
	if not _can_edit_selection():
		return
	var changes: Dictionary = {}
	for node in selected_meshes:
		var filled := Painter.fill(node.mesh, ui_sidebar.brush_strength(), ui_sidebar.brush_color(), ui_sidebar.channel_mask())
		if filled != null:
			changes[node] = filled
	_commit_mesh_changes(changes, "Fill vertex colors")


func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	viewport_camera = camera
	if event is InputEventMouse:
		update_overlays()
	if ui_sidebar.is_tool_active() and not selected_meshes.is_empty() and event is InputEventKey:
		if event.pressed and not event.alt_pressed and not event.ctrl_pressed and not event.meta_pressed:
			var key: int = event.keycode
			if key == KEY_X:
				if not event.echo:
					ui_sidebar.swap_colors()
				return AFTER_GUI_INPUT_STOP
			if ui_sidebar.is_painting() and (key == KEY_BRACKETLEFT or key == KEY_BRACKETRIGHT):
				ui_sidebar.scale_brush_radius(0.8 if key == KEY_BRACKETLEFT else 1.25)
				return AFTER_GUI_INPUT_STOP
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and fill_pressed:
		fill_pressed = false
		return AFTER_GUI_INPUT_STOP
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and process_drawing:
		_finish_stroke()
		return AFTER_GUI_INPUT_STOP
	if not ui_sidebar.is_tool_active() or selected_meshes.is_empty():
		_finish_stroke()
		return AFTER_GUI_INPUT_PASS
	if event is InputEventMouse and (event.alt_pressed or event.ctrl_pressed or event.meta_pressed):
		_finish_stroke()
		return AFTER_GUI_INPUT_PASS
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not _can_edit_selection():
			return AFTER_GUI_INPUT_STOP
		if ui_sidebar.active_tool() == "Fill":
			var hit: Variant = _selection_hit(camera, event.position)
			if hit == null:
				return AFTER_GUI_INPUT_PASS
			_fill_tool()
			fill_pressed = true
			return AFTER_GUI_INPUT_STOP
		process_drawing = true
		stroke_meshes_before.clear()
		for node in selected_meshes:
			stroke_meshes_before[node] = node.mesh
		stroke_tool = ui_sidebar.active_tool()
		_request_dab(camera, event.position, true)
		return AFTER_GUI_INPUT_STOP
	if event is InputEventMouseMotion and fill_pressed:
		if not event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			fill_pressed = false
			return AFTER_GUI_INPUT_PASS
		return AFTER_GUI_INPUT_STOP
	if event is InputEventMouseMotion and process_drawing:
		if not event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_finish_stroke()
		else:
			_request_dab(camera, event.position)
		return AFTER_GUI_INPUT_STOP
	return AFTER_GUI_INPUT_PASS


func _request_dab(camera: Camera3D, mouse: Vector2, first: bool = false) -> void:
	var now := Time.get_ticks_msec()
	if not first and now - last_dab_ms < ui_sidebar.dab_interval_ms():
		return
	last_dab_ms = now
	_dab(camera, mouse)


func _dab(camera: Camera3D, mouse: Vector2) -> void:
	var hit: Variant = _selection_hit(camera, mouse)
	if hit == null:
		return
	match ui_sidebar.active_tool():
		"Paint":
			_paint_tool(hit)
		"Blur":
			_blur_tool(hit)


func _paint_tool(hit_position: Vector3) -> void:
	for node in selected_meshes:
		if not is_instance_valid(node) or node.mesh == null:
			continue
		var painted := Painter.paint(node.mesh, node.global_transform, hit_position, ui_sidebar.brush_radius(), ui_sidebar.brush_strength(), ui_sidebar.brush_color(), ui_sidebar.channel_mask())
		if painted != null:
			node.mesh = painted


func _blur_tool(hit_position: Vector3) -> void:
	if selected_meshes.size() > 1:
		var changes := MultiBrush.blur(selected_meshes, hit_position, ui_sidebar.brush_radius(), ui_sidebar.brush_strength(), ui_sidebar.channel_mask())
		for node in changes:
			node.mesh = changes[node]
		return
	for node in selected_meshes:
		if not is_instance_valid(node) or node.mesh == null:
			continue
		var painted := Painter.blur(node.mesh, node.global_transform, hit_position, ui_sidebar.brush_radius(), ui_sidebar.brush_strength(), ui_sidebar.channel_mask())
		if painted != null:
			node.mesh = painted


func _finish_stroke() -> void:
	fill_pressed = false
	if not process_drawing:
		return
	process_drawing = false
	var changed: Array[MeshInstance3D] = []
	for node in stroke_meshes_before:
		if is_instance_valid(node) and node.mesh != stroke_meshes_before[node]:
			changed.append(node)
	if not changed.is_empty():
		var undo := get_undo_redo()
		undo.create_action("VPainter: %s vertex colors" % stroke_tool, UndoRedo.MERGE_DISABLE, changed[0])
		for node in changed:
			undo.add_do_property(node, "mesh", node.mesh)
			undo.add_undo_property(node, "mesh", stroke_meshes_before[node])
		undo.commit_action(false)
	stroke_meshes_before.clear()


func _show_message(message: String) -> void:
	var dialog: AcceptDialog = ui_dialogs.get_node("Message")
	dialog.dialog_text = message
	dialog.popup_centered()


func _replace_mesh(result: ArrayMesh, action: String) -> void:
	if result == null:
		_show_message("The mesh could not be processed. The color source needs triangle geometry.")
		return
	_commit_mesh_changes({current_mesh: result}, action)


func _commit_mesh_changes(changes: Dictionary, action: String) -> void:
	if changes.is_empty():
		return
	var undo := get_undo_redo()
	undo.create_action("VPainter: " + action, UndoRedo.MERGE_DISABLE, changes.keys()[0])
	for node in changes:
		_add_mesh_change(undo, node, changes[node])
	undo.commit_action()
	update_overlays()


func _add_mesh_change(undo: EditorUndoRedoManager, node: MeshInstance3D, result: ArrayMesh) -> void:
	undo.add_do_property(node, "mesh", result)
	undo.add_undo_property(node, "mesh", node.mesh)
	# Replacing geometry can truncate instance overrides and blend weights.
	# Record them after the mesh operation so undo restores the complete state.
	for surface in range(node.get_surface_override_material_count()):
		var material := node.get_surface_override_material(surface)
		undo.add_undo_method(node, "set_surface_override_material", surface, material)
		if surface < result.get_surface_count():
			undo.add_do_method(node, "set_surface_override_material", surface, material)
	var weights: Dictionary = {}
	for index in range(node.get_blend_shape_count()):
		var weight := node.get_blend_shape_value(index)
		weights[node.mesh.get_blend_shape_name(index)] = weight
		undo.add_undo_method(node, "set_blend_shape_value", index, weight)
	for index in range(result.get_blend_shape_count()):
		undo.add_do_method(node, "set_blend_shape_value", index, weights.get(result.get_blend_shape_name(index), 0.0))


func _copy_colors() -> void:
	_finish_stroke()
	# Copy is read-only and is also available on non-editable imported nodes.
	if not _has_single_mesh() or current_mesh.mesh == null or not (current_mesh.mesh is ArrayMesh or current_mesh.mesh is PrimitiveMesh):
		_show_message("Select a supported mesh to copy vertex colors.")
		return
	var snapshot := ColorTransfer.new()
	if not snapshot.capture(current_mesh.mesh):
		_show_message("Copy requires a mesh with triangle geometry.")
		return
	color_clipboard = snapshot
	ui_sidebar.set_selection_actions(true, true)


func _paste_colors() -> void:
	_finish_stroke()
	if not _can_edit():
		return
	if color_clipboard == null:
		_show_message("Copy vertex colors from a mesh first.")
		return
	_replace_mesh(color_clipboard.bake(current_mesh.mesh), "Paste vertex colors")


func _open_reload() -> void:
	_finish_stroke()
	if not _can_edit():
		return
	reload_target = current_mesh
	reload_before = current_mesh.mesh
	reload_candidates.clear()
	var dialog: EditorFileDialog = ui_dialogs.get_node("MeshFile")
	if not current_mesh.mesh.resource_path.is_empty():
		dialog.current_dir = current_mesh.mesh.resource_path.split("::")[0].get_base_dir()
	dialog.popup_centered_ratio(0.7)


func _reload_is_current() -> bool:
	if not is_instance_valid(reload_target) or reload_target != current_mesh or current_mesh.mesh != reload_before:
		_show_message("The selected mesh changed while choosing a file. Open Reload mesh again.")
		return false
	return _can_edit()


func _reload_file_selected(path: String) -> void:
	if not _reload_is_current():
		return
	# Ignore cached imports so Reload reads the latest resource on disk.
	var resource := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	reload_candidates.clear()
	var choice: OptionButton = ui_dialogs.get_node("ChooseMesh/MeshChoice")
	choice.clear()
	if resource is Mesh and (resource is ArrayMesh or resource is PrimitiveMesh):
		reload_candidates.append(resource)
		choice.add_item(path.get_file())
	elif resource is PackedScene:
		var root: Node = resource.instantiate()
		_collect_reload_meshes(root, root, choice)
		root.free()
	else:
		_show_message("Choose a Mesh resource or an imported scene containing meshes.")
		return
	if reload_candidates.is_empty():
		_show_message("The selected file contains no supported meshes.")
	elif reload_candidates.size() == 1:
		_reload_with_mesh(reload_candidates[0])
	else:
		choice.select(0)
		ui_dialogs.get_node("ChooseMesh").popup_centered()


func _collect_reload_meshes(node: Node, root: Node, choice: OptionButton) -> void:
	if node is MeshInstance3D and node.mesh != null and (node.mesh is ArrayMesh or node.mesh is PrimitiveMesh):
		reload_candidates.append(node.mesh)
		choice.add_item(str(root.get_path_to(node)) if node != root else str(node.name))
	for child in node.get_children():
		_collect_reload_meshes(child, root, choice)


func _reload_choice_confirmed() -> void:
	var choice: OptionButton = ui_dialogs.get_node("ChooseMesh/MeshChoice")
	if choice.selected >= 0 and choice.selected < reload_candidates.size():
		_reload_with_mesh(reload_candidates[choice.selected])


func _reload_with_mesh(replacement: Mesh) -> void:
	_finish_stroke()
	if not _reload_is_current():
		return
	var transfer := ColorTransfer.new()
	if not transfer.capture(reload_before):
		_show_message("Reload requires a current mesh with triangle geometry to transfer colors from.")
		return
	_replace_mesh(transfer.bake(replacement), "Reload mesh and bake vertex colors")
	reload_candidates.clear()
	reload_target = null
	reload_before = null


func _rebuild_lods() -> void:
	_finish_stroke()
	if not _can_edit_selection():
		return
	var changes: Dictionary = {}
	for node in selected_meshes:
		var rebuilt := MeshLODs.rebuild(node.mesh)
		if rebuilt == null:
			_show_message("A selected mesh could not rebuild LODs. No meshes were changed.")
			return
		changes[node] = rebuilt
	_commit_mesh_changes(changes, "Rebuild mesh LODs")
