extends Node3D
@export var end_checkpoint: Node3D
@export var checkpoint_parent: Node
@export var squishy: Squishy
@export var min_height: float
@export var checkpoint_distance: float = 3.0

signal level_finished
signal checkpoint_passed

var last_CP_position: Vector3 = Vector3(0,0,0)
var last_CP_time: int = Time.get_ticks_msec()

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	var squishy_center = squishy.get_real_center()
	if squishy_center.y < min_height:
		squishy.teleport(last_CP_position)
		return

	if (squishy_center - end_checkpoint.global_position).length() < checkpoint_distance:
		print("flag reached")
		level_finished.emit()
		set_process(false)
		return

	for cp in checkpoint_parent.get_children():
		if (squishy_center - cp.global_position).length() < checkpoint_distance:
			#Emit the signal only every 5 sec if the user stays at the CP
			if Time.get_ticks_msec() - last_CP_time > 5000:
				last_CP_position = cp.global_position
				last_CP_time = Time.get_ticks_msec()
				checkpoint_passed.emit()
				return
