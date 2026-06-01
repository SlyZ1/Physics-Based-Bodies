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

var collision_dir: Vector3 = Vector3.UP
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
	collision_triangles = MeshCollisions.extract_collider_geometry(colliders_parent)
	
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

func _collide(dt: float, old_pos: PackedVector3Array) -> void:
	var inverse_transform = global_transform.inverse()
	is_colliding = false
	var new_collision_dir: Vector3 = Vector3.ZERO
	
	for i in range(N):
		var global_start: Vector3 = global_transform * old_pos[i]
		var global_end: Vector3 = global_transform * pos[i]
		
		var best_hit = MeshCollisions.intersect_nearest_triangle(collision_triangles, global_start, global_end)
		var best_hit_pos = best_hit["pos"]
		var best_hit_normal = best_hit["normal"]

		if best_hit_pos != null:
			is_colliding = true
			
			var hit_local_pos: Vector3 = inverse_transform * best_hit_pos
			var hit_local_normal: Vector3 = (global_transform.basis.transposed() * best_hit_normal).normalized()
			
			# Little offset to ensure the mesh stays on top of the collider
			pos[i] = hit_local_pos + (hit_local_normal * 1e-2)
			
			# Accumulate collision direction
			if hit_local_normal.dot(Vector3.UP) > 0:
				var test = (squeleton_center - anchor_point_arr[i]).normalized()
				new_collision_dir += test
			
			var normal_velocity: float = hit_local_normal.dot(loc_vel[i])
			if normal_velocity < 0:
				loc_vel[i] -= (2 - energy_abs) * hit_local_normal * normal_velocity

			var anchor_offset: Vector3 = anchor_point_arr[i] - pos[i]
			var anchor_spring: Vector3 = k/m * anchor_offset
			
			var normal: Vector3 = (pos[i] - pos_center)
			var dist_to_center: float = normal.length()
			if dist_to_center > 1e-6: normal /= dist_to_center
			var center_spring: Vector3 = k/m * normal * (radius - dist_to_center)
			
			var dot_prod: float = hit_local_normal.dot(anchor_spring + center_spring)
			glob_vel -= best_hit_normal * min(dot_prod, 0) * (1 + 1.5 * (1 - energy_abs)) * dt / N

	if is_colliding: 
		if new_collision_dir.length() == 0.0:
			new_collision_dir = Vector3.UP
		collision_dir = new_collision_dir.normalized()


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
	_collide(dt, old_pos)
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
	_handle_fps()
	if Input.is_action_just_pressed("gizmos"):
		center_gizmo.get_parent_node_3d().visible = !center_gizmo.get_parent_node_3d().visible
	if Input.is_action_just_pressed("pause"): pause = !pause
	if !pause: 
		var safe_dt = min(dt, 1.0 / 45.0)
		_physics(safe_dt)
		
	_refresh_mesh()
	_handle_gizmos()
