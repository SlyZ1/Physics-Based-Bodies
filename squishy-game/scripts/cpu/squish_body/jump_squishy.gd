extends Node

@export var squishy: Squishy
@export var jump_force: float
@export var coyotee_time: float
@export var jump_buffer_time: float

# CAN JUMP
const jump_cd: float = 0.2
var can_jump: bool = true
var jump_timer: float

# COYOTEE
var can_jump_coyotee: bool
var coyotee_timer: float

# BUFFER
var buffer_counter: float
var is_jumping: bool 

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
		
	if buffer_counter > jump_buffer_time:
		is_jumping = false
	else:
		buffer_counter += dt
		
	if !is_jumping or !can_jump_coyotee or !can_jump:
		return
	can_jump = false
	var up: Vector3 = squishy.anchor_vel.normalized()
	squishy.add_glob_acc(up * jump_force / dt)
	squishy.add_glob_vel(-up * up.dot(squishy.glob_vel))
	
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		is_jumping = true
		buffer_counter = 0
