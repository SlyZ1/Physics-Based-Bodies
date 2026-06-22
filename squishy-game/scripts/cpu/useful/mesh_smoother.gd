class_name MeshSmoother

static func compute_neighbors(mesh: Mesh) -> Dictionary:
	var mesh_data: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = mesh_data[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = mesh_data[Mesh.ARRAY_INDEX]
	var n = vertices.size()

	var position_to_canonical: Dictionary = {}
	var canonical_index: PackedInt32Array = PackedInt32Array()
	canonical_index.resize(n)

	for i in range(n):
		var p = vertices[i]
		var key = "%.4f,%.4f,%.4f" % [
			p.x if p.x != 0.0 else 0.0,
			p.y if p.y != 0.0 else 0.0,
			p.z if p.z != 0.0 else 0.0
		]
		if not position_to_canonical.has(key):
			position_to_canonical[key] = i
		canonical_index[i] = position_to_canonical[key]

	var neighbors_set: Dictionary = {}
	for t in range(0, indices.size(), 3):
		var a = canonical_index[indices[t]]
		var b = canonical_index[indices[t + 1]]
		var c = canonical_index[indices[t + 2]]
		for pair in [[a, b], [a, c], [b, a], [b, c], [c, a], [c, b]]:
			if pair[0] == pair[1]:
				continue
			if not neighbors_set.has(pair[0]):
				neighbors_set[pair[0]] = {}
			neighbors_set[pair[0]][pair[1]] = true

	var neighbours: Array = []
	neighbours.resize(n)
	for i in range(n):
		var canon = canonical_index[i]
		if neighbors_set.has(canon):
			neighbours[i] = neighbors_set[canon].keys()
		else:
			neighbours[i] = []

	return {
		"neighbours": neighbours,
		"canonical_index": canonical_index
	}


static func smooth_mesh(vertices: PackedVector3Array, neighbours: Array, factor: float) -> PackedVector3Array:
	var new_vertices: PackedVector3Array = vertices.duplicate()
	for i in range(neighbours.size()):
		var list: Array = neighbours[i]
		var num_neighbours: int = list.size()
		if num_neighbours == 0:
			continue
		var v_pos: Vector3 = vertices[i]
		var center: Vector3 = Vector3.ZERO
		for j in range(num_neighbours):
			center += new_vertices[list[j]]
		new_vertices[i] = v_pos.lerp(center / num_neighbours, factor)
	return new_vertices
