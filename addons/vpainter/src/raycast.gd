#RAYCAST FROM CAMERA:
@tool
extends Node


var is_hit:bool = false
var hit_position:Vector3
var hit_normal:  Vector3

var plugin:EditorPlugin
var data:VPainterData
var collision_mask:int = 524288


func _init(plugin:EditorPlugin) -> void:
	self.plugin = plugin
	data = load("res://addons/vpainter/data.tres")
	collision_mask = data.collision_mask
	data.collision_mask_changed.connect(on_collision_mask_changed)


func on_collision_mask_changed(value:int) -> void:
	collision_mask = value


func run(camera:Camera3D, event:InputEvent) -> void:
	if not event is InputEventMouse:
		return

	var direct_space_state := plugin.get_viewport().world_3d.direct_space_state

	var ray_origin = camera.project_ray_origin(event.position)
	var ray_dir = camera.project_ray_normal(event.position)
	var ray_distance = camera.far

	var p = PhysicsRayQueryParameters3D.new()
	p.from = ray_origin
	p.to = ray_origin + ray_dir * ray_distance
	p.set_collision_mask(collision_mask)

	var _hit = direct_space_state.intersect_ray(p)
	#IF RAYCAST HITS A DRAWABLE SURFACE:
	if _hit.size() == 0:
		is_hit = false
		return
	if _hit:
		is_hit = true
		hit_position = _hit.position
		hit_normal = _hit.normal

#		print(hit_position)
