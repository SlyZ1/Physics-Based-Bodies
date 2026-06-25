extends Node

@export var parent : Rigidbody
@export var rotation_speed : float = 1
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var local_VecZ = (parent.global_transform.basis * Vector3.FORWARD).normalized()
	
	parent.add_angular_vel(rotation_speed * local_VecZ)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.s
func _process(delta: float) -> void:
	
	pass
