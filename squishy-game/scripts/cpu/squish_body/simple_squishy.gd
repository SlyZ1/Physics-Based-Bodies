class_name Squishy
extends MeshInstance3D

@export_group("Scene")
@export var ground_node: Node3D
@export var center_node: Node3D
@export var center_gizmo: Node3D

@export_group("Movement")
@export var move_force: float = 10
@export var jump_force: float = 10

@export_group("Physics")
@export_subgroup("Global")
@export var g: float = 9.8
@export var air_damping: float = 0.1
@export var friction_factor: float = 3
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
var N: int
var radius: float
var pos_center: Vector3
var squeleton_center: Vector3

var anchor_vel: Vector3
var is_colliding: bool
var squeleton: Array[Node3D] = []
var neighbours: Array

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
	
func get_radius_in_dir(dir: Vector3) -> float:
	var best_dot = -INF
	var best_radius = radius
	for i in range(pos.size()):
		var n = (pos_center - pos[i]).normalized()
		var d = n.dot(dir.normalized())
		if d > best_dot:
			best_dot = d
			best_radius = (pos_center - pos[i]).length()
	return best_radius
	
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
	
func _ready() -> void:
	mesh = MeshUtils.create_icosphere(0.5, 4)
	anchor_point_arr = MeshUtils.get_vertices(mesh)
	original_anchor_point_arr = anchor_point_arr.duplicate()
	pos = anchor_point_arr.duplicate()
	N = anchor_point_arr.size();
	loc_acc.resize(N)
	loc_vel.resize(N)
	anch_spring_acc.resize(N)
	anch_spring_vel.resize(N)
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
	if is_colliding:
		var u = anchor_vel.normalized()
		var dot_vel: float = u.dot(glob_vel + vel * 0.55)
		vel -= u * min(dot_vel, 0) * (2 - energy_abs)
		#vel += anchor_vel / dt
	
	return vel
	
func _compute_MD(center: Vector3) -> Vector3:
	var mean: Vector3
	for i in range(N):
		var u: Vector3 = (pos[i] - center).abs()
		mean += u.normalized() * (radius - u.length())
	mean /= N
	mean = mean.max(Vector3.ZERO)
	return mean
	
func _integrate(dt: float) -> void:
	glob_acc += _compute_glob_acc(dt)
	glob_vel += _compute_glob_vel(dt)
	
	var mean_deformation: Vector3 = _compute_MD(pos_center) / 0.02
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
		loc_acc[i] *= 0
	glob_acc *= 0
		
func _collide(dt: float) -> void:
	var inverse_transform = global_transform.inverse()
	var zero_world: Vector3 = inverse_transform * Vector3.ZERO
	var ground_up: Vector3 = (global_transform.basis.transposed() * ground_node.global_basis.y).normalized()
	var ground_pos: float = (inverse_transform * ground_node.global_position).dot(ground_up)
	is_colliding = false
	for i in range(N):
		var v_pos: float = pos[i].dot(ground_up)
		pos[i] = (pos[i] - ground_up * v_pos) + ground_up * max(v_pos, ground_pos)
		if v_pos < ground_pos:
			loc_vel[i] -= ground_up * ground_up.dot(loc_vel[i])
			is_colliding = true

func _recenter(dt: float, old_pos_center) -> void:
	pos_center = MeshUtils.get_center(pos)
	if !is_colliding:
		return
	anchor_vel = pos_center - old_pos_center

func _handle_gizmos() -> void:
	if center_gizmo.get_parent_node_3d().visible: 
		center_gizmo.global_position = global_transform * MeshUtils.get_center(anchor_point_arr)
		for i in range(N):
			squeleton[i].global_position = global_transform * pos[i]

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
	var old_pos_center = MeshUtils.get_center(pos)
	_collide(dt)
	_recenter(dt, old_pos_center)
	squeleton_center = MeshUtils.get_center(anchor_point_arr)
	
func _refresh_mesh() -> void:
	var vertices = MeshUtils.smooth_mesh(mesh, pos, neighbours, smooth_factor)
	mesh = MeshUtils.set_vertices(mesh, vertices)
	center_node.global_position = global_transform * MeshUtils.get_center(vertices)
	custom_aabb = AABB()
	
var pause = false
func _process(dt: float) -> void:
	dt = clamp(dt, 0, 0.05)
	#dt /= 3
	if Input.is_action_just_pressed("gizmos"):
		center_gizmo.get_parent_node_3d().visible = !center_gizmo.get_parent_node_3d().visible
	if Input.is_action_just_pressed("pause"): pause = !pause
	if !pause: _physics(dt)
		
	_refresh_mesh()
	_handle_gizmos()
	_handle_fps()
