extends MeshInstance3D

@export_group("Scene")
@export var ground_node: Node3D
@export_group("Physics")
@export_subgroup("Global")
@export var g: float = 9.8
@export var m: float = 5
@export_range(0, 1) var energy_absorption: float = 0.5
@export var linear_damping: float = 0.1
@export var angular_damping: float = 0.1
@export var friction_factor: float = 3

var vertices: PackedVector3Array
var N: int
var initial_pos: Vector3

var glob_acc: Vector3
var glob_vel: Vector3

var glob_angular_acc: Vector3
var glob_angular_vel: Vector3

var inverse_inertia_tensor: Basis

var is_colliding: bool

func add_vel(vel: Vector3) -> void:
	glob_vel += vel
	
func add_acc(acc: Vector3) -> void:
	glob_acc += acc
	
func add_angular_vel(vel: Vector3) -> void:
	glob_angular_vel += vel
	
func add_angular_acc(acc: Vector3) -> void:
	glob_angular_vel += acc
	
func add_impact(origin: Vector3, force: Vector3):
	var r: Vector3 = origin - global_transform.origin
	glob_angular_vel += inverse_inertia_tensor * r.cross(force)

func _start_simulation() -> void:
	glob_acc *= 0
	glob_vel *= 0
	global_position = initial_pos
	global_rotation_degrees = Vector3(
		randf_range(0, 360),
		randf_range(0, 360),
		randf_range(0, 360)
	)

func _ready() -> void:
	vertices = MeshUtils.get_vertices(mesh)
	N = vertices.size()
	initial_pos = global_position
	
func _compute_inverse_inertia_tensor() -> Basis:
	var scale: Vector3 = transform.basis.get_scale()
	var Ix: float = (1.0 / 12.0) * m * (scale.y*scale.y + scale.z*scale.z)
	var Iy: float = (1.0 / 12.0) * m * (scale.x*scale.x + scale.z*scale.z)
	var Iz: float = (1.0 / 12.0) * m * (scale.x*scale.x + scale.y*scale.y)
	var I_local_inv: Basis = Basis(
		Vector3(1.0/Ix, 0, 0),
		Vector3(0, 1.0/Iy, 0),
		Vector3(0, 0, 1.0/Iz)
	)
	var rot: Basis = global_transform.basis.orthonormalized()
	return rot * I_local_inv * rot.transposed()
	
func _integrate(dt: float) -> void:
	glob_acc += g * Vector3.DOWN - linear_damping * glob_vel / m
	glob_vel += glob_acc * dt
	global_position += glob_vel * dt
	glob_acc *= 0
	
	glob_angular_acc += - angular_damping * glob_angular_vel / m
	glob_angular_vel += glob_angular_acc * dt
	if glob_angular_vel.length_squared() > 1e-6:
		global_rotate(glob_angular_vel.normalized(), glob_angular_vel.length() * dt)
	glob_angular_acc *= 0
	
	inverse_inertia_tensor = _compute_inverse_inertia_tensor()
	
func _collide(dt: float) -> void:
	for i in range(N):
		var pos: Vector3 = global_transform * vertices[i]
		var ground_up: Vector3 = ground_node.basis.y.normalized()
		var ground_pos: float = ground_node.global_position.dot(ground_up)
		var v_pos: float = pos.dot(ground_up)
		var r: Vector3 = pos - global_transform.origin
		if v_pos < ground_pos:
			is_colliding = true
			
			var p_angular_vel: Vector3 = glob_angular_vel.cross(r)
			var p_vel: Vector3 = glob_vel + p_angular_vel
			var d: float = v_pos - ground_pos
			var d_vel: float = ground_up.dot(p_vel)
			
			var tangent_vel: Vector3 = p_vel - ground_up * d_vel
			glob_angular_acc += inverse_inertia_tensor * r.cross(-friction_factor / m * tangent_vel)
			
			if d_vel >= -0.01: continue
			
			var inertia_inv: float = ground_up.dot((inverse_inertia_tensor * r.cross(ground_up)).cross(r))
			var j: float = - (2 - energy_absorption) * d_vel / (1.0 / m + inertia_inv)
			glob_vel += (j / m) * ground_up
			glob_angular_vel += inverse_inertia_tensor * r.cross(j * ground_up)
			
			global_position += ground_up * (ground_pos - v_pos) * 0.3

func _process(dt: float) -> void:
	if InputManager.jumps(): _start_simulation()
	dt = min(dt, 1.0 / 45.0)
	_collide(dt)
	_integrate(dt)
