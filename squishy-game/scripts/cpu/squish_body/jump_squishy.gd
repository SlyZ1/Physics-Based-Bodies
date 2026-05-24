extends Node

@export var squishy: Squishy
@export var jump_force: float
@export var coyotee_time: float

const jump_cd: float = 0.2
var can_jump: bool = true
var jump_timer: float

var can_jump_coyotee: bool
var coyotee_timer: float

func _process(dt: float) -> void:
	if jump_timer > jump_cd:
		can_jump = true
	else: jump_timer += dt
		
	if squishy.is_colliding:
		can_jump_coyotee = true
		coyotee_timer = 0
	else:
		if coyotee_timer > coyotee_time:
			can_jump_coyotee = false
		else: coyotee_timer += dt
		
	if !InputManager.jumps() or !can_jump_coyotee or !can_jump:
		return
	can_jump = false
	squishy.add_glob_acc(Vector3.UP * jump_force / dt)
	squishy.add_glob_vel(-Vector3.DOWN * Vector3.DOWN.dot(squishy.glob_vel))
	
