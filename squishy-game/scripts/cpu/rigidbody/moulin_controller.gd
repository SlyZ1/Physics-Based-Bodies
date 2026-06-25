extends Node

@export var child : Rigidbody
@export var rotation_speed : float = 1


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var local_VecZ = child.global_transform.basis.z.normalized()
	child.add_angular_vel(rotation_speed * local_VecZ)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.s
func _process(delta: float) -> void:
	
	pass
