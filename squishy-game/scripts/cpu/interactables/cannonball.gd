extends Node3D

var visual_only: bool = false

@export var gravity: float = 20.0
@export var lifetime: float = 3.0
@export_range(0.0, 3.0) var momentum_factor: float = 1.2

var velocity: Vector3 = Vector3.ZERO
var age: float = 0.0

func launch(initial_velocity: Vector3) -> void:
	velocity = initial_velocity

func get_collision_velocity_at_global_point(_global_point: Vector3) -> Vector3:
	return velocity

func get_collision_momentum_factor() -> float:
	return momentum_factor

func _physics_process(dt: float) -> void:
	velocity += Vector3.DOWN * gravity * dt
	global_position += velocity * dt
	age += dt
	
	if age >= lifetime:
		queue_free()
