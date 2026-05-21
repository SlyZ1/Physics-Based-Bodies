extends MeshInstance3D

@export_group("Scene")
@export var ground_node: Node3D
@export var center_node: Node3D

@export_group("Movement")
@export var move_force: float = 10
@export var jump_force: float = 10

@export_group("Physics")
@export var k: float = 50
@export var m: float = 0.1
@export var g: float = 9.8
@export var damping: float = 10
@export var air_damping: float = 0.1
@export_range(0,1) var energy_abs: float = 0.5
@export_range(0,1) var squish_factor: float = 0.5
@export var friction_factor: float = 3

@export_group("Debug")
@export_range(0,1) var smooth_factor: float = 0.5

var anchor_point_arr: PackedVector3Array
var loc_acc: PackedVector3Array = []
var loc_vel: PackedVector3Array = []
var glob_acc: Vector3
var glob_vel: Vector3
var pos: PackedVector3Array = []
var N: int
var radius: float

var anchor_vel: Vector3
var is_colliding: bool
var squeleton: Array[Node3D] = []
var neighbours: Array

const inputs = preload("res://scripts/cpu/inputs.gd")
const mesh_utils = preload("res://scripts/cpu/mesh_utils.gd")

func _ready() -> void:
	mesh = mesh_utils.close_sphere(mesh)
	anchor_point_arr = mesh_utils.get_vertices(mesh)
	pos = anchor_point_arr.duplicate()
	N = pos.size();
	loc_acc.resize(N)
	loc_vel.resize(N)
	mesh = mesh_utils.set_vertices(mesh, pos)
	var center: Vector3 = mesh_utils.get_center(pos)
	radius = (center - pos[0]).length()
	neighbours = mesh_utils.compute_neighbors(mesh)
	
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
		center_node.get_parent().add_child(dup)
		squeleton.append(dup)
	
func _shrink(dt: float, dir: Vector3, force: float) -> void:
	var center: Vector3 = mesh_utils.get_center(pos)
	for i in range(N):
		loc_vel[i] -= dir * dir.dot(pos[i] - center) * force * dt
		
func _stretch(dt: float) -> void:
	var center: Vector3 = mesh_utils.get_center(anchor_point_arr)
	var dot_prod: float = glob_acc.dot(glob_vel)
	var dir: Vector3 = glob_acc.normalized()
	for i in range(N):
		var offset: Vector3 = (anchor_point_arr[i] - center).normalized()
		var custom_radius: float = radius * abs(offset.dot(glob_vel.normalized()))
		anchor_point_arr[i] = center + offset * custom_radius
	
func _compute_glob_acc(dt: float) -> Vector3:
	var gravity: Vector3 = g * Vector3.DOWN
	var acc: Vector3 = gravity - air_damping * glob_vel
	
	if is_colliding:
		var u = anchor_vel.normalized()
		var dot_vel: float = u.dot(glob_vel)
		var tang_vel: Vector3 = glob_vel - u * dot_vel
		var ground_friction: Vector3 = -tang_vel * friction_factor
		acc += ground_friction
	
	var move_inputs: Vector2 = inputs.get_move_inputs()
	var move_up: Vector3 = Vector3.UP if anchor_vel.length() < 0.005 else anchor_vel.normalized() 
	var move_right: Vector3 = move_up.cross(Vector3.BACK)
	var move_forward: Vector3 = move_right.cross(move_up)
	acc += (move_right * move_inputs.x - move_forward * move_inputs.y) * move_force
	if inputs.jumps(): acc += Vector3.UP * jump_force / dt
	
	return acc
	
func _compute_glob_vel(dt: float) -> Vector3:
	var vel: Vector3 = glob_acc * dt
	if is_colliding:
		var u = anchor_vel.normalized()
		var dot_vel: float = u.dot(glob_vel + vel * 0.5)
		vel -= u * min(dot_vel, 0) * (2 - energy_abs)
		vel += 0.5 * anchor_vel / dt
	
	if inputs.jumps(): glob_vel -= Vector3.DOWN * Vector3.DOWN.dot(glob_vel)
	
	return vel
	
func _compute_MD(center: Vector3) -> Vector3:
	var mean: Vector3
	for i in range(N):
		var u: Vector3 = (pos[i] - center).abs()
		var v: Vector3 = (anchor_point_arr[i] - center).abs()
		mean += v - u
	mean /= N
	mean = mean.max(Vector3.ZERO)
	return mean
	
func _compute_MD_2(center: Vector3) -> Vector3:
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
	var center: Vector3 = mesh_utils.get_center(pos)
	var deformation_rescale_factor: float = 0.1
	var mean_deformation = _compute_MD_2(center) / 0.02
	#_stretch(dt)
	for i in range(N):
		anchor_point_arr[i] += glob_vel * dt
		
		var anchor_offset: Vector3 = anchor_point_arr[i] - pos[i]
		var anchor_spring: Vector3 = k/m * anchor_offset
		
		var center_offset: Vector3 = (pos[i] - center)
		var dist_to_center: float = center_offset.length()
		center_offset /= dist_to_center
		var angle: float = center_offset.angle_to(anchor_point_arr[i])
		var deformation: float = mean_deformation.cross(center_offset).length()
		var custom_radius: float = radius * (1 + deformation * squish_factor)
		var center_spring: Vector3 = k/m * center_offset * (custom_radius - dist_to_center)
		
		var resistance: Vector3 = damping * loc_vel[i]
		
		loc_acc[i] = anchor_spring - resistance + center_spring
		loc_vel[i] += loc_acc[i] * dt
		pos[i] += loc_vel[i] * dt
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

func _recenter(dt: float, anchor_center) -> void:
	var new_anchor_center: Vector3 = mesh_utils.get_center(pos)
	if !is_colliding:
		return
	anchor_vel = new_anchor_center - anchor_center

func _handle_gizmos():
	if center_node.get_parent_node_3d().visible: 
		center_node.global_position = global_transform * mesh_utils.get_center(anchor_point_arr)
		for i in range(N):
			squeleton[i].global_position = global_transform * pos[i]

var iteration: int
var mean_fps: float
func _handle_fps():
	mean_fps += Engine.get_frames_per_second()
	iteration += 1
	if iteration == 20:
		print("fps : ", mean_fps / 20)
		mean_fps = 0
		iteration = 0

func _physics(dt: float) -> void:
	_integrate(dt)
	var anchor_center = mesh_utils.get_center(pos)
	_collide(dt)
	_recenter(dt, anchor_center)

var pause = false
func _process(dt: float) -> void:
	dt = clamp(dt, 0, 0.05)
	if Input.is_action_just_pressed("gizmos"):
		center_node.get_parent_node_3d().visible = !center_node.get_parent_node_3d().visible
	if Input.is_action_just_pressed("pause"): pause = !pause
	if !pause: _physics(dt)
		
	var vertices = mesh_utils.smooth_mesh(mesh, pos, neighbours, smooth_factor)
	mesh = mesh_utils.set_vertices(mesh, vertices)
	custom_aabb = AABB()
	
	_handle_gizmos()
	_handle_fps()
