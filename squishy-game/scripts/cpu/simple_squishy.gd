extends MeshInstance3D

@export_group("Other")
@export var ground: Node3D

@export_group("Physics")
@export var k: float = 50
@export var m: float = 0.1
@export var g: float = 9.8
@export var damping: float = 10
@export var air_damping: float = 0.1
@export_range(0,1) var energy_abs: float = 0.5
@export_range(0,1) var squish_factor: float = 0.5
@export var friction_factor: float = 3

var anchor_point_arr: PackedVector3Array
var loc_acc: PackedVector3Array = []
var loc_vel: PackedVector3Array = []
var glob_acc: Vector3
var glob_vel: Vector3
var pos: PackedVector3Array = []
var N: int
var radius: float

func _get_vertices() -> PackedVector3Array:
	var mesh_data: Array = mesh.surface_get_arrays(0)
	return mesh_data[Mesh.ARRAY_VERTEX]
	
func _set_vertices(vertices: PackedVector3Array) -> void:
	var surface: Array = mesh.surface_get_arrays(0)
	surface[Mesh.ARRAY_VERTEX] = vertices
	
	var arr_mesh: ArrayMesh = ArrayMesh.new()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface)
	mesh = arr_mesh
	
func _get_center(arr: PackedVector3Array) -> Vector3:
	var center: Vector3 = Vector3.ZERO
	for i in range(N):
		center += arr[i]
	center /= N
	return center

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	anchor_point_arr = _get_vertices()
	pos = _get_vertices()
	N = pos.size();
	loc_acc.resize(N)
	loc_vel.resize(N)
	_set_vertices(pos)
	var center: Vector3 = _get_center(pos)
	radius = (center - pos[0]).length()
	
func _compute_glob_acc() -> Vector3:
	return g * Vector3.DOWN - air_damping * glob_vel
	
func _compute_MD(center: Vector3) -> Vector3:
	var mean: Vector3
	for i in range(N):
		var u: Vector3 = pos[i] - center
		if u.dot(Vector3.UP) < 0: u *= -1
		mean += u.normalized() * (u.length() - radius)
	mean = Vector3(max(-mean.x, 0), max(-mean.y, 0), max(-mean.z, 0))
	mean /= N
	return mean
	
func _integrate(dt: float) -> void:
	glob_acc += _compute_glob_acc()
	glob_vel += glob_acc * dt
	var center: Vector3 = _get_center(pos)
	var deformation_rescale_factor: float = 0.02 # rescale factor
	var mean_deformation = _compute_MD(center).limit_length(deformation_rescale_factor) / deformation_rescale_factor
	for i in range(N):
		anchor_point_arr[i] += glob_vel * dt
		
		var anchor_offset: Vector3 = anchor_point_arr[i] - pos[i]
		var anchor_spring: Vector3 = k/m * anchor_offset
		
		var center_offset: Vector3 = pos[i] - center
		var dist_to_center: float = center_offset.length()
		var angle: float = center_offset.angle_to(anchor_point_arr[i])
		var deformation: float = mean_deformation.cross(center_offset / dist_to_center).length()
		var custom_radius: float = radius * (1 + deformation * squish_factor)
		var center_spring: Vector3 = k/m * center_offset / dist_to_center * (custom_radius - dist_to_center)
		
		var resistance: Vector3 = damping * loc_vel[i]
		
		loc_acc[i] = anchor_spring - resistance + center_spring
		loc_vel[i] += loc_acc[i] * dt
		pos[i] += loc_vel[i] * dt
		
func _collide() -> void:
	var inverse_transform = global_transform.inverse()
	var zero_world: Vector3 = inverse_transform * Vector3.ZERO
	var ground_up: Vector3 = (global_transform.basis.transposed() * ground.global_basis.y).normalized()
	var ground_pos: float = (inverse_transform * ground.global_position).dot(ground_up)
	var I: float = (1.0/6.0) * (m * N)
	for i in range(N):
		var v_pos: float = pos[i].dot(ground_up)
		pos[i] = (pos[i] - ground_up * v_pos) + ground_up * max(v_pos, ground_pos)
		if v_pos < ground_pos:
			loc_vel[i] -= ground_up * ground_up.dot(loc_vel[i])
			var offset: Vector3 = pos[i] - anchor_point_arr[i]
			var force: Vector3 = ground_up * ground_up.dot(loc_vel[i] + glob_vel)
			var torque: Vector3 = offset.cross(force)

func _recenter(dt: float, anchor_center) -> void:
	var new_anchor_center: Vector3 = _get_center(pos)
	var anchor_vel: Vector3 = new_anchor_center - anchor_center
	if anchor_vel.length() < 0.001:
		glob_acc *= 0
		return
	
	var u: Vector3 = anchor_vel.normalized()
	var dot_vel: float = u.dot(glob_vel)
	var tang_vel: Vector3 = glob_vel - u * dot_vel
	var friction: Vector3 = -tang_vel * dot_vel * friction_factor
	print(tang_vel.normalized())
	glob_acc = -u * u.dot(_compute_glob_acc()) + friction
	glob_vel -= u * min(dot_vel, 0) * (2 - energy_abs)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(dt: float) -> void:
	dt = clamp(dt, 0, 0.05)
	_integrate(dt)
	var anchor_center = _get_center(pos)
	_collide()
	_recenter(dt, anchor_center)
	_set_vertices(pos)
	custom_aabb = AABB()
