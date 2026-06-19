class_name MeshCollisions
extends Object

static func _extract_collider_geometry(colliders_parent: Node) -> Array:
	var collision_object_triangles: Array
	
	for child in colliders_parent.get_children():
		var triangles: Array = []
		var rb: Rigidbody = child if child is Rigidbody else null
		var moving_body: Node = child if child.has_method("get_collision_velocity_at_global_point") else null
		_extract_collider_geometry_recursive(child, triangles, rb, moving_body)
		collision_object_triangles.append(triangles)
	return collision_object_triangles

static func _extract_collider_geometry_recursive(
	node: Node,
	triangles: Array,
	rb: Rigidbody,
	moving_body: Node
) -> void:
	if node.get("visual_only") == true:
		return

	if moving_body == null and node.has_method("get_collision_velocity_at_global_point"):
		moving_body = node

	if node is MeshInstance3D and node.visible and node.mesh:
		if moving_body != null and moving_body.has_method("should_include_collision_mesh"):
			if not moving_body.should_include_collision_mesh(node):
				return

		var faces = node.mesh.get_faces()
		var node_transform = node.global_transform

		for i in range(0, faces.size(), 3):
			var v0 = node_transform * faces[i]
			var v1 = node_transform * faces[i+1]
			var v2 = node_transform * faces[i+2]
			var normal = (v2 - v0).cross(v1 - v0).normalized()

			triangles.append({
				"v0": v0,
				"v1": v1,
				"v2": v2,
				"normal": normal,
				"rb": rb,
				"body": moving_body,
				"two_sided": (
					moving_body != null
					and moving_body.has_method("uses_two_sided_collision")
					and moving_body.uses_two_sided_collision()
				)
			})

	for child in node.get_children():
		_extract_collider_geometry_recursive(child, triangles, rb, moving_body)

static func create_collision_BVH_object(colliders_parent: Node) -> BoundingSphereTree.SphereNode:
	return BoundingSphereTree.build_hierarchy(_extract_collider_geometry(colliders_parent))

static func ray_intersects_triangle(ray_origin: Vector3, ray_vector: Vector3, tri: Dictionary) -> Variant:
	const EPSILON = 0.0000001
	var v0 = tri.v0
	var v1 = tri.v1
	var v2 = tri.v2
	var two_sided: bool = tri.get("two_sided", false)
	if not two_sided and ray_vector.dot(tri.normal) > EPSILON:
		return null
	
	var edge1 = v1 - v0
	var edge2 = v2 - v0
	var h = ray_vector.cross(edge2)
	var a = edge1.dot(h)
	
	if (two_sided and abs(a) < EPSILON) or (not two_sided and a > -EPSILON):
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
	
static func intersect_nearest_triangles(
	collision_triangles: Array,
	global_center: Vector3,
	global_start: Vector3,
	global_end: Vector3,
	dt: float
) -> Array:
	var hit_1 = {"pos": null, "normal": Vector3.ZERO, "dist": INF, "rb": null, "body": null}
	var hit_2 = {"pos": null, "normal": Vector3.ZERO, "dist": INF, "rb": null, "body": null}

	for tri in collision_triangles:
		var body: Node = tri.get("body")
		var body_velocity := Vector3.ZERO
		if body != null and body.has_method("get_collision_velocity_at_global_point"):
			var tri_center: Vector3 = (tri.v0 + tri.v1 + tri.v2) / 3.0
			body_velocity = body.get_collision_velocity_at_global_point(tri_center)

		# Compare the vertex against the collider in the collider's current frame.
		# This catches a moving collider sweeping into a stationary squishy vertex.
		var relative_start := global_start + body_velocity * dt
		var ray_vector: Vector3 = global_end - relative_start
		var relative_center := global_center + body_velocity * dt
		var snd_ray_vector: Vector3 = global_end - relative_center

		var used_ray_vector := ray_vector
		var hit_pos = MeshCollisions.ray_intersects_triangle(relative_start, ray_vector, tri)
		if hit_pos == null:
			hit_pos = MeshCollisions.ray_intersects_triangle(relative_center, snd_ray_vector, tri)
			if hit_pos == null:
				continue
			used_ray_vector = snd_ray_vector

		var collision_normal: Vector3 = tri.normal
		if tri.get("two_sided", false):
			# Closed moving boxes can already contain a vertex. Keep the normal
			# facing the squishy's center so the vertex is pushed back out on the
			# side it entered instead of being allowed to exit through the wall.
			var toward_center: Vector3 = global_center - (hit_pos as Vector3)
			if toward_center.dot(collision_normal) < 0.0:
				collision_normal = -collision_normal
			elif abs(toward_center.dot(collision_normal)) < 1e-6:
				if used_ray_vector.dot(collision_normal) > 0.0:
					collision_normal = -collision_normal
			
		# Project along the normal to have a relevant behaviour
		var hit_along_normal = global_end - (global_end - hit_pos).dot(collision_normal) * collision_normal
		var dist = global_start.distance_squared_to(hit_along_normal)
		
		# Prevent registering two triangles from the exact same flat plane (e.g. edge hits)
		if hit_1.pos != null and hit_1.normal.dot(collision_normal) > 0.99 and abs(dist - hit_1.dist) < 0.0001:
			continue

		if hit_2.pos != null and hit_2.normal.dot(collision_normal) > 0.99 and abs(dist - hit_2.dist) < 0.0001:
			continue
			
		if dist < hit_1.dist:
			hit_2.pos = hit_1.pos
			hit_2.normal = hit_1.normal
			hit_2.dist = hit_1.dist
			hit_2.rb = hit_1.rb
			hit_2.body = hit_1.body
			
			hit_1.pos = hit_along_normal
			hit_1.normal = collision_normal
			hit_1.dist = dist
			hit_1.rb = tri.rb
			hit_1.body = body
		elif dist < hit_2.dist:
			hit_2.pos = hit_along_normal
			hit_2.normal = collision_normal
			hit_2.dist = dist
			hit_2.rb = tri.rb
			hit_2.body = body

	var results = []
	if hit_1.pos != null:
		results.append({
			"pos": hit_1.pos,
			"normal": hit_1.normal,
			"dist": hit_1.dist,
			"rb": hit_1.rb,
			"body": hit_1.body
		})
	if hit_2.pos != null:
		results.append({
			"pos": hit_2.pos,
			"normal": hit_2.normal,
			"dist": hit_2.dist,
			"rb": hit_2.rb,
			"body": hit_2.body
		})
		
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
