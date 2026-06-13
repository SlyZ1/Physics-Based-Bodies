extends MeshInstance3D
class_name Rigidbody

@export_group("Scene")
@export var ground_nodes: Array[Node3D]
@export var gizmo: Node3D
@export_group("Physics")
@export_subgroup("Global")
@export var g: float = 9.8
@export var m: float = 5
@export_range(0, 1) var energy_absorption: float = 0.5
@export var linear_damping: float = 0.1
@export var angular_damping: float = 0.1
@export var friction_factor: float = 3
@export_subgroup("Restrictions")
@export var restrict_linX: bool
@export var restrict_linY: bool
@export var restrict_linZ: bool
@export var restrict_angX: bool
@export var restrict_angY: bool
@export var restrict_angZ: bool
@export_subgroup("Sleep Mode")
@export var velocity_thresh: float = 0.01
@export var angular_velocity_thresh: float = 0.01
@export var sleep_delay: float = 0.5

var vertices: PackedVector3Array
var vertices_constraints: Array[Vector3]
var N: int
var initial_pos: Vector3

var glob_acc: Vector3
var glob_vel: Vector3

var glob_angular_acc: Vector3
var glob_angular_vel: Vector3

var inverse_inertia_tensor: Basis

var was_colliding: Array[bool]
var is_colliding: bool
var is_sleeping: bool

func add_vel(vel: Vector3) -> void:
	glob_vel += vel

func add_acc(acc: Vector3) -> void:
	glob_acc += acc

func add_angular_vel(vel: Vector3) -> void:
	glob_angular_vel += vel

func add_angular_acc(acc: Vector3) -> void:
	glob_angular_acc += acc

func add_impact(origin: Vector3, force: Vector3, check_contraints: bool) -> void:
	if force.length() < 1e-8: return
	is_sleeping = false
	var r: Vector3 = origin - global_transform.origin
	var force_dir: Vector3 = force.normalized()
	var inertia_inv: float = force_dir.dot((inverse_inertia_tensor * r.cross(force_dir)).cross(r))
	var j: Vector3 = force / (1.0 / m + inertia_inv)
	var impact_vel: Vector3 = j / m
	var impact_ang_vel: Vector3 = inverse_inertia_tensor * r.cross(j)
	glob_vel += impact_vel
	glob_angular_vel += impact_ang_vel
	if !check_contraints: return
	for i in range(N):
		var constraint = vertices_constraints[i]
		if constraint.length_squared() < 1e-5: continue
		var loc_pos = global_transform * vertices[i]
		var rv = loc_pos - global_transform.origin
		var p_vel = impact_vel + impact_ang_vel.cross(rv)
		add_impact(loc_pos, -constraint * constraint.dot(p_vel) * 0.3, false)

func add_force(origin: Vector3, force: Vector3) -> void:
	if force.length() < 1e-8: return
	var r = origin - global_position
	glob_acc += force / m
	glob_angular_acc += inverse_inertia_tensor * r.cross(force)
	is_sleeping = false

func get_loc_vel(origin: Vector3) -> Vector3:
	var r: Vector3 = origin - global_transform.origin
	var p_angular_vel: Vector3 = glob_angular_vel.cross(r)
	var p_vel: Vector3 = glob_vel + p_angular_vel
	return p_vel

func _start_simulation() -> void:
	glob_acc *= 0
	glob_vel *= 0
	glob_angular_acc *= 0
	glob_angular_vel *= 0
	global_position = initial_pos
	global_rotation_degrees = Vector3(
		randf_range(0, 360),
		randf_range(0, 360),
		randf_range(0, 360)
	)
	is_sleeping = false

func _ready() -> void:
	vertices = MeshUtils.get_vertices(mesh)
	N = vertices.size()
	was_colliding.resize(N)
	vertices_constraints.resize(N)
	initial_pos = global_position

func _compute_inverse_inertia_tensor() -> Basis:
	var Ix: float = (1.0 / 12.0) * m * (scale.y*scale.y + scale.z*scale.z)
	var Iy: float = (1.0 / 12.0) * m * (scale.x*scale.x + scale.z*scale.z)
	var Iz: float = (1.0 / 12.0) * m * (scale.x*scale.x + scale.y*scale.y)
	var I_local_inv: Basis = Basis(
		Vector3(1.0/Ix, 0, 0) * (1 - float(restrict_angX)),
		Vector3(0, 1.0/Iy, 0) * (1 - float(restrict_angY)),
		Vector3(0, 0, 1.0/Iz) * (1 - float(restrict_angZ))
	)
	var rot: Basis = global_transform.basis.orthonormalized()
	return rot * I_local_inv * rot.transposed()

func _integrate(dt: float) -> void:
	var restrict_lin: Vector3 = Vector3(restrict_linX, restrict_linY, restrict_linZ)
	restrict_lin = Vector3.ONE - restrict_lin
	glob_acc += g * Vector3.DOWN 
	glob_acc -= linear_damping * glob_vel / m
	glob_acc *= restrict_lin
	glob_vel += glob_acc * dt
	glob_vel *= restrict_lin

	global_position += glob_vel * dt
	glob_acc *= 0

	var restrict_ang: Vector3 = Vector3(restrict_angX, restrict_angY, restrict_angZ)
	restrict_ang = Vector3.ONE - restrict_ang
	glob_angular_acc += - angular_damping * glob_angular_vel / m
	glob_angular_acc *= restrict_ang
	glob_angular_vel += glob_angular_acc * dt
	glob_angular_vel *= restrict_ang
	#if glob_angular_vel.length() < 0.1: glob_angular_vel *= 0
	if glob_angular_vel.length_squared() > 1e-6:
		global_rotate(glob_angular_vel.normalized(), glob_angular_vel.length() * dt)
	glob_angular_acc *= 0

	inverse_inertia_tensor = _compute_inverse_inertia_tensor()

var mean_collision_dir: Vector3
func _collide(dt) -> void:
	var new_mcd: Vector3
	vertices_constraints = []
	vertices_constraints.resize(N)
	var restrict_lin: Vector3 = Vector3(restrict_linX, restrict_linY, restrict_linZ)
	restrict_lin = Vector3.ONE - restrict_lin
	for ground_node in ground_nodes:
		var ground_up: Vector3 = ground_node.basis.y.normalized()
		var ground_pos: float = ground_node.global_position.dot(ground_up)

		for i in range(N):
			var pos: Vector3 = global_transform * vertices[i]
			var v_pos: float = pos.dot(ground_up)
			var r: Vector3 = pos - global_transform.origin
			var penetration: float = ground_pos - v_pos
			var p_angular_vel: Vector3 = glob_angular_vel.cross(r)
			var p_vel: Vector3 = glob_vel + p_angular_vel

			if penetration >= 0:
				is_colliding = true
				vertices_constraints[i] = (vertices_constraints[i] + ground_up).normalized()

				var d_vel: float = ground_up.dot(p_vel)

				var slop: float = 0.001
				var tangent_vel: Vector3 = p_vel - ground_up * d_vel
				var friction_force: Vector3 = -friction_factor * tangent_vel
				if penetration > slop:
					var k: float = 1e6 * m
					var d: float = 2 * sqrt(k * m)
					
					var gamma = 1 / (d + dt * k)
					var beta = dt * k * gamma
					
					var v2: float = d_vel + beta/(m * gamma) * penetration
					v2 /= 1 + dt / (m * gamma)
					var delta_v = (v2 - d_vel) * ground_up
					add_impact(pos, delta_v, false)
					if !was_colliding[i]:
						add_impact(pos, friction_force, false)
					else:
						add_force(pos, friction_force * dt)
					new_mcd += delta_v
					#print("i: ", i, " d_vel: ", d_vel, " penetration: ", penetration, " v2: ", v2)

				if d_vel < -0.01:
					if !was_colliding[i]:
						var collision_force: Vector3 = -(2 - energy_absorption) * d_vel * ground_up
						add_impact(pos, collision_force, false)
					was_colliding[i] = true
				else:
					was_colliding[i] = false
			else:
				new_mcd += p_vel
	new_mcd /= N
	if new_mcd.length() <= 0.01 || !is_colliding:
		new_mcd = Vector3.ZERO
	else: 
		new_mcd = new_mcd.normalized()
	mean_collision_dir = new_mcd
	gizmo.global_position = global_position + mean_collision_dir

var sleep_timer: float
func _sleep_check(dt: float) -> void:
	if glob_vel.length() < velocity_thresh && glob_angular_vel.length() < angular_velocity_thresh:
		sleep_timer += dt
	else: sleep_timer = 0
	if sleep_timer > sleep_delay:
		is_sleeping = true
		sleep_timer = 0

func _process(dt: float) -> void:
	dt = min(dt, 1.0 / 45.0)

	if is_sleeping: return
	_integrate(dt)
	_collide(dt)
	_sleep_check(dt)
