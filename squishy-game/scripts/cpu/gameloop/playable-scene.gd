extends Node3D
@export var squishy_object: Node3D
@export var end_flag: Node3D

signal level_finished

func _ready() -> void:
	pass


func _process(delta: float) -> void:
	if (squishy_object.global_position - end_flag.global_position).length() < 2.0:
		print("flag reached")
		level_finished.emit()
		set_process(false)
