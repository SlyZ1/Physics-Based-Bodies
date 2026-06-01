class_name MeshCollisions
extends Object

static func extract_collider_geometry(colliders_parent: Node) -> Array:
	var collision_triangles: Array
	
	for child in colliders_parent.get_children():
		if child is MeshInstance3D and child.mesh:
			var faces = child.mesh.get_faces() 
			var child_transform = child.global_transform
			
			for i in range(0, faces.size(), 3):
				var v0 = child_transform * faces[i]
				var v1 = child_transform * faces[i+1]
				var v2 = child_transform * faces[i+2]
				
				var normal = (v2 - v0).cross(v1 - v0).normalized()
				
				collision_triangles.append({
					"v0": v0, "v1": v1, "v2": v2, "normal": normal
				})
	return collision_triangles


static func ray_intersects_triangle(ray_origin: Vector3, ray_vector: Vector3, tri: Dictionary) -> Variant:
	const EPSILON = 0.0000001
	var v0 = tri.v0
	var v1 = tri.v1
	var v2 = tri.v2
	
	var edge1 = v1 - v0
	var edge2 = v2 - v0
	var h = ray_vector.cross(edge2)
	var a = edge1.dot(h)
	
	if a > -EPSILON and a < EPSILON:
		return null
		
	var f = 1.0 / a
	var s = ray_origin - v0
	var u = f * s.dot(h)
	
	if u < 0.0 or u > 1.0:
		return null
		
	var q = s.cross(edge1)
	var v = f * ray_vector.dot(q)
	
	if v < 0.0 or u + v > 1.0:
		return null
		
	var t = f * edge2.dot(q)
	
	if t > EPSILON and t <= 1.0:
		return ray_origin + (ray_vector * t)
		
	return null

static func intersect_nearest_triangle(collision_triangles: Array, global_start, global_end) -> Dictionary:
	var ray_vector: Vector3 = global_end - global_start 
	
	var best_hit_pos: Variant = null
	var best_hit_normal: Vector3
	var min_dist: float = INF

	for tri in collision_triangles:
		var hit_pos = MeshCollisions.ray_intersects_triangle(global_start, ray_vector, tri)
		if hit_pos == null:
			continue
		# Project along the normal to have a relevant behaviour
		var hit_along_normal = global_end - (global_end - hit_pos).dot(tri.normal) * tri.normal
		var dist = global_start.distance_squared_to(hit_along_normal)
		if dist < min_dist:
			min_dist = dist
			best_hit_pos = hit_along_normal
			best_hit_normal = tri.normal
	return {"pos": best_hit_pos, "normal": best_hit_normal}
