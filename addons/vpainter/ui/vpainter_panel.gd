@tool
extends PanelContainer

signal brush_preview_changed
signal tool_changed
signal copy_requested
signal paste_requested
signal reload_requested
signal rebuild_lods_requested


func _ready() -> void:
	%SwapColors.pressed.connect(swap_colors)
	%Radius.value_changed.connect(func(_value: float) -> void: brush_preview_changed.emit())
	%Tool.item_selected.connect(_on_tool_selected)
	%FileMenu.get_popup().id_pressed.connect(_on_file_menu)
	%EditMenu.get_popup().id_pressed.connect(_on_edit_menu)


func _on_file_menu(id: int) -> void:
	if id == 0:
		reload_requested.emit()
	elif id == 1:
		rebuild_lods_requested.emit()


func _on_edit_menu(id: int) -> void:
	if id == 0:
		copy_requested.emit()
	elif id == 1:
		paste_requested.emit()


func set_selection_actions(single_mesh: bool, has_clipboard: bool) -> void:
	%EditMenu.get_popup().set_item_disabled(0, not single_mesh)
	%EditMenu.get_popup().set_item_disabled(1, not single_mesh or not has_clipboard)
	%FileMenu.get_popup().set_item_disabled(0, not single_mesh)


func _on_tool_selected(_index: int) -> void:
	tool_changed.emit()
	brush_preview_changed.emit()


func reset_tools() -> void:
	%Tool.select(0)


func is_painting() -> bool:
	return visible and active_tool() != "Fill"


func is_tool_active() -> bool:
	return visible


func active_tool() -> String:
	return %Tool.get_item_text(%Tool.selected)


func brush_color() -> Color:
	return %Color.color


func swap_colors() -> void:
	var previous: Color = %Color.color
	%Color.color = %SecondaryColor.color
	%SecondaryColor.color = previous


func brush_radius() -> float:
	return %Radius.value


func scale_brush_radius(factor: float) -> void:
	%Radius.value = clampf(%Radius.value * factor, %Radius.min_value, %Radius.max_value)


func brush_strength() -> float:
	return %Strength.value


func dab_interval_ms() -> float:
	# A rate of 1 applies at most 100 dabs/second; 0.1 keeps the original 10.
	var rate := clampf(%PaintRate.value, 0.001, 1.0)
	return 1000.0 / (rate * 100.0)


func channel_mask() -> Array[bool]:
	return [%R.button_pressed, %G.button_pressed, %B.button_pressed, %A.button_pressed]
