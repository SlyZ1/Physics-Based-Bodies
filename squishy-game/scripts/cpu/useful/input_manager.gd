class_name InputManager
extends Object

static func get_move_inputs() -> Vector2:
	return Input.get_vector("left", "right", "backward", "forward")

static func jumps() -> bool:
	return Input.is_action_just_released("jump")

static func presses_jump() -> bool:
	return Input.is_action_pressed("jump")
