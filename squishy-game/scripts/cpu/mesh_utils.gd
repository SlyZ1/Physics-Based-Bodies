const sphere_ring_count = 65

static func close_sphere(mesh: Mesh) -> ArrayMesh:
	var mesh_data: Array = mesh.surface_get_arrays(0)
	var indices: PackedInt32Array = mesh_data[Mesh.ARRAY_INDEX]
	var N: int = mesh_data[Mesh.ARRAY_VERTEX].size()
	for i in range(sphere_ring_count, N - 1, sphere_ring_count):
		indices.append(i - sphere_ring_count)
		indices.append(i)
		indices.append(i - 1)
		
		indices.append(i - 1)
		indices.append(i)
		indices.append(i + sphere_ring_count - 1)
	mesh_data[Mesh.ARRAY_INDEX] = indices
	var arr_mesh: ArrayMesh = ArrayMesh.new()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_data)
	return arr_mesh

static func compute_neighbors(mesh: Mesh) -> Array:
	var mesh_data: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = mesh_data[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = mesh_data[Mesh.ARRAY_INDEX]
	var n = vertices.size()
	
	var neighbors: Array = []
	neighbors.resize(n)
	for i in range(n):
		neighbors[i] = {}
	
	for t in range(0, indices.size(), 3):
		var a = indices[t]
		var b = indices[t + 1]
		var c = indices[t + 2]
		neighbors[a][b] = true
		neighbors[a][c] = true
		neighbors[b][a] = true
		neighbors[b][c] = true
		neighbors[c][a] = true
		neighbors[c][b] = true
	
	var result: Array = []
	result.resize(n)
	for i in range(n):
		result[i] = neighbors[i].keys()
	
	return result

static func get_vertices(mesh: Mesh) -> PackedVector3Array:
	var mesh_data: Array = mesh.surface_get_arrays(0)
	return mesh_data[Mesh.ARRAY_VERTEX]

static func recompute_normals(vertices: PackedVector3Array) -> PackedVector3Array:
	var normals: PackedVector3Array = PackedVector3Array()
	var N: int = vertices.size()
	normals.resize(N)
	var center: Vector3 = get_center(vertices)
	for i in range(N):
		normals[i] = (vertices[i] - center).normalized()
	return normals

static func get_center(arr: PackedVector3Array) -> Vector3:
	var center: Vector3 = Vector3.ZERO
	var N: int = arr.size()
	for i in range(N):
		center += arr[i]
	center /= N
	return center

static func set_vertices(mesh: Mesh, vertices: PackedVector3Array) -> Mesh:
	var surface: Array = mesh.surface_get_arrays(0)
	surface[Mesh.ARRAY_VERTEX] = vertices
	surface[Mesh.ARRAY_NORMAL] = recompute_normals(vertices)
	
	var arr_mesh: ArrayMesh = ArrayMesh.new()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface)
	return arr_mesh

static func smooth_mesh(mesh: Mesh, vertices: PackedVector3Array, neighbours: Array, factor: float) -> PackedVector3Array:
	var mesh_data: Array = mesh.surface_get_arrays(0)
	var new_vertices: PackedVector3Array = vertices.duplicate()
	for i in range(sphere_ring_count, neighbours.size() - sphere_ring_count):
		var list: Array = neighbours[i]
		var v_pos: Vector3 = new_vertices[i]
		var center: Vector3
		var num_neighbours: int = list.size()
		for j in range(num_neighbours):
			center += new_vertices[neighbours[i][j]]
		new_vertices[i] = v_pos.lerp(center / (num_neighbours), factor)
	return new_vertices
