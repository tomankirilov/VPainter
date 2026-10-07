@tool
extends RefCounted

const Painter = preload("res://addons/vpainter/core/mesh_painter.gd")
const Transfer = preload("res://addons/vpainter/core/mesh_color_transfer.gd")


static func rebuild(source: Mesh) -> ArrayMesh:
	var local := Painter.copy_mesh(source)
	var importer := ImporterMesh.from_mesh(local)
	importer.generate_lods(60.0, 0.0, [])
	var generated := importer.get_mesh()
	if generated == null:
		return null
	# LOD generation can split/reorder vertices; use the same spatial bake.
	var transfer := Transfer.new()
	if not transfer.capture(source):
		return null
	var result := transfer.bake(generated)
	result.custom_aabb = local.custom_aabb
	return result
