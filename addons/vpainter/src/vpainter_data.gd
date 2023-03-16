@tool
extends Resource
class_name VpainterData

signal active_tool_changed(value:int)
@export var active_tool:int = 0:
	set(value):
		active_tool = value
		emit_signal("active_tool_changed", value)


signal edit_r_changed(value:bool)
@export var edit_r:bool = true:
	set(value):
		edit_r = value
		emit_signal("edit_r_changed", value)

signal edit_g_changed(value:bool)
@export var edit_g:bool = true:
	set(value):
		edit_g = value
		emit_signal("edit_g_changed", value)

signal edit_b_changed(value:bool)
@export var edit_b:bool = true:
	set(value):
		edit_b = value
		emit_signal("edit_b_changed", value)

signal edit_a_changed(value:bool)
@export var edit_a:bool = true:
	set(value):
		edit_a = value
		emit_signal("edit_a_changed", value)


signal brush_size_changed(value:float)
@export var brush_size:float = 1.0:
	set(value):
		brush_size = value
		emit_signal("brush_size_changed", value)


signal brush_opacity_changed(value:float)
@export var brush_opacity:float = 1.0:
	set(value):
		brush_opacity = value
		emit_signal("brush_opacity_changed", value)


signal brush_spacing_changed(value:float)
@export var brush_spacing:float = 1.0:
	set(value):
		brush_spacing = value
		emit_signal("brush_spacing_changed", value)


signal brush_falloff_changed(value:float)
@export var brush_falloff:float = 1.0:
	set(value):
		brush_falloff = value
		emit_signal("brush_falloff_changed", value)


signal paint_color_changed(value:Color)
@export var paint_color:Color = Color.WHITE:
	set(value):
		paint_color = value
		emit_signal("paint_color_changed", value)


signal erase_color_changed(value:Color)
@export var erase_color:Color = Color.BLACK:
	set(value):
		erase_color = value
		emit_signal("erase_color_changed", value)


@export_flags_3d_physics var collision_layer = 524288
