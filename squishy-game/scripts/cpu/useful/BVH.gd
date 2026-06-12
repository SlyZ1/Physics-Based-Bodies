class_name BoundingSphereTree extends Object

# Represents an individual object and its triangles
class ObjectSphere:
	var center: Vector3
	var radius: float
	var triangles: Array = []

# The root container holding all objects
class SphereNode:
	var objects: Array = [] # Array of ObjectSphere

# Expect items to be an array of ARRAYS of triangles: [ [tri, tri, tri], [tri, tri, tri] ]
# Each subarray represents a separate object.
static func build_hierarchy(items: Array) -> SphereNode:
	var root_node = SphereNode.new()

	if items.is_empty():
		return root_node

	for object_triangles in items: # loop of objects
		if object_triangles.is_empty():
			continue
			
		var obj_sphere = ObjectSphere.new()
		obj_sphere.triangles = object_triangles

		# Approximate center using AABB for this specific object
		var first_tri = object_triangles[0]
		var total_bounds: AABB = AABB(first_tri["v0"], Vector3.ZERO)
		total_bounds = total_bounds.expand(first_tri["v1"]).expand(first_tri["v2"])
		
		for i in range(1, object_triangles.size()):
			var tri = object_triangles[i]
			total_bounds = total_bounds.expand(tri["v0"]).expand(tri["v1"]).expand(tri["v2"])
		
		obj_sphere.center = total_bounds.get_center()

		# Radius : furthest vertex from the center
		var max_radius_sq: float = 0.0
		for tri in object_triangles:
			max_radius_sq = max(max_radius_sq, obj_sphere.center.distance_squared_to(tri["v0"]))
			max_radius_sq = max(max_radius_sq, obj_sphere.center.distance_squared_to(tri["v1"]))
			max_radius_sq = max(max_radius_sq, obj_sphere.center.distance_squared_to(tri["v2"]))
		
		obj_sphere.radius = sqrt(max_radius_sq)
		root_node.objects.append(obj_sphere)

	return root_node


# Returns an array of triangles to test against a target center and distance threshold
static func query_sphere(node: SphereNode, target_center: Vector3, distance_threshold: float, results: Array = []) -> Array:
	if node == null or node.objects.is_empty():
		return results

	for obj in node.objects:
		var distance_sq = obj.center.distance_squared_to(target_center)
		var combined_radius = obj.radius + distance_threshold
		
		# Broad-collision: sphere intersection only
		if distance_sq <= (combined_radius * combined_radius):
			
			# check triangles as well (more optimized to do here before any vertex-to-triangle check)
			for tri in obj.triangles:
				var tri_center = (tri["v0"] + tri["v1"] + tri["v2"]) / 3.0
				var r0 = tri_center.distance_squared_to(tri["v0"])
				var r1 = tri_center.distance_squared_to(tri["v1"])
				var r2 = tri_center.distance_squared_to(tri["v2"])
				var tri_radius = sqrt(max(r0, max(r1, r2)))

				var tri_dist_sq = tri_center.distance_squared_to(target_center)
				var tri_comb_radius = tri_radius + distance_threshold
				
				if tri_dist_sq <= (tri_comb_radius * tri_comb_radius):
					results.append(tri)

	return results
