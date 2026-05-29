extends Node3D

@export var squishy: Squishy
@export var move_squishy: MoveSquishy

var last_dir: Vector3
var center: Vector3

func _process(delta: float) -> void:
	var offset: Vector3 = (global_position - center).normalized()
	center = squishy.global_transform * squishy.get_real_center()
	var new_offset: Vector3 = offset.slerp(last_dir, 8 * delta)
	var v_index: int = squishy.get_vertex_in_dir(squishy.global_transform.basis.transposed() * new_offset)
	var vertex: Vector3 = squishy.pos[v_index]
	var radius: float = (vertex - squishy.get_real_center()).length()
	global_position = center + new_offset * radius
	
	var move_force: Vector3 = move_squishy.get_move_force()
	if move_force.length_squared() < 1e-8: return
	last_dir = move_force.normalized()
