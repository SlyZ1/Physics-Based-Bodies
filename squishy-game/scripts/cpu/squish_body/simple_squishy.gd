class_name Squishy
extends MeshInstance3D

@export_group("Scene")
@export var colliders_parent: Node
@export var center_node: Node3D
@export var center_gizmo: Node3D
@export var gizmo1: Node3D
@export var gizmo2: Node3D

@export_group("Physics")
@export_subgroup("Global")
@export var g: float = 20
@export var air_damping: float = 0.01
@export_subgroup("Springs")
@export var k: float = 50
@export var m: float = 0.2
@export var center_damping: float = 4
@export var squeleton_damping: float = 20
@export_subgroup("Customization Factors")
@export_range(0,1) var horizontal_hardness: float = 1
@export_range(0,1) var energy_abs: float = 0.5
@export_range(0,1) var squish_factor: float = 0.583
@export var max_velocity: float = 15

@export_group("Debug")
@export_range(0,1) var smooth_factor: float = 1

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

var mean_collision_point: Vector3
var mean_collision_normal: Vector3
var mean_penetration: float
var collision_dir: Vector3 = Vector3.UP
var is_colliding: bool

var anchor_vel: Vector3
var squeleton: Array[Node3D] = []
var neighbours: Array
var collision_BVH: BoundingSphereTree.SphereNode

var bounce_force: Vector3
static var core: Squishy

func add_glob_acc(acc: Vector3) -> void:
	glob_acc += acc
	
func add_glob_vel(vel: Vector3) -> void:
	glob_vel += vel

func add_loc_acc(acc: Vector3, i: int) -> void:
	loc_acc[i] += acc
	
func add_loc_vel(vel: Vector3, i: int) -> void:
	loc_vel[i] += vel
	
func get_squeleton_center() -> Vector3:
	return global_transform * squeleton_center
	
func get_real_center() -> Vector3:
	return global_transform * pos_center
	
func get_local_real_center() -> Vector3:
	return pos_center
	
func get_pos() -> PackedVector3Array:
	return pos
	
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
		anchor_point_arr[i] -= squeleton_center - new_pos
		if reset_vel_acc:
			loc_acc[i] *= 0
			loc_vel[i] *= 0
	pos = anchor_point_arr.duplicate()
	squeleton_center = new_pos
	pos_center *= 0
	
func get_local_basis(up_vec: Vector3) -> Basis:
	var up: Vector3 = Vector3.UP if up_vec.length() < 1e-8 else up_vec
	var ref: Vector3 = Vector3.FORWARD if abs(up.dot(Vector3.RIGHT)) > 0.9 else Vector3.RIGHT
	var right: Vector3 = up.cross(ref).normalized()
	var forward: Vector3 = right.cross(up).normalized()
	return Basis(right, up, forward)
	
func _ready() -> void:
	# INITIALIZE ARRAYS AND DATA
	core = self
	mesh = MeshUtils.create_icosphere(0.5, 3)
	anchor_point_arr = MeshUtils.get_vertices(mesh)
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
	
	# SETUP GIZMOS (for debug purposes)
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
	collision_BVH = MeshCollisions.create_collision_BVH_object(colliders_parent)
	
func _compute_glob_acc() -> Vector3:
	var gravity: Vector3 = g * Vector3.DOWN
	var acc: Vector3 = gravity - air_damping * glob_vel
	return acc
	
func _compute_glob_vel(dt: float) -> Vector3:
	var vel: Vector3 = glob_acc * dt
	return vel
	
# COMPUTE MEAN DEFORMATION
func _compute_MD(center: Vector3) -> Vector3:
	if !is_colliding: return Vector3.ZERO
	
	var mean: Vector3 = Vector3.ZERO
	var defo_basis: Basis = get_local_basis(mean_collision_normal)
	for i in range(N):
		var u: Vector3 = defo_basis.transposed() * (pos[i] - center)
		u.y = abs(u.y)
		mean += u.normalized() * max(radius - u.length(), 0)
	mean /= N
	mean = mean.max(Vector3.ZERO)
	mean = defo_basis * mean
	return mean
	
func _deformation_on_normal(md: Vector3, origin: Vector3, vertex: Vector3) -> float:
	var normal: Vector3 = (vertex - origin).normalized()
	var cross: float = md.normalized().cross(normal).length()
	var deformation: float = cross * md.length()
	return deformation
	
func _integrate(dt: float) -> void:
	glob_acc += _compute_glob_acc()
	glob_vel += _compute_glob_vel(dt)
	
	# CLAMP MAX "VERTICAL" (along normal) VELOCITY
	var loc_basis: Basis = get_local_basis(collision_dir)
	glob_vel = loc_basis.transposed() * glob_vel
	glob_vel.y = clamp(glob_vel.y, -max_velocity, max_velocity)
	glob_vel = loc_basis * glob_vel
	
	var mean_deformation: Vector3 = _compute_MD(pos_center) / 0.01
	for i in range(N):
		anchor_point_arr[i] += glob_vel * dt
		
		# REAL CENTER SPRING FORCE
		var normal: Vector3 = (pos[i] - pos_center)
		var dist_to_center: float = normal.length()
		if dist_to_center > 1e-8: normal /= dist_to_center
		var deformation: float = _deformation_on_normal(mean_deformation, pos_center, pos[i])
		var custom_radius: float = radius * (1 + deformation * squish_factor)
		var center_spring: Vector3 = k/m * normal * (custom_radius - dist_to_center)
		
		# SQUELETON SPRING FORCE
		var custom_anchor_point: Vector3 = (anchor_point_arr[i] - squeleton_center).normalized()
		custom_anchor_point = custom_anchor_point * custom_radius + squeleton_center
		var anchor_offset: Vector3 = anchor_point_arr[i] - pos[i]
		var anchor_spring: Vector3 = k/m * anchor_offset
		
		# SQUELETON SPRINGS ACC & VEL
		anch_spring_acc[i] = anchor_spring - squeleton_damping * anch_spring_vel[i]
		anch_spring_vel[i] += anch_spring_acc[i] * dt
		
		# OTHER ACC & VEL
		loc_acc[i] += center_spring - center_damping * loc_vel[i]
		loc_vel[i] += loc_acc[i] * dt
		
		# INTEGRATION
		pos[i] += (loc_vel[i] + anch_spring_vel[i]) * dt
		
		# HORIZONTAL HARDNESS
		var collision_up: Vector3 = mean_collision_normal
		if abs(collision_up.dot(Vector3.UP)) < 0.6: collision_up = Vector3.UP
		pos[i] += (glob_vel - collision_up * glob_vel.dot(collision_up)) * horizontal_hardness * 0.7 * dt
		
		# RESTRAIN MAX SQUISH
		pos[i] = pos_center + (pos[i] - pos_center).normalized() * max((pos[i] - pos_center).length(), radius / 2)
		
		loc_acc[i] *= 0
	glob_acc *= 0

func _collide(dt: float, old_center: Vector3) -> void:
	var global_squishy_distance = 0.0
	old_center = MeshUtils.get_center(pos)
	for i in range(N):
		# no need to apply global_transform as scale is (1,1,1) and we are treating distances
		var dist_sq: float = (old_center - pos[i]).length_squared()
		global_squishy_distance = max(global_squishy_distance, dist_sq)
	global_squishy_distance = sqrt(global_squishy_distance)
	var reduc: float = 0
	global_squishy_distance *= 1 - reduc + reduc * clamp(1 - glob_vel.length() / max_velocity, 0, 1)

	var collision_triangles = BoundingSphereTree.query_sphere(collision_BVH, global_transform * old_center, global_squishy_distance)
	#print(collision_triangles.size())
	var inverse_transform = global_transform.inverse()
	is_colliding = false
	var new_collision_dir: Vector3 = Vector3.ZERO
	
	for i in range(N):
		var global_start: Vector3 = global_transform * old_pos[i]
		var global_end: Vector3 = global_transform * pos[i]
		
		# FIND INTERSECTION
		var best_hits = MeshCollisions.intersect_nearest_triangles(collision_triangles, get_real_center(), global_start, global_end)
		if len(best_hits) == 0:
			continue
		var best_hit_pos = best_hits[0]["pos"]
		var best_hit_normal = best_hits[0]["normal"]
		var best_hit_dist = best_hits[0]["dist"]
		if len(best_hits) == 2:
			var snd_best_hit_normal = best_hits[1]["normal"]
			var snd_best_hit_dist = best_hits[1]["dist"]
			
			best_hit_pos += snd_best_hit_normal * sqrt(snd_best_hit_dist)
			best_hit_normal = snd_best_hit_normal * snd_best_hit_dist + best_hit_normal * best_hit_dist
			best_hit_normal = best_hit_normal.normalized()

		if best_hit_pos != null:
			is_colliding = true
			
			var hit_local_pos: Vector3 = inverse_transform * best_hit_pos
			var hit_local_normal: Vector3 = (global_transform.basis.transposed() * best_hit_normal).normalized()
			
			# DEPENETRATE
			pos[i] = hit_local_pos + (hit_local_normal * 1e-3)
			var normal_velocity: float = hit_local_normal.dot(loc_vel[i])
			if normal_velocity < 0:
				loc_vel[i] -= (2 - energy_abs) * hit_local_normal * normal_velocity
			
			# ACCUMULATE COLLISION INFORMATIONS
			mean_collision_point += pos[i]
			mean_collision_normal += hit_local_normal
			if abs(hit_local_normal.dot(Vector3.UP)) > 0.5:
				new_collision_dir += (squeleton_center - anchor_point_arr[i]).normalized()
			
			# SQUELETON SPRING REPULSION
			var anchor_offset: Vector3 = anchor_point_arr[i] - pos[i]
			var anchor_spring: Vector3 = k/m * anchor_offset
			
			# CENTER SPRING REPULSION
			var normal: Vector3 = (pos[i] - pos_center)
			var dist_to_center: float = normal.length()
			if dist_to_center > 1e-6: normal /= dist_to_center
			var center_spring: Vector3 = k/m * normal * (radius - dist_to_center)
			
			# REBOUND PARAMETERS
			var dot_prod: float = hit_local_normal.dot(anchor_spring + center_spring)
			var hardness: float = horizontal_hardness if abs(hit_local_normal.dot(Vector3.UP)) < 0.5 else 0.0
			var hardness_factor: float = 1 + 7 * pow(hardness, 2)
			var energy_abs_factor: float = 1 + 1.5 * (1 - energy_abs)
			
			# REBOUND
			glob_vel -= hardness_factor * hit_local_normal * min(dot_prod, 0) * energy_abs_factor * dt / N


	collision_dir /= N
	if is_colliding && new_collision_dir.length() > 1e-2:
		collision_dir = new_collision_dir.normalized()
	else:
		collision_dir = Vector3.UP
	mean_collision_normal /= N
	mean_penetration =  mean_collision_normal.length()
	if is_colliding && mean_collision_normal.length() > 1e-2:
		mean_collision_normal = mean_collision_normal.normalized()
	else: mean_collision_normal = Vector3.UP

func _recenter(old_pos_center) -> void:
	pos_center = MeshUtils.get_center(pos)
	if !is_colliding:
		return
	anchor_vel = (pos_center - old_pos_center).length() * collision_dir
	for i in range(N):
		anchor_point_arr[i] += anchor_vel
	squeleton_center += anchor_vel

func _handle_gizmos() -> void:
	if center_gizmo.get_parent_node_3d().visible: 
		gizmo1.global_position = global_transform * (pos_center + mean_collision_normal)
		gizmo2.global_position = global_transform * (pos_center + collision_dir)
		center_gizmo.global_position = global_transform * pos_center
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
	_integrate(dt)
	var old_center: Vector3 = MeshUtils.get_center(pos)
	squeleton_center = MeshUtils.get_center(anchor_point_arr)
	_collide(dt, old_center)
	_recenter(old_center)
	old_pos = pos.duplicate()
	
func _refresh_mesh() -> void:
	var vertices = MeshUtils.smooth_mesh(mesh, pos, neighbours, smooth_factor)
	var mesh_center: Vector3 = MeshUtils.get_center(vertices)
	mesh = MeshUtils.set_vertices(mesh, vertices)
	center_node.global_position = global_transform * mesh_center
	custom_aabb = AABB()
	
var pause = false
func _process(dt: float) -> void:
	_handle_fps()
	if Input.is_action_just_pressed("gizmos"):
		center_gizmo.get_parent_node_3d().visible = !center_gizmo.get_parent_node_3d().visible
	if Input.is_action_just_pressed("pause"): pause = !pause
	if !pause: 
		var safe_dt = min(dt, 1.0 / 45.0)
		_physics(safe_dt)
		
	_refresh_mesh()
	_handle_gizmos()
