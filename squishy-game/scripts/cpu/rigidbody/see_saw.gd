extends Node3D

@export var child : Rigidbody
@export var rotation_threshold : float = PI / 6



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var local_VecZ = child.global_transform.basis.z.normalized()
	var angle = child.rotation[2] - PI / 2.0
	var sgn = 1
	if angle < 0:
		sgn = -1
		
	if abs(angle) > rotation_threshold:
		child.rotate_z(-1 * sgn * (abs(angle) - rotation_threshold))
		if child.glob_angular_vel.z * sgn > 0:
			child.glob_angular_vel.z = 0
	pass
