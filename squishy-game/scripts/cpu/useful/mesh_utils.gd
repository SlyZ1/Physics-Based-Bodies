class_name MeshUtils
extends Object

static func create_icosphere(r: float, subs: int) -> ArrayMesh:
	var t = (1.0 + sqrt(5.0)) / 2.0
	var verts = PackedVector3Array([
		Vector3(-1,  t,  0), Vector3( 1,  t,  0),
		Vector3(-1, -t,  0), Vector3( 1, -t,  0),
		Vector3( 0, -1,  t), Vector3( 0,  1,  t),
		Vector3( 0, -1, -t), Vector3( 0,  1, -t),
		Vector3( t,  0, -1), Vector3( t,  0,  1),
		Vector3(-t,  0, -1), Vector3(-t,  0,  1),
	])
	for i in range(verts.size()):
		verts[i] = -verts[i].normalized() * r

	var indices = PackedInt32Array([
		0,11,5, 0,5,1, 0,1,7, 0,7,10, 0,10,11,
		1,5,9, 5,11,4, 11,10,2, 10,7,6, 7,1,8,
		3,9,4, 3,4,2, 3,2,6, 3,6,8, 3,8,9,
		4,9,5, 2,4,11, 6,2,10, 8,6,7, 9,8,1
	])

	var mid_cache = {}
	for s in range(subs):
		var new_indices = PackedInt32Array()
		mid_cache.clear()
		for t2 in range(0, indices.size(), 3):
			var a = indices[t2]
			var b = indices[t2 + 1]
			var c = indices[t2 + 2]
			var ab = _midpoint(a, b, verts, mid_cache, r)
			var bc = _midpoint(b, c, verts, mid_cache, r)
			var ca = _midpoint(c, a, verts, mid_cache, r)
			new_indices.append_array([a,ab,ca, b,bc,ab, c,ca,bc, ab,bc,ca])
		indices = new_indices

	var normals = PackedVector3Array()
	for v in verts:
		normals.append(v.normalized())

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices

	var arr_mesh = ArrayMesh.new()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	var mat = StandardMaterial3D.new()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	arr_mesh.surface_set_material(0, mat)
	return arr_mesh

static func _midpoint(a: int, b: int, verts: PackedVector3Array, cache: Dictionary, r: float) -> int:
	var key = min(a, b) * 1000000 + max(a, b)
	if cache.has(key):
		return cache[key]
	var mid = ((verts[a] + verts[b]) / 2.0).normalized() * r
	verts.append(mid)
	var idx = verts.size() - 1
	cache[key] = idx
	return idx

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

static func get_volume_center(arr: PackedVector3Array, mesh: Mesh) -> Vector3:
	var total_volume: float = 0.0
	var center: Vector3 = Vector3.ZERO

	var surface: Array = mesh.surface_get_arrays(0)
	var indices: PackedInt32Array = surface[Mesh.ARRAY_INDEX]

	for i: int in range(0, indices.size(), 3):
		var v0: Vector3 = arr[indices[i]]
		var v1: Vector3 = arr[indices[i + 1]]
		var v2: Vector3 = arr[indices[i + 2]]

		var signed_volume: float = v0.dot(v1.cross(v2)) / 6.0
		var centroid: Vector3 = (v0 + v1 + v2) / 4.0

		total_volume += signed_volume
		center += signed_volume * centroid

	center /= total_volume
	return center

static func set_vertices(mesh: Mesh, vertices: PackedVector3Array) -> ArrayMesh:
	var surface: Array = mesh.surface_get_arrays(0)
	surface[Mesh.ARRAY_VERTEX] = vertices
	
	var arr_mesh: ArrayMesh = ArrayMesh.new()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface)
	return arr_mesh
	
static func fast_set_vertices(mesh: Mesh, mesh_rid: RID, vertices: PackedVector3Array, bounds: AABB) -> void:
	var surface: Array = mesh.surface_get_arrays(0)
	surface[Mesh.ARRAY_VERTEX] = vertices
	RenderingServer.mesh_surface_update_vertex_region(
		mesh_rid, 0, 0, 
		vertices.to_byte_array()
	)
	RenderingServer.mesh_set_custom_aabb(
		mesh_rid,
		bounds
	)
	
static func set_triangles(mesh: Mesh, triangles: PackedInt32Array) -> ArrayMesh:
	var surface: Array = mesh.surface_get_arrays(0)
	surface[Mesh.ARRAY_INDEX] = triangles
	
	var arr_mesh: ArrayMesh = ArrayMesh.new()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface)
	return arr_mesh

static func smooth_mesh(mesh: Mesh, vertices: PackedVector3Array, neighbours: Array, factor: float) -> PackedVector3Array:
	var mesh_data: Array = mesh.surface_get_arrays(0)
	var new_vertices: PackedVector3Array = vertices.duplicate()
	for i in range(neighbours.size()):
		var list: Array = neighbours[i]
		var v_pos: Vector3 = new_vertices[i]
		var center: Vector3
		var num_neighbours: int = list.size()
		for j in range(num_neighbours):
			center += new_vertices[neighbours[i][j]]
		new_vertices[i] = v_pos.lerp(center / (num_neighbours), factor)
	return new_vertices
