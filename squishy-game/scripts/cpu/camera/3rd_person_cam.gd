extends Node3D

@export var target: Node3D
@export var camera: Node3D
@export var target_damp: float = 1
@export var distance: float = 4
@export var sensibility: float = 1

var target_pos: Vector3 = Vector3.ZERO

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _follow_target(delta: float):
	camera.position = Vector3(0, 0, distance)
	var y: float = global_position.y - 0.8 - camera.global_position.y
	if y > 0:
		var cos_theta: float = global_basis.z.dot(Vector3.DOWN)
		camera.position -= Vector3(0, 0, y / cos_theta)
		camera.position.z = max(camera.position.z, distance / 5)
	
	var t: float = clamp(delta * 50 / target_damp, 0, 1)
	target_pos = target_pos.lerp(target.global_position + Vector3.UP, t)
	global_position = target_pos

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	_follow_target(delta)
	if Input.is_action_just_pressed("escape"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Input.is_action_just_pressed("lmb"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

var glob_rot: Vector2
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		glob_rot.x -= sensibility * event.relative.y
		glob_rot.x = clamp(glob_rot.x, -PI/2 * 0.9, PI/2 * 0.5)
		glob_rot.y -= sensibility * event.relative.x
		rotation.x = glob_rot.x
		rotation.y = glob_rot.y
