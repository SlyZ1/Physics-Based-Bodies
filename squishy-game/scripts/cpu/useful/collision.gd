class_name MeshCollisions
extends Object

static func _extract_collider_geometry(colliders_parent: Node) -> Array:
	var collision_object_triangles: Array
	
	for child in colliders_parent.get_children():
		var triangles: Array = []
		if child is MeshInstance3D and child.mesh:
			var faces = child.mesh.get_faces() 
			var child_transform = child.global_transform
			
			for i in range(0, faces.size(), 3):
				var v0 = child_transform * faces[i]
				var v1 = child_transform * faces[i+1]
				var v2 = child_transform * faces[i+2]
				
				var normal = (v2 - v0).cross(v1 - v0).normalized()
				
				triangles.append({
					"v0": v0, "v1": v1, "v2": v2, "normal": normal
				})
		collision_object_triangles.append(triangles)
	return collision_object_triangles

static func create_collision_BVH_object(colliders_parent: Node) -> BoundingSphereTree.SphereNode:
	return BoundingSphereTree.build_hierarchy(_extract_collider_geometry(colliders_parent))

static func ray_intersects_triangle(ray_origin: Vector3, ray_vector: Vector3, tri: Dictionary) -> Variant:
	const EPSILON = 0.0000001
	var v0 = tri.v0
	var v1 = tri.v1
	var v2 = tri.v2
	if ray_vector.dot(tri.normal) > EPSILON:
		return null
	
	var edge1 = v1 - v0
	var edge2 = v2 - v0
	var h = ray_vector.cross(edge2)
	var a = edge1.dot(h)
	
	if a > -EPSILON:
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
	
static func intersect_nearest_triangles(collision_triangles: Array, global_center: Vector3, global_start: Vector3, global_end: Vector3) -> Array:
	var ray_vector: Vector3 = global_end - global_start 
	var snd_ray_vector: Vector3 = global_end - global_center
	
	var hit_1 = {"pos": null, "normal": Vector3.ZERO, "dist": INF}
	var hit_2 = {"pos": null, "normal": Vector3.ZERO, "dist": INF}

	for tri in collision_triangles:
		var hit_pos = MeshCollisions.ray_intersects_triangle(global_start, ray_vector, tri)
		if hit_pos == null:
			hit_pos = MeshCollisions.ray_intersects_triangle(global_center, snd_ray_vector, tri)
			if hit_pos == null:
				continue
			
		# Project along the normal to have a relevant behaviour
		var hit_along_normal = global_end - (global_end - hit_pos).dot(tri.normal) * tri.normal
		var dist = global_start.distance_squared_to(hit_along_normal)
		
		# Prevent registering two triangles from the exact same flat plane (e.g. edge hits)
		if hit_1.pos != null and hit_1.normal.dot(tri.normal) > 0.99 and abs(dist - hit_1.dist) < 0.0001:
			continue
			
		if dist < hit_1.dist:
			hit_2.pos = hit_1.pos
			hit_2.normal = hit_1.normal
			hit_2.dist = hit_1.dist
			
			hit_1.pos = hit_along_normal
			hit_1.normal = tri.normal
			hit_1.dist = dist
		elif dist < hit_2.dist:
			hit_2.pos = hit_along_normal
			hit_2.normal = tri.normal
			hit_2.dist = dist

	var results = []
	if hit_1.pos != null:
		results.append({"pos": hit_1.pos, "normal": hit_1.normal, "dist": hit_1.dist})
	if hit_2.pos != null:
		results.append({"pos": hit_2.pos, "normal": hit_2.normal, "dist": hit_2.dist})
		
	return results

# Old function, keep for consistency for now (Colin)
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
