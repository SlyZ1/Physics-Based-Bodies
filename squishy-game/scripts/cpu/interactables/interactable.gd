extends Node3D

class_name Interactable

@export var distance_threshold: float

func interact(dt: float, squishy: Squishy) -> void:
	print("interact")
	pass

func _process(dt: float) -> void:
	var squishy_pos: Vector3 = Squishy.core.get_real_center()
	if (squishy_pos - global_position).length() < distance_threshold:
		interact(dt, Squishy.core)
