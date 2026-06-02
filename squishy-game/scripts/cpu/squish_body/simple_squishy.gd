class_name Squishy
extends MeshInstance3D

@export_group("Scene")
@export var ground_nodes: Array[Node3D]
@export var center_node: Node3D
@export var center_gizmo: Node3D

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
@export_range(0,1) var horizontal_hardness
@export_range(0,1) var energy_abs: float = 0.5
@export_range(0,1) var squish_factor: float = 0.583
@export var max_velocity: float = 15

@export_group("Debug")
@export_range(0,1) var smooth_factor: float = 1

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

var mean_collision_normal: Vector3
var collision_dir: Vector3
var anchor_vel: Vector3
var is_colliding: bool
var squeleton: Array[Node3D] = []
var neighbours: Array

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
		
		var resistance: Vector3 = center_damping * loc_vel[i]
		
		anch_spring_acc[i] = anchor_spring - squeleton_damping * anch_spring_vel[i]
		anch_spring_vel[i] += anch_spring_acc[i] * dt
		loc_acc[i] += - resistance + center_spring
		loc_vel[i] += loc_acc[i] * dt
		pos[i] += loc_vel[i] * dt + anch_spring_vel[i] * dt
		# To make it harder (less soft) on horizontal movement
		pos[i] += (glob_vel - collision_dir * collision_dir.dot(glob_vel)) * horizontal_hardness * dt
		# Restrain maximum squish
		pos[i] = pos_center + (pos[i] - pos_center).normalized() * max((pos[i] - pos_center).length(), radius / 2)
		loc_acc[i] *= 0
	glob_acc *= 0
		
func _collide(dt: float) -> void:
	is_colliding = false
	var inverse_transform = global_transform.inverse()
	var zero_world: Vector3 = inverse_transform * Vector3.ZERO
	var new_collision_dir: Vector3
	var repulsion_force: Vector3
	for ground_node in ground_nodes:
		var ground_up: Vector3 = (global_transform.basis.transposed() * ground_node.global_basis.y).normalized()
		var ground_center: Vector3 = inverse_transform * ground_node.global_position
		var ground_pos: float = ground_center.dot(ground_up) + 1e-2
		for i in range(N):
			var v_pos: float = pos[i].dot(ground_up)
			var old_v_pos: float = old_pos[i].dot(ground_up)
			var v_pos_collide: bool = v_pos < ground_pos && (pos[i] - ground_center).length() < 10 * sqrt(2)
			var old_v_pos_collide: bool = old_v_pos < ground_pos
			if v_pos_collide && !old_v_pos_collide:
				mean_collision_normal += ground_up
				if Vector3.UP.dot(ground_up) > 0:
					var test = (squeleton_center - anchor_point_arr[i]).normalized()
					new_collision_dir += test
				is_colliding = true
				
				pos[i] = (pos[i] - ground_up * v_pos) + ground_up * max(v_pos, ground_pos + 1e-4)
				loc_vel[i] -= (2 - energy_abs) * ground_up * ground_up.dot(loc_vel[i])
				
				var anchor_offset: Vector3 = anchor_point_arr[i] - pos[i]
				var anchor_spring: Vector3 = k/m * anchor_offset
				
				var normal: Vector3 = (pos[i] - pos_center)
				var dist_to_center: float = normal.length()
				if dist_to_center > 1e-6: normal /= dist_to_center
				var angle: float = normal.angle_to(anchor_point_arr[i])
				var center_spring: Vector3 = k/m * normal * (radius - dist_to_center)
				
				var dot_prod: float = ground_up.dot(anchor_spring + center_spring)
				var hardness: float = 0
				if ground_up.dot(Vector3.UP) < 0.1:
					hardness = horizontal_hardness
				var softness_factor: float = 1 + 6 * pow(hardness, 2)
				var energy_abs_factor: float = 1 + 1.5 * (1 - energy_abs)
				glob_vel -= softness_factor * ground_up * min(dot_prod, 0) * energy_abs_factor * dt / N
	if is_colliding && new_collision_dir.length() > 1e-8: 
		collision_dir = new_collision_dir.normalized()
	if is_colliding && mean_collision_normal.length() > 1e-5:
		mean_collision_normal = mean_collision_normal.normalized()
	else: mean_collision_normal = collision_dir

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
	_integrate(dt)
	var old_center: Vector3 = MeshUtils.get_center(pos)
	squeleton_center = MeshUtils.get_center(anchor_point_arr)
	_collide(dt)
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
