extends MeshInstance3D

@export var k: float = 50
@export var m: float = 0.1
@export var g: float = 9.8
@export var damping: float = 10
@export var air_damping: float = 0.1
@export var energy_abs: float = 0.5

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
	
func _calculate_center(arr: PackedVector3Array) -> Vector3:
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
	var center: Vector3 = _calculate_center(pos)
	radius = (center - pos[0]).length()
	
func _integrate(dt: float) -> void:
	glob_acc += g * Vector3.DOWN - air_damping * glob_vel
	glob_vel += glob_acc * dt
	var center: Vector3 = _calculate_center(pos)
	for i in range(N):
		anchor_point_arr[i] += glob_vel * dt
		var anchor_offset: Vector3 = anchor_point_arr[i] - pos[i]
		var anchor_spring = k/m * anchor_offset
		var center_offset: Vector3 = pos[i] - center
		var center_spring = k/(2*m) * center_offset.normalized() * (radius - center_offset.length())
		var resistance: Vector3 = damping * loc_vel[i]
		loc_acc[i] = anchor_spring - resistance + center_spring
		loc_vel[i] += loc_acc[i] * dt
		pos[i] += loc_vel[i] * dt
	glob_acc = Vector3.ZERO
		
func _collide() -> void:
	var zero_world: Vector3 = global_transform.inverse() * Vector3.ZERO
	for i in range(N):
		var v_pos: Vector3 = pos[i]
		if v_pos.y < zero_world.y:
			loc_vel[i] *= Vector3(1, 0, 1)
		pos[i] = Vector3(v_pos.x, max(v_pos.y, zero_world.y), v_pos.z)

func _recenter(dt: float, anchor_center) -> void:
	var new_anchor_center: Vector3 = _calculate_center(pos)
	var anchor_vel: Vector3 = new_anchor_center - anchor_center
	if anchor_vel.length() < 0.001: return
	
	var u: Vector3 = anchor_vel.normalized()
	glob_vel -= u * min(u.dot(glob_vel), 0) * (2 - energy_abs)
	for i in range(N):
		anchor_point_arr[i] += anchor_vel * (1 - energy_abs)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(dt: float) -> void:
	dt = clamp(dt, 0, 0.05)
	_integrate(dt)
	var anchor_center = _calculate_center(pos)
	_collide()
	_recenter(dt, anchor_center)
	_set_vertices(pos)
