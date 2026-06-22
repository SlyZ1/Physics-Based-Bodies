extends Node

@export var squishy: Squishy
@export var move_squishy: MoveSquishy
@export var angle_damping: float = 5

var forward: Vector3

func _ready() -> void:
	forward = Vector3.FORWARD

func _process(dt: float) -> void:
	var move_vector: Vector3 = move_squishy.get_move_force()
	if move_vector.length() < 1: return
	move_vector = move_vector.normalized()
	if move_vector.dot(forward) > 0.99: return
	
	var new_forward = forward.slerp(move_vector, dt * angle_damping)
	if move_vector.dot(forward) < -0.5:
		new_forward = forward.slerp(forward.rotated(Vector3.UP, PI / 2), dt * angle_damping)
	new_forward = forward.rotated(Vector3.UP, forward.signed_angle_to(move_vector, Vector3.UP) * dt * angle_damping)
	var new_basis = Basis.looking_at(new_forward, Vector3.UP)
	var forward_rotation: Quaternion = Quaternion(new_basis)
	squishy.rotate_of_angles(forward_rotation, Quaternion(forward, new_forward))
	forward = new_forward
