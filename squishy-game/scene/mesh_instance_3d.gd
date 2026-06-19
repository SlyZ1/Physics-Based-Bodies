extends Node3D

var visual_only: bool = true

@export var angular_speed: float = 3.0
@export var local_axis: Vector3 = Vector3.FORWARD

func _physics_process(dt: float) -> void:
	var axis := local_axis.normalized()
	if axis.length_squared() < 1e-8:
		return

	rotate_object_local(axis, angular_speed * dt)
