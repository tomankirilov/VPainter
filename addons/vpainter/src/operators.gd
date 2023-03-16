@tool
extends Node

var data:VPainterData
var collision_mask:int


var plugin:EditorPlugin
func _init(plugin:EditorPlugin):
	self.plugin = plugin
	data = load("res://addons/vpainter/data.tres")
	data.collision_mask_changed.connect(on_collision_mask_changed)


func on_collision_mask_changed(value:int) -> void:
	collision_mask = value

#OPERATORS:
func generate_collider() -> void:
	pass

func clean_collider() -> void:
	pass

func copy_color_data() -> void:
	pass

func paste_color_data() -> void:
	pass

func save_color_data() -> void:
	pass

func load_color_data() -> void:
	pass
