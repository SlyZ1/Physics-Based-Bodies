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
	var t: float = clamp(delta * 50 / target_damp, 0, 1)
	target_pos = target_pos.lerp(target.global_position, t)
	global_position = target_pos

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	_follow_target(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		global_rotation.x -= sensibility * event.relative.y
		global_rotation_degrees.x = clamp(global_rotation_degrees.x, -80, 10)
		global_rotation.y -= sensibility * event.relative.x
