tool
extends Control

var vpainter
#LOCAL COPY BUTTON
export var local_copy_button_path:NodePath
var local_copy_button

#COLOR PICKER:
export var color_picker_dir:NodePath
var color_picker:ColorPickerButton

#TOOLS:
export var button_select_dir:NodePath
var button_select:ToolButton

export var button_paint_dir:NodePath
var button_paint:ToolButton

export var button_blur_dir:NodePath
var button_blur:ToolButton

export var button_fill_dir:NodePath
var button_fill:ToolButton

#BRUSH SLIDERS:
export var brush_size_slider_dir:NodePath
var brush_size_slider:HSlider

export var brush_opacity_slider_dir:NodePath
var brush_opacity_slider:HSlider

export var brush_hardness_slider_dir:NodePath
var brush_hardness_slider:HSlider

export var brush_spacing_slider_dir:NodePath
var brush_spacing_slider:HSlider

#BLENDING MODES:
export var blend_modes_path:NodePath
var blend_modes:OptionButton

#MATERIAL PREVIEW:
export var button_m_path:NodePath
var button_m:ToolButton

export var button_r_path:NodePath
var button_r:ToolButton

export var button_g_path:NodePath
var button_g:ToolButton

export var button_b_path:NodePath
var button_b:ToolButton


func _enter_tree():
	local_copy_button = get_node(local_copy_button_path)
	local_copy_button.connect("button_down", self, "_make_local_copy")
	
	color_picker = get_node(color_picker_dir)
	color_picker.connect("color_changed", self, "_set_paint_color")
	
	button_select = get_node(button_select_dir)
	button_select.connect("toggled", self, "_set_select_tool")
	button_paint = get_node(button_paint_dir)
	button_paint.connect("toggled", self, "_set_paint_tool")
	button_blur = get_node(button_blur_dir)
	button_blur.connect("toggled", self, "_set_blur_tool")
	button_fill = get_node(button_fill_dir)
	button_fill.connect("toggled", self, "_set_fill_tool")

	brush_size_slider = get_node(brush_size_slider_dir)
	brush_size_slider.connect("value_changed", self, "_set_brush_size")
	brush_opacity_slider = get_node(brush_opacity_slider_dir)
	brush_opacity_slider.connect("value_changed", self, "_set_brush_opacity")
	brush_hardness_slider = get_node(brush_hardness_slider_dir)
	brush_hardness_slider.connect("value_changed", self, "_set_brush_hardness")
	brush_spacing_slider = get_node(brush_spacing_slider_dir)
	brush_spacing_slider.connect("value_changed", self, "_set_brush_spacing")
	
	blend_modes = get_node(blend_modes_path)
	blend_modes.connect("item_selected", self, "_set_blend_mode")
	blend_modes.clear()
	blend_modes.add_item("MIX", 0)
	blend_modes.add_item("ADD", 1)
	blend_modes.add_item("SUBTRACT", 2)
	blend_modes.add_item("MULTIPLY", 3)
	blend_modes.add_item("DIVIDE", 4)

	button_m = get_node(button_m_path)
	button_m.connect("toggled", self, "_set_preview_material")
	
	button_r = get_node(button_r_path)
	button_r.connect("toggled", self, "_set_r_channel")
	
	button_g = get_node(button_g_path)
	button_g.connect("toggled", self, "_set_g_channel")

	button_b = get_node(button_b_path)
	button_b.connect("toggled", self, "_set_b_channel")


	button_paint.set_pressed(true)

func _exit_tree():
	pass

func _make_local_copy():
	vpainter._make_local_copy()

func _set_paint_color(value):
	vpainter.paint_color = value

func _set_blend_mode(id):
	#MIX, ADD, SUBTRACT, MULTIPLY, DIVIDE
	match id:
		0: #MIX
			#print("BLEND MODE = MIX")
			vpainter.blend_mode = vpainter.MIX
		1: #ADD
			#print("BLEND MODE = ADD")
			vpainter.blend_mode = vpainter.ADD
		2: #SUBTRACT
			#print("BLEND MODE = SUBTRACT")
			vpainter.blend_mode = vpainter.SUBTRACT
		3: #MULTIPLY
			#print("BLEND MODE = MULTIPLY")
			vpainter.blend_mode = vpainter.MULTIPLY
		4: #DIVIDE
			#print("BLEND MODE = DIVIDE")
			vpainter.blend_mode = vpainter.DIVIDE

func _set_select_tool(value):
	if value:
		vpainter.current_tool = vpainter.SELECT
		#print("TOOL = SELCT")
		button_paint.set_pressed(false)
		button_blur.set_pressed(false)
		button_fill.set_pressed(false)
#	else:
#		vpainter._set_paint_mode(false)

func _set_paint_tool(value):
	if value:
		vpainter.current_tool = vpainter.PAINT
		#print("TOOL = PAINT")
		button_select.set_pressed(false)
		button_blur.set_pressed(false)
		button_fill.set_pressed(false)
#	else:
#		vpainter._set_paint_mode(false)

func _set_blur_tool(value):
	if value:
		vpainter.current_tool = vpainter.BLUR
		#print("TOOL = BLUR")
		button_select.set_pressed(false)
		button_paint.set_pressed(false)
		button_fill.set_pressed(false)
#	else:
#		vpainter._set_paint_mode(false)

func _set_fill_tool(value):
	if value:
		vpainter.current_tool = vpainter.FILL
		#print("TOOL = FILL")
		button_select.set_pressed(false)
		button_paint.set_pressed(false)
		button_blur.set_pressed(false)
		button_fill.set_pressed(true)
#	else:
#		vpainter._set_paint_mode(false)

func _set_brush_size(value):
	vpainter.brush_size = value
	#print("Brush size set: " + str(value))

func _set_brush_opacity(value):
	vpainter.brush_opacity = value
	#print("Brush opacity set: " + str(value))

func _set_brush_hardness(value):
	vpainter.brush_hardness = value
	#print("Brush hardness set: " + str(value))

func _set_brush_spacing(value):
	vpainter.brush_spacing = value
	#print("Brush spacing set: " + str(value))


func _set_preview_material(value):
	if value:
#		print("SET PREVIEW MATERAIAL:")
		vpainter._set_preview_material()
		_set_r_channel(value)
		_set_g_channel(value)
		_set_b_channel(value)
	else:
#		print("PREVIEW TURNED OFF")
		button_r.hide()
		button_g.hide()
		button_b.hide()
		vpainter._set_input_material()
		button_m.set_pressed(false)

func _set_r_channel(value):
	vpainter._preview_r(value)
	if value:
		button_r.show()
		button_r.set_pressed(true)
	else:
		button_r.set_pressed(false)

func _set_g_channel(value):
	vpainter._preview_g(value)
	if value:
		button_g.show()
		button_g.set_pressed(true)
	else:
		button_g.set_pressed(false)

func _set_b_channel(value):
	vpainter._preview_b(value)
	if value:
		button_b.show()
		button_b.set_pressed(true)
	else:
		button_b.set_pressed(false)

