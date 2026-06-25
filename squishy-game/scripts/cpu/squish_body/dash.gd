extends Node


@export var cooldown : float = 2
@export var intensity : float = 1
@export var squishy : Squishy
@export_group("get_move_force")
@export var cam_container: Node3D
@export var ground_force: float
@export var air_force: float
@export var ground_friction: float
@export var air_friction: float


@onready var timer: Timer = $CooldownTimer
var is_ready = true

func get_move_force() -> Vector3:
	var move_inputs: Vector2 = InputManager.get_move_inputs()
	var move_up = squishy.collision_dir
	if move_up.dot(Vector3.UP) < 0.7: move_up = Vector3.UP
	var move_forward: Vector3 = cam_container.global_basis.x.cross(move_up).normalized()
	var move_right: Vector3 = move_up.cross(move_forward)
	var movement: Vector3 = (move_right * move_inputs.x - move_forward * move_inputs.y)
	movement *= ground_force if squishy.is_colliding else air_force
	return movement

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	timer.timeout.connect(_on_timer_timeout)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("shift") and is_ready:
		is_ready = false
		
		var dir = get_move_force().normalized()
		squishy.add_glob_vel(intensity * dir)
		print(dir*intensity)
		
		$CooldownTimer.start(cooldown)
		print("dash") 
	


func _on_timer_timeout() -> void:
	is_ready = true
