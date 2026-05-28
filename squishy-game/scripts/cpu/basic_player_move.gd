extends CharacterBody3D

@export var move_speed: float = 100
@export var run_multiplicator: float = 2
@export var move_damping: float = 1
@export var camera: Node3D

var movement: Vector3 = Vector3.ZERO
	
func _get_input() -> Vector2:
	return Input.get_vector("left", "right", "backward", "forward")
	
func _is_moving(input: Vector2) -> bool:
	return abs(input.x) > 0.05 || abs(input.y) > 0.05

func _run(movement: Vector3) -> Vector3:
	var is_running: bool = Input.is_action_pressed("shift")
	if is_running:
		return movement * run_multiplicator
	return movement
	
func _compute_movement(delta: float, input: Vector2) -> void:
	var cam_basis: Basis = camera.global_transform.basis
	var forward: Vector3 = -cam_basis.z * Vector3(1,0,1)
	var right: Vector3 = cam_basis.x * Vector3(1,0,1)
	var new_movement: Vector3 = Vector3.ZERO
	if _is_moving(input):
		new_movement = forward.normalized() * input.y + right.normalized() * input.x
		new_movement = new_movement.normalized()
	var t: float = clamp(delta * 50 / move_damping, 0, 1)
	new_movement = _run(new_movement)
	
	movement = movement.lerp(new_movement, t)
	velocity = movement * move_speed
	
func _physics_process(delta: float) -> void:
	var input: Vector2 = _get_input()
	_compute_movement(delta, input)
	

func _process(delta: float) -> void:
	move_and_slide()
