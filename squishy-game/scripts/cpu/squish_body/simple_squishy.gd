class_name Squishy
extends MeshInstance3D

@export_group("Scene")
@export var colliders_parent: Node
@export var center_node: Node3D
@export var center_gizmo: Node3D

@export_group("Movement")
@export var move_force: float = 10
@export var jump_force: float = 10

@export_group("Physics")
@export_subgroup("Global")
@export var g: float = 9.8
@export var air_damping: float = 0.1
@export_subgroup("Springs")
@export var k: float = 50
@export var m: float = 0.1
@export var center_damping: float = 2
@export var squeleton_damping: float = 20
@export_subgroup("Aerodynamism")
@export var aero_factor: float = 0.01
@export var cp_front: float = 0.9
@export var cp_back: float = 0.4
@export_subgroup("Customization Factors")
@export_range(0,1) var energy_abs: float = 0.5
@export_range(0,1) var squish_factor: float = 0.5
@export var max_velocity: float = 10

@export_group("Debug")
@export_range(0,1) var smooth_factor: float = 0.5

var original_anchor_point_arr: PackedVector3Array
var anchor_point_arr: PackedVector3Array
var loc_acc: PackedVector3Array = []
var loc_vel: PackedVector3Array = []
var anch_spring_acc: PackedVector3Array = []
var anch_spring_vel: PackedVector3Array = []
var glob_acc: Vector3
var glob_vel: Vector3
var pos: PackedVector3Array = []
var old_pos: PackedVector3Array = []
var N: int
var radius: float
var pos_center: Vector3
var squeleton_center: Vector3

var collision_dir: Vector3
var anchor_vel: Vector3
var is_colliding: bool
var squeleton: Array[Node3D] = []
var neighbours: Array
var collision_triangles: Array = []

var bounce_force: Vector3

func add_glob_acc(acc: Vector3) -> void:
	glob_acc += acc
	
func add_glob_vel(vel: Vector3) -> void:
	glob_vel += vel

func add_loc_acc(acc: Vector3, i: int) -> void:
	loc_acc[i] += acc
	
func add_loc_vel(vel: Vector3, i: int) -> void:
	loc_vel[i] += vel
	
func get_squeleton_center() -> Vector3:
	return squeleton_center
	
func get_real_center() -> Vector3:
	return pos_center
	
func get_vertex_in_dir(dir: Vector3) -> int:
	var best_dot: float = -INF
	var index: int = -1
	for i in range(pos.size()):
		var n: Vector3 = (pos_center - pos[i]).normalized()
		var d: float = n.dot(dir.normalized())
		if d > best_dot:
			best_dot = d
			index = i
			if best_dot > 0.99: break
	return index
	
func teleport(new_pos: Vector3, reset_vel_acc: bool = true):
	if reset_vel_acc:
		glob_acc *= 0
		glob_vel *= 0
	for i in range(N):
		anchor_point_arr[i] -= squeleton_center
		if reset_vel_acc:
			loc_acc[i] *= 0
			loc_vel[i] *= 0
	pos = anchor_point_arr.duplicate()
	squeleton_center *= 0
	pos_center *= 0
	
func get_local_basis() -> Basis:
	var up: Vector3 = Vector3.UP if !is_colliding else collision_dir 
	var ref: Vector3 = Vector3.FORWARD if abs(up.dot(Vector3.RIGHT)) > 0.9 else Vector3.RIGHT
	var right: Vector3 = up.cross(ref).normalized()
	var forward: Vector3 = right.cross(up).normalized()
	return Basis(right, up, forward)
	
func _ready() -> void:
	mesh = MeshUtils.create_icosphere(0.5, 3)
	anchor_point_arr = MeshUtils.get_vertices(mesh)
	original_anchor_point_arr = anchor_point_arr.duplicate()
	pos = anchor_point_arr.duplicate()
	N = anchor_point_arr.size();
	loc_acc.resize(N)
	loc_vel.resize(N)
	anch_spring_acc.resize(N)
	anch_spring_vel.resize(N)
	old_pos.resize(N)
	mesh = MeshUtils.set_vertices(mesh, pos)
	var center: Vector3 = MeshUtils.get_center(pos)
	radius = (center - pos[0]).length()
	neighbours = MeshUtils.compute_neighbors(mesh)
	
	for i in range(N):
		var mat = StandardMaterial3D.new()
		mat.no_depth_test = true
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0, 1, 0, 0.1)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var dup = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = 0.01
		sphere.height = 0.02
		dup.mesh = sphere
		dup.material_override = mat
		dup.position = global_transform * anchor_point_arr[i]
		center_gizmo.get_parent().add_child(dup)
		squeleton.append(dup)
	_extract_collider_geometry()

func _extract_collider_geometry() -> void:
	if not colliders_parent: return
	
	for child in colliders_parent.get_children():
		if child is MeshInstance3D and child.mesh:
			var faces = child.mesh.get_faces() 
			var child_transform = child.global_transform
			
			for i in range(0, faces.size(), 3):
				var v0 = child_transform * faces[i]
				var v1 = child_transform * faces[i+1]
				var v2 = child_transform * faces[i+2]
				
				# FIXED: Swapped v2 and v1 to reverse the cross product direction!
				var normal = (v2 - v0).cross(v1 - v0).normalized()
				
				collision_triangles.append({
					"v0": v0, "v1": v1, "v2": v2, "normal": normal
				})
	
func _compute_glob_acc(dt: float) -> Vector3:
	var gravity: Vector3 = g * Vector3.DOWN
	var acc: Vector3 = gravity - air_damping * glob_vel
	return acc
	
func _compute_glob_vel(dt: float) -> Vector3:
	var vel: Vector3 = glob_acc * dt
	return vel
	
	
func _compute_MD(center: Vector3) -> Vector3:
	if !is_colliding: return Vector3.ZERO
	
	var mean: Vector3
	var defo_basis: Basis = get_local_basis()
	for i in range(N):
		var u: Vector3 = defo_basis.transposed() * (pos[i] - center)
		u.y = abs(u.y)
		mean += u.normalized() * (radius - u.length())
	mean /= N
	mean = mean.max(Vector3.ZERO)
	mean = defo_basis * mean
	return mean
	
func _integrate(dt: float) -> void:
	glob_acc += _compute_glob_acc(dt)
	glob_vel += _compute_glob_vel(dt)
	var loc_basis: Basis = get_local_basis()
	glob_vel = loc_basis.transposed() * glob_vel
	glob_vel.y = clamp(glob_vel.y, -max_velocity, max_velocity)
	glob_vel = loc_basis * glob_vel
	
	var mean_deformation: Vector3 = _compute_MD(pos_center) / 0.01
	for i in range(N):
		anchor_point_arr[i] += glob_vel * dt
		
		var anchor_offset: Vector3 = anchor_point_arr[i] - pos[i]
		var anchor_spring: Vector3 = k/m * anchor_offset
		
		var normal: Vector3 = (pos[i] - pos_center)
		var dist_to_center: float = normal.length()
		if dist_to_center > 1e-8: normal /= dist_to_center
		var angle: float = normal.angle_to(anchor_point_arr[i])
		var deformation: float = mean_deformation.cross(normal).length()
		var custom_radius: float = radius * (1 + deformation * squish_factor)
		var center_spring: Vector3 = k/m * normal * (custom_radius - dist_to_center)
		
		var speed: float = (loc_vel[i] + anch_spring_vel[i]).length()
		var vel_dir: Vector3 = Vector3.ZERO if speed < 1e-8 else (loc_vel[i] + anch_spring_vel[i]) / speed
		var aero_deform: float = speed * speed * aero_factor
		var cos_angle: float = vel_dir.dot(normal)
		var aero_force: Vector3
		if cos_angle < 0:
			var pressure: float = aero_deform * cp_back * abs(cos_angle)
			aero_force += -pressure * vel_dir
		
		var resistance: Vector3 = center_damping * loc_vel[i]
		
		anch_spring_acc[i] = anchor_spring - squeleton_damping * anch_spring_vel[i]
		anch_spring_vel[i] += anch_spring_acc[i] * dt
		loc_acc[i] += - resistance + center_spring + aero_force * dt
		loc_vel[i] += loc_acc[i] * dt
		pos[i] += loc_vel[i] * dt + anch_spring_vel[i] * dt
		pos[i] = pos_center + (pos[i] - pos_center).normalized() * max((pos[i] - pos_center).length(), radius / 2)
		loc_acc[i] *= 0
	glob_acc *= 0

func _ray_intersects_triangle(ray_origin: Vector3, ray_vector: Vector3, tri: Dictionary) -> Variant:
	const EPSILON = 0.0000001
	var v0 = tri.v0
	var v1 = tri.v1
	var v2 = tri.v2
	
	var edge1 = v1 - v0
	var edge2 = v2 - v0
	var h = ray_vector.cross(edge2)
	var a = edge1.dot(h)
	
	# If 'a' is close to 0, the ray is parallel to the triangle
	if a > -EPSILON and a < EPSILON:
		return null
		
	var f = 1.0 / a
	var s = ray_origin - v0
	var u = f * s.dot(h)
	
	# Ray misses the triangle
	if u < 0.0 or u > 1.0:
		return null
		
	var q = s.cross(edge1)
	var v = f * ray_vector.dot(q)
	
	# Ray misses the triangle
	if v < 0.0 or u + v > 1.0:
		return null
		
	var t = f * edge2.dot(q)
	
	# t <= 1.0 ensures the hit happens WITHIN the segment (between old_pos and new_pos)
	if t > EPSILON and t <= 1.0:
		return ray_origin + (ray_vector * t)
		
	return null

func _collide(dt: float, old_pos: PackedVector3Array) -> void:
	var inverse_transform = global_transform.inverse()
	is_colliding = false
	
	for i in range(N):
		# 1. Use the actual old position saved from before integration
		var global_start: Vector3 = global_transform * old_pos[i]
		var global_end: Vector3 = global_transform * pos[i]
		
		# 2. Ray goes FROM start TO end
		var ray_vector: Vector3 = global_end - global_start 
		
		var best_hit_pos: Variant = null
		var best_hit_normal: Vector3
		var min_dist: float = INF
		
		# 3. Test segment against every triangle in the world
		for tri in collision_triangles:
			# Pass global_start as the ray origin
			var hit_pos = _ray_intersects_triangle(global_start, ray_vector, tri)
			if hit_pos != null:
				var dist = global_start.distance_squared_to(hit_pos)
				if dist < min_dist:
					min_dist = dist
					best_hit_pos = hit_pos
					best_hit_normal = tri.normal
		
		# 4. If we hit something, resolve the collision
		if best_hit_pos != null:
			is_colliding = true
			
			# Convert world hit data back to the blob's local space
			var hit_local_pos: Vector3 = inverse_transform * best_hit_pos
			# For normals, multiplying by the transposed basis handles non-uniform scaling safely
			var hit_local_normal: Vector3 = (global_transform.basis.transposed() * best_hit_normal).normalized()
			
			# Project the vertex to the surface + a tiny offset
			pos[i] = hit_local_pos + (hit_local_normal * 0.001)
			
			loc_vel[i] -= hit_local_normal.normalized() * hit_local_normal.normalized().dot(loc_vel[i])

func _recenter(dt: float, old_pos_center) -> void:
	pos_center = MeshUtils.get_center(pos)
	if !is_colliding:
		return
	anchor_vel = (pos_center - old_pos_center).length() * collision_dir
	for i in range(N):
		anchor_point_arr[i] += anchor_vel
	squeleton_center += anchor_vel

func _handle_gizmos() -> void:
	if center_gizmo.get_parent_node_3d().visible: 
		center_gizmo.global_position = global_transform * MeshUtils.get_center(anchor_point_arr)
		for i in range(N):
			squeleton[i].global_position = global_transform * anchor_point_arr[i]

var iteration: int
var mean_fps: float
func _handle_fps() -> void:
	mean_fps += Engine.get_frames_per_second()
	iteration += 1
	if iteration == 20:
		print("fps : ", mean_fps / 20)
		mean_fps = 0
		iteration = 0

func _physics(dt: float) -> void:
	var old_pos = pos.duplicate()
	
	_integrate(dt)
	var old_center: Vector3 = MeshUtils.get_center(pos)
	squeleton_center = MeshUtils.get_center(anchor_point_arr)
	_collide(dt)
	print(collision_dir)
	_recenter(dt, old_center)
	old_pos = pos.duplicate()
	
func _refresh_mesh() -> void:
	var vertices = MeshUtils.smooth_mesh(mesh, pos, neighbours, smooth_factor)
	var mesh_center: Vector3 = MeshUtils.get_center(vertices)
	mesh = MeshUtils.set_vertices(mesh, vertices)
	center_node.global_position = global_transform * mesh_center
	custom_aabb = AABB()
	
var pause = false
func _process(dt: float) -> void:
	#_handle_fps()
	if Input.is_action_just_pressed("gizmos"):
		center_gizmo.get_parent_node_3d().visible = !center_gizmo.get_parent_node_3d().visible
	if Input.is_action_just_pressed("pause"): pause = !pause
	if !pause: 
		var safe_dt = min(dt, 1.0 / 45.0)
		_physics(safe_dt)
		
	_refresh_mesh()
	_handle_gizmos()
