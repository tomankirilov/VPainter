@tool
extends RefCounted


static func copy_mesh(source: Mesh, surface_arrays: Array = []) -> ArrayMesh:
	var result := ArrayMesh.new()
	result.resource_local_to_scene = true
	result.resource_name = source.resource_name.trim_suffix(" (VPainter)") + " (VPainter)"
	if source is ArrayMesh:
		result.blend_shape_mode = source.blend_shape_mode
		for index in range(source.get_blend_shape_count()):
			result.add_blend_shape(source.get_blend_shape_name(index))
		result.custom_aabb = source.custom_aabb
	for surface in range(source.get_surface_count()):
		var arrays: Array = source.surface_get_arrays(surface).duplicate(true) if surface_arrays.is_empty() else surface_arrays[surface]
		var blends: Array = []
		var lods: Dictionary = {}
		if source is ArrayMesh:
			blends = source.surface_get_blend_shape_arrays(surface)
			lods = _surface_lods(source, surface)
		var flags: int = (source.surface_get_format(surface) & ~Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES) if source is ArrayMesh else 0
		var primitive: int = source.surface_get_primitive_type(surface) if source is ArrayMesh else Mesh.PRIMITIVE_TRIANGLES
		result.add_surface_from_arrays(primitive, arrays, blends, lods, flags)
		result.surface_set_material(surface, source.surface_get_material(surface))
		if source is ArrayMesh:
			result.surface_set_name(surface, source.surface_get_name(surface))
	return result


static func _surface_lods(mesh: ArrayMesh, surface: int) -> Dictionary:
	var data := RenderingServer.mesh_get_surface(mesh.get_rid(), surface)
	var result: Dictionary = {}
	var stride := RenderingServer.mesh_surface_get_format_index_stride(data["format"], data["vertex_count"])
	for lod in data.get("lods", []):
		var bytes: PackedByteArray = lod["index_data"]
		var indices := PackedInt32Array()
		for offset in range(0, bytes.size(), stride):
			indices.append(bytes.decode_u16(offset) if stride == 2 else bytes.decode_u32(offset))
		result[lod["edge_length"]] = indices
	return result


static func hit_position(mesh: Mesh, transform: Transform3D, origin: Vector3, direction: Vector3) -> Variant:
	if is_zero_approx(transform.basis.determinant()):
		return null
	var inverse := transform.affine_inverse()
	var local_origin := inverse * origin
	var local_direction := (inverse.basis * direction).normalized()
	var closest: Variant = null
	var closest_distance := INF
	for surface in range(mesh.get_surface_count()):
		if mesh is ArrayMesh and mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := indices.size() if not indices.is_empty() else vertices.size()
		for triangle in range(0, count - 2, 3):
			var a := indices[triangle] if not indices.is_empty() else triangle
			var b := indices[triangle + 1] if not indices.is_empty() else triangle + 1
			var c := indices[triangle + 2] if not indices.is_empty() else triangle + 2
			var hit: Variant = Geometry3D.ray_intersects_triangle(local_origin, local_direction, vertices[a], vertices[b], vertices[c])
			if hit != null:
				var world_hit: Vector3 = transform * hit
				var distance := origin.distance_squared_to(world_hit)
				if distance < closest_distance:
					closest_distance = distance
					closest = world_hit
	return closest


static func paint(mesh: Mesh, transform: Transform3D, center: Vector3, radius: float, strength: float, target: Color, channels: Array[bool]) -> ArrayMesh:
	var surfaces: Array = []
	var changed := false
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface).duplicate(true)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors := _colors_or_white(arrays, vertices.size())
		for vertex in range(vertices.size()):
			var distance := (transform * vertices[vertex]).distance_to(center)
			if distance >= radius:
				continue
			var weight := strength * (1.0 - distance / radius)
			var color := blend_channels(colors[vertex], target, weight, channels)
			changed = changed or not color.is_equal_approx(colors[vertex])
			colors[vertex] = color
		arrays[Mesh.ARRAY_COLOR] = colors
		surfaces.append(arrays)
	return copy_mesh(mesh, surfaces) if changed else null


static func fill(mesh: Mesh, strength: float, target: Color, channels: Array[bool]) -> ArrayMesh:
	var surfaces: Array = []
	var changed := false
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface).duplicate(true)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors := _colors_or_white(arrays, vertices.size())
		for vertex in range(colors.size()):
			var color := blend_channels(colors[vertex], target, strength, channels)
			changed = changed or not color.is_equal_approx(colors[vertex])
			colors[vertex] = color
		arrays[Mesh.ARRAY_COLOR] = colors
		surfaces.append(arrays)
	return copy_mesh(mesh, surfaces) if changed else null


static func _colors_or_white(arrays: Array, count: int) -> PackedColorArray:
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	if colors.is_empty():
		colors.resize(count)
		colors.fill(Color.WHITE)
	return colors


static func blend_channels(color: Color, target: Color, strength: float, channels: Array[bool]) -> Color:
	for channel in range(4):
		if channels[channel]:
			color[channel] = lerpf(color[channel], target[channel], clampf(strength, 0.0, 1.0))
	return color


static func blur(mesh: Mesh, transform: Transform3D, center: Vector3, radius: float, strength: float, channels: Array[bool]) -> ArrayMesh:
	var surfaces: Array = []
	var changed := false
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface).duplicate(true)
		surfaces.append(arrays)
		if mesh is ArrayMesh and mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var original := _colors_or_white(arrays, vertices.size())
		var colors := original.duplicate()
		var neighbors: Array[Dictionary] = []
		neighbors.resize(vertices.size())
		for vertex in range(vertices.size()):
			neighbors[vertex] = {}
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := indices.size() if not indices.is_empty() else vertices.size()
		for triangle in range(0, count - 2, 3):
			var face: Array[int] = []
			for corner in range(3):
				face.append(indices[triangle + corner] if not indices.is_empty() else triangle + corner)
			for a in face:
				for b in face:
					if a != b:
						neighbors[a][b] = true
		for vertex in range(vertices.size()):
			var distance := (transform * vertices[vertex]).distance_to(center)
			if distance >= radius or neighbors[vertex].is_empty():
				continue
			# Read from the snapshot, so smoothing does not depend on vertex order.
			var average := Color(0, 0, 0, 0)
			for neighbor in neighbors[vertex]:
				average += original[neighbor]
			average /= float(neighbors[vertex].size())
			var weight := clampf(strength, 0.0, 1.0) * (1.0 - distance / radius)
			var color := blend_channels(original[vertex], average, weight, channels)
			changed = changed or not color.is_equal_approx(original[vertex])
			colors[vertex] = color
		arrays[Mesh.ARRAY_COLOR] = colors
	return copy_mesh(mesh, surfaces) if changed else null
