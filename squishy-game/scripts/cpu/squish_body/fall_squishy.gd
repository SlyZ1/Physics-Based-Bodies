extends Node

@export var squishy: Squishy
@export var min_height: float

func _process(delta: float) -> void:
	if squishy.get_real_center().y < min_height:
		squishy.teleport(Vector3(0,0,0))
