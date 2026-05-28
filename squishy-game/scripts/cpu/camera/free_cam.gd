extends Camera3D

@export var speed: float = 10.0
@export var sensitivity: float = 0.003
@export var sprint_multiplier: float = 3.0

var _captured: bool = false

func _ready() -> void:
	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void:
	return
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_captured = true
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_captured = false
	if event is InputEventMouseMotion and _captured:
		var look_x = -event.relative.y * sensitivity
		var look_y = -event.relative.x * sensitivity
		
		# Rotation Y en global (pour pas avoir de roll)
		rotate_object_local(Vector3.RIGHT, look_x)
		global_rotate(Vector3.UP, look_y)

var move = false
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pause"):
		move = !move
	if not _captured || !move:
		return

	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_Z): dir -= transform.basis.z
	if Input.is_key_pressed(KEY_S): dir += transform.basis.z
	if Input.is_key_pressed(KEY_Q): dir -= transform.basis.x
	if Input.is_key_pressed(KEY_D): dir += transform.basis.x
	if Input.is_key_pressed(KEY_SPACE): dir += Vector3.UP
	if Input.is_key_pressed(KEY_SHIFT): dir += Vector3.DOWN

	var current_speed = speed * sprint_multiplier if Input.is_key_pressed(KEY_SHIFT) else speed
	position += dir.normalized() * current_speed * delta
