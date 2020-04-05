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

func _enter_tree():
	local_copy_button = get_node(local_copy_button_path)
	local_copy_button.connect("button_down", self, "_make_local_copy")
	
	color_picker = get_node(color_picker_dir)
	color_picker.connect("color_changed", self, "_set_paint_color")
	
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

func _set_paint_tool(value):
	if value:
		vpainter.current_tool = vpainter.PAINT
		#print("TOOL = PAINT")
		button_blur.set_pressed(false)
		button_fill.set_pressed(false)

func _set_blur_tool(value):
	if value:
		vpainter.current_tool = vpainter.BLUR
		#print("TOOL = BLUR")
		button_paint.set_pressed(false)
		button_fill.set_pressed(false)


func _set_fill_tool(value):
	if value:
		vpainter.current_tool = vpainter.FILL
		#print("TOOL = FILL")
		button_paint.set_pressed(false)
		button_blur.set_pressed(false)
		button_fill.set_pressed(true)


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

