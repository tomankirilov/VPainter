@tool
extends RefCounted

const Painter = preload("res://addons/vpainter/core/mesh_painter.gd")


static func blur(nodes: Array[MeshInstance3D], center: Vector3, radius: float, strength: float, channels: Array[bool]) -> Dictionary:
	# Snapshot every selected mesh before applying any result. Spatial neighbors
	# can belong to another object, allowing smoothing across object boundaries.
	var kernel := radius * 0.5
	var cells: Dictionary = {}
	var surfaces_by_node: Dictionary = {}
	for node in nodes:
		var surfaces: Array = []
		for surface in range(node.mesh.get_surface_count()):
			var arrays := node.mesh.surface_get_arrays(surface).duplicate(true)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var colors := Painter._colors_or_white(arrays, vertices.size())
			arrays[Mesh.ARRAY_COLOR] = colors
			surfaces.append(arrays)
			for vertex in range(vertices.size()):
				var world := node.global_transform * vertices[vertex]
				if world.distance_to(center) >= radius + kernel:
					continue
				var cell := _cell(world, kernel)
				if not cells.has(cell):
					cells[cell] = []
				cells[cell].append({"position": world, "color": colors[vertex]})
		surfaces_by_node[node] = surfaces
	var results: Dictionary = {}
	for node in nodes:
		var surfaces: Array = surfaces_by_node[node]
		var changed := false
		for arrays in surfaces:
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			for vertex in range(vertices.size()):
				var world := node.global_transform * vertices[vertex]
				var distance := world.distance_to(center)
				if distance >= radius:
					continue
				var average := Color(0, 0, 0, 0)
				var total := 0.0
				var cell := _cell(world, kernel)
				for x in range(-1, 2):
					for y in range(-1, 2):
						for z in range(-1, 2):
							for sample in cells.get(cell + Vector3i(x, y, z), []):
								var position: Vector3 = sample["position"]
								var weight := maxf(0.0, 1.0 - world.distance_to(position) / kernel)
								average += sample["color"] * weight
								total += weight
				if total <= 0:
					continue
				average /= total
				var weight := strength * (1.0 - distance / radius)
				var color := Painter.blend_channels(colors[vertex], average, weight, channels)
				changed = changed or not color.is_equal_approx(colors[vertex])
				colors[vertex] = color
			arrays[Mesh.ARRAY_COLOR] = colors
		if changed:
			results[node] = Painter.copy_mesh(node.mesh, surfaces)
	return results


static func _cell(point: Vector3, size: float) -> Vector3i:
	return Vector3i(floori(point.x / size), floori(point.y / size), floori(point.z / size))
