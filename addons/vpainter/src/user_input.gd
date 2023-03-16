@tool
extends Node

signal mouse_moved
var is_mouse_moving:bool = false
var mouse_screen_position:Vector2

signal lmb_down
signal lmb_up
var is_lmb_down:bool = false


var is_shift_down:bool = false
signal shift_down
signal shift_up

var is_ctrl_down:bool = false
signal ctrl_down
signal ctrl_up

var is_bracketleft_down:bool = false
signal bracketleft_down
signal bracketleft_up

var is_bracketright_down:bool = false
signal bracketright_down
signal bracketright_up


var plugin:EditorPlugin
func _init(plugin:EditorPlugin):
	self.plugin = plugin


func run(event :InputEvent) -> int:
########################################################
#       MOUSE BUTTON        ############################
	if event is InputEventMouse:
		is_mouse_moving = true
		mouse_screen_position = event.position
		mouse_moved.emit()
	else:
		is_mouse_moving = false

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			is_lmb_down = true
			print("LMB Down")
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		else:
			is_lmb_down = false
			print("LMB Up")
			return EditorPlugin.AFTER_GUI_INPUT_PASS




########################################################
#       BRACKETS            ############################
	if event is InputEventKey and event.get_keycode() == KEY_BRACKETLEFT:
		if event.is_pressed():
			is_bracketleft_down = true
			print("BRACKETLEFT is DOWN")
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		else:
			is_bracketleft_down = false
			print("BRACKETLEFT is UP")
			return EditorPlugin.AFTER_GUI_INPUT_PASS

	if event is InputEventKey and event.get_keycode() == KEY_BRACKETRIGHT:
		if event.is_pressed():
			is_bracketright_down = true
			print("BRACKETRIGHT is DOWN")
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		else:
			is_bracketright_down = false
			print("BRACKETRIGHT is UP")
			return EditorPlugin.AFTER_GUI_INPUT_PASS

########################################################
#       MODIFIERS           ############################

	if event is InputEventKey and event.get_keycode() == KEY_CTRL:
		if event.is_pressed() and !event.is_echo():
			is_ctrl_down = true
#			events.emit_signal("ctrl_down")
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		elif !event.is_pressed() and !event.is_echo():
			is_ctrl_down = false
#			events.emit_signal("ctrl_up")
			return EditorPlugin.AFTER_GUI_INPUT_PASS
		else:
			return EditorPlugin.AFTER_GUI_INPUT_PASS

	if event is InputEventKey and event.get_keycode() == KEY_SHIFT:
		if event.is_pressed() and !event.is_echo():
			is_shift_down = true
#			events.emit_signal("shift_down")
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		elif !event.is_pressed() and !event.is_echo():
			is_shift_down = false
#			events.emit_signal("shift_up")
			return EditorPlugin.AFTER_GUI_INPUT_PASS
		else:
			return EditorPlugin.AFTER_GUI_INPUT_PASS
########################################################
########################################################
	else:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
