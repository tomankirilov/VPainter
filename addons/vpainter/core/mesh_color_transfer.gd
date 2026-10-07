@tool
extends RefCounted

const Painter = preload("res://addons/vpainter/core/mesh_painter.gd")

var _triangles: Array[Dictionary] = []
var _tree: Dictionary = {}


func capture(mesh: Mesh) -> bool:
	_triangles.clear()
	_tree.clear()
	for surface in range(mesh.get_surface_count()):
		if mesh is ArrayMesh and mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors := Painter._colors_or_white(arrays, vertices.size())
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := indices.size() if not indices.is_empty() else vertices.size()
		for offset in range(0, count - 2, 3):
			var a := indices[offset] if not indices.is_empty() else offset
			var b := indices[offset + 1] if not indices.is_empty() else offset + 1
			var c := indices[offset + 2] if not indices.is_empty() else offset + 2
			var bounds := AABB(vertices[a], Vector3.ZERO).expand(vertices[b]).expand(vertices[c])
			_triangles.append({"a": vertices[a], "b": vertices[b], "c": vertices[c], "ca": colors[a], "cb": colors[b], "cc": colors[c], "bounds": bounds})
	if _triangles.is_empty():
		return false
	var ids: Array[int] = []
	for index in range(_triangles.size()):
		ids.append(index)
	_tree = _build_tree(ids)
	return true


func bake(target: Mesh) -> ArrayMesh:
	if _tree.is_empty() or target.get_surface_count() == 0:
		return null
	var surfaces: Array = []
	for surface in range(target.get_surface_count()):
		var arrays := target.surface_get_arrays(surface).duplicate(true)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors := PackedColorArray()
		colors.resize(vertices.size())
		for vertex in range(vertices.size()):
			var color := sample(vertices[vertex])
			# Godot stores mesh colors as bytes. Round once so repeated bakes do
			# not gradually darken flat colors through floating-point truncation.
			for channel in range(4):
				color[channel] = roundf(clampf(color[channel], 0, 1) * 255.0) / 255.0
			colors[vertex] = color
		arrays[Mesh.ARRAY_COLOR] = colors
		surfaces.append(arrays)
	return Painter.copy_mesh(target, surfaces)


func sample(point: Vector3) -> Color:
	var nearest_distance := INF
	var color := Color.WHITE
	var pending: Array[Dictionary] = [_tree]
	while not pending.is_empty():
		var node: Dictionary = pending.pop_back()
		if _bounds_distance_squared(node["bounds"], point) > nearest_distance:
			continue
		if node.has("ids"):
			for id in node["ids"]:
				var triangle: Dictionary = _triangles[id]
				var a: Vector3 = triangle["a"]
				var b: Vector3 = triangle["b"]
				var c: Vector3 = triangle["c"]
				var weights := _closest_weights(point, a, b, c)
				var closest := a * weights.x + b * weights.y + c * weights.z
				var distance := point.distance_squared_to(closest)
				if distance < nearest_distance:
					nearest_distance = distance
					color = triangle["ca"] * weights.x + triangle["cb"] * weights.y + triangle["cc"] * weights.z
		else:
			var left: Dictionary = node["left"]
			var right: Dictionary = node["right"]
			# Visit the nearer branch first to prune distant triangles quickly.
			if _bounds_distance_squared(left["bounds"], point) < _bounds_distance_squared(right["bounds"], point):
				pending.append(right)
				pending.append(left)
			else:
				pending.append(left)
				pending.append(right)
	return color


func _build_tree(ids: Array[int]) -> Dictionary:
	var bounds: AABB = _triangles[ids[0]]["bounds"]
	for id in ids:
		bounds = bounds.merge(_triangles[id]["bounds"])
	if ids.size() <= 16:
		return {"bounds": bounds, "ids": ids}
	var axis := bounds.size.max_axis_index()
	ids.sort_custom(func(a: int, b: int) -> bool:
		var ba: AABB = _triangles[a]["bounds"]
		var bb: AABB = _triangles[b]["bounds"]
		return ba.get_center()[axis] < bb.get_center()[axis])
	var midpoint := ids.size() / 2
	return {"bounds": bounds, "left": _build_tree(ids.slice(0, midpoint)), "right": _build_tree(ids.slice(midpoint))}


static func _bounds_distance_squared(bounds: AABB, point: Vector3) -> float:
	var closest := Vector3(clampf(point.x, bounds.position.x, bounds.end.x), clampf(point.y, bounds.position.y, bounds.end.y), clampf(point.z, bounds.position.z, bounds.end.z))
	return closest.distance_squared_to(point)


static func _closest_weights(point: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var ab := b - a
	var ac := c - a
	# Collapsed triangles still have a well-defined nearest segment or vertex.
	if ab.cross(ac).length_squared() <= ab.length_squared() * ac.length_squared() * 1e-12:
		var best := Vector3(1, 0, 0)
		var distance := INF
		for edge in [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 0)]:
			var positions: Array[Vector3] = [a, b, c]
			var start := positions[edge.x]
			var delta := positions[edge.y] - start
			var t := clampf((point - start).dot(delta) / delta.length_squared(), 0, 1) if delta.length_squared() > 0 else 0.0
			var edge_distance := point.distance_squared_to(start + delta * t)
			if edge_distance < distance:
				distance = edge_distance
				best = Vector3.ZERO
				best[edge.x] = 1 - t
				best[edge.y] = t
		return best
	var ap := point - a
	var d1 := ab.dot(ap)
	var d2 := ac.dot(ap)
	if d1 <= 0 and d2 <= 0:
		return Vector3(1, 0, 0)
	var bp := point - b
	var d3 := ab.dot(bp)
	var d4 := ac.dot(bp)
	if d3 >= 0 and d4 <= d3:
		return Vector3(0, 1, 0)
	var vc := d1 * d4 - d3 * d2
	if vc <= 0 and d1 >= 0 and d3 <= 0:
		var v := d1 / (d1 - d3)
		return Vector3(1 - v, v, 0)
	var cp := point - c
	var d5 := ab.dot(cp)
	var d6 := ac.dot(cp)
	if d6 >= 0 and d5 <= d6:
		return Vector3(0, 0, 1)
	var vb := d5 * d2 - d1 * d6
	if vb <= 0 and d2 >= 0 and d6 <= 0:
		var w := d2 / (d2 - d6)
		return Vector3(1 - w, 0, w)
	var va := d3 * d6 - d5 * d4
	if va <= 0 and d4 - d3 >= 0 and d5 - d6 >= 0:
		var w := (d4 - d3) / ((d4 - d3) + (d5 - d6))
		return Vector3(0, 1 - w, w)
	var inverse := 1.0 / (va + vb + vc)
	var v := vb * inverse
	var w := vc * inverse
	return Vector3(1 - v - w, v, w)
