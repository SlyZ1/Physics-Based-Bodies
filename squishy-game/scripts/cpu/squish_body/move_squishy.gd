extends Node

@export var squishy: Squishy
@export var cam_container: Node3D
@export var move_force: float
	
func _process(delta: float) -> void:
	var move_inputs: Vector2 = InputManager.get_move_inputs()
	var anchor_vel: Vector3 = squishy.anchor_vel
	var move_up: Vector3 = Vector3.UP if anchor_vel.length() < 0.005 else anchor_vel.normalized() 
	var move_forward: Vector3 = cam_container.global_basis.x.cross(move_up).normalized()
	var move_right: Vector3 = cam_container.global_basis.x.normalized()
	var acc: Vector3 = (move_right * move_inputs.x - move_forward * move_inputs.y) * move_force
	squishy.add_glob_acc(acc)
