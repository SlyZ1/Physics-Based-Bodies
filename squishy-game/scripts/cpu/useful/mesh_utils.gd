class_name MeshUtils
extends Object

static var _vertex_map: Dictionary = {}
static var _final_vertices: PackedVector3Array
static var _radius: float = 1.0

static func generate_geodesic_sphere(frequency: int, radius: float = 1.0) -> Dictionary:
	_vertex_map.clear()
	_final_vertices = PackedVector3Array()
	_radius = radius

	var t = (1.0 + sqrt(5.0)) / 2.0

	var base_vertices = [
		Vector3(-1,  t,  0), Vector3( 1,  t,  0), Vector3(-1, -t,  0), Vector3( 1, -t,  0),
		Vector3( 0, -1,  t), Vector3( 0,  1,  t), Vector3( 0, -1, -t), Vector3( 0,  1, -t),
		Vector3( t,  0, -1), Vector3( t,  0,  1), Vector3(-t,  0, -1), Vector3(-t,  0,  1)
	]
	for i in base_vertices.size():
		base_vertices[i] = base_vertices[i].normalized()

	var base_faces = [
		[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
		[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]
	]

	var final_indices: PackedInt32Array = PackedInt32Array()

	var base_vertex_indices: Array = []
	for bv in base_vertices:
		base_vertex_indices.append(_get_or_add_vertex(bv * radius))

	for face in base_faces:
		var v0 = base_vertices[face[0]]
		var v1 = base_vertices[face[1]]
		var v2 = base_vertices[face[2]]

		var grid: Array = []
		for i in range(frequency + 1):
			var row: Array = []
			for j in range(frequency + 1 - i):
				var idx: int
				if i == 0 and j == 0:
					idx = base_vertex_indices[face[0]]
				elif i == frequency and j == 0:
					idx = base_vertex_indices[face[1]]
				elif i == 0 and j == frequency:
					idx = base_vertex_indices[face[2]]
				else:
					var a = float(i) / frequency
					var b = float(j) / frequency
					var c = 1.0 - a - b
					var p = (v0 * c + v1 * a + v2 * b).normalized() * radius
					idx = _get_or_add_vertex(p)
				row.append(idx)
			grid.append(row)

		for i in range(frequency):
			for j in range(frequency - i):
				var i0 = grid[i][j]
				var i1 = grid[i + 1][j]
				var i2 = grid[i][j + 1]
				final_indices.append(i0)
				final_indices.append(i2)
				final_indices.append(i1)

				if j < frequency - i - 1:
					var i3 = grid[i + 1][j + 1]
					final_indices.append(i1)
					final_indices.append(i2)
					final_indices.append(i3)

	return {"vertices": _final_vertices, "indices": final_indices}


static func _get_or_add_vertex(p: Vector3) -> int:
	var px = p.x if abs(p.x) > 1e-4 else 0.0
	var py = p.y if abs(p.y) > 1e-4 else 0.0
	var pz = p.z if abs(p.z) > 1e-4 else 0.0
	var key = "%.4f,%.4f,%.4f" % [px, py, pz]
	if _vertex_map.has(key):
		return _vertex_map[key]
	var idx = _final_vertices.size()
	_final_vertices.append(p)
	_vertex_map[key] = idx
	return idx


static func export_mesh_to_obj(mesh_data: Dictionary, path: String) -> void:
	var vertices: PackedVector3Array = mesh_data["vertices"]
	var indices: PackedInt32Array = mesh_data["indices"]
	
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Impossible d'ouvrir le fichier: " + path)
		return
	
	file.store_line("# Exported from Godot")
	
	for v in vertices:
		file.store_line("v %f %f %f" % [v.x, v.y, v.z])
	
	# OBJ utilise des index 1-based, pas 0-based
	for i in range(0, indices.size(), 3):
		var i0 = indices[i] + 1
		var i1 = indices[i + 1] + 1
		var i2 = indices[i + 2] + 1
		file.store_line("f %d %d %d" % [i0, i1, i2])
	
	file.close()
	print("Mesh exportée vers: ", path)

static func build_geodesic_mesh(frequency: int, radius: float = 1.0) -> ArrayMesh:
	var data = generate_geodesic_sphere(frequency, radius)
	var vertices: PackedVector3Array = data["vertices"]
	var indices: PackedInt32Array = data["indices"]

	var normals := PackedVector3Array()
	for v in vertices:
		normals.append(v.normalized())

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	
	var verts = data["vertices"]
	var seen = {}
	for i in verts.size():
		var found_dup = false
		for key in seen.keys():
			if verts[i].distance_to(seen[key]) < 0.01:
				print("Doublon: index ", i, " (", verts[i], ") proche de index ", key, " (", seen[key], "), distance=", verts[i].distance_to(seen[key]))
				found_dup = true
		if not found_dup:
			seen[i] = verts[i]

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

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

static func set_vertices(mesh: Mesh, vertices: PackedVector3Array, center: Vector3) -> ArrayMesh:
	var surface: Array = mesh.surface_get_arrays(0)
	var material: Material = mesh.surface_get_material(0)
	surface[Mesh.ARRAY_VERTEX] = vertices
	
	var normals: PackedVector3Array
	var N: int = vertices.size()
	normals.resize(N)
	for i in range(N):
		normals[i] = (vertices[i] - center).normalized()
	surface[Mesh.ARRAY_NORMAL] = normals
	
	var arr_mesh: ArrayMesh = ArrayMesh.new()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface)
	arr_mesh.surface_set_material(0, material)
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
