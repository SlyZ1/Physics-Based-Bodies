class_name MoveSquishy
extends Node

@export var squishy: Squishy
@export var cam_container: Node3D
@export var ground_force: float
@export var air_force: float
@export var ground_friction: float
@export var air_friction: float

func get_move_force() -> Vector3:
	var move_inputs: Vector2 = InputManager.get_move_inputs()
	var move_up = squishy.collision_dir
	if move_up.dot(Vector3.UP) < 0.7: move_up = Vector3.UP
	var move_forward: Vector3 = cam_container.global_basis.x.cross(move_up).normalized()
	var move_right: Vector3 = move_up.cross(move_forward)
	var movement: Vector3 = (move_right * move_inputs.x - move_forward * move_inputs.y)
	movement *= ground_force if squishy.is_colliding else air_force
	return movement
	
func _process(dt: float) -> void:
	dt = min(dt, 1.0 / 45.0)
	squishy.add_glob_vel(get_move_force() * dt)
	
	var u = squishy.collision_dir
	if u.dot(Vector3.UP) < 0.5: u = Vector3.UP
	if squishy.is_colliding && squishy.mean_penetration > 5e-2:
		var dot_vel: float = u.dot(squishy.glob_vel)
		var tang_vel: Vector3 = squishy.glob_vel - u * dot_vel
		var ground_frict: Vector3 = -tang_vel * ground_friction
		squishy.add_glob_vel(ground_frict * dt)
	else:
		var dot_vel: float = u.dot(squishy.glob_vel)
		var tang_vel: Vector3 = squishy.glob_vel - u * dot_vel
		var air_frict: Vector3 = -tang_vel * air_friction
		squishy.add_glob_vel(air_frict * dt)
