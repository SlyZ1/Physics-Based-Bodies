extends Node3D

@export var squishy: Squishy
@export var move_squishy: MoveSquishy

var last_dir: Vector3
var center: Vector3

func _process(delta: float) -> void:
	var offset: Vector3 = (global_position - center).normalized()
	center = squishy.global_transform * squishy.pos_center
	var new_offset: Vector3 = offset.slerp(last_dir, 20 * delta)
	var radius: float = squishy.get_radius_in_dir(squishy.global_transform.basis.transposed() * new_offset)
	global_position = center + new_offset * radius
	
	var move_dir: Vector3 = squishy.glob_vel
	move_dir.y = 0
	move_dir = move_dir.normalized()
	if move_dir.length_squared() < 1e-8: return
	last_dir = move_dir.normalized()
