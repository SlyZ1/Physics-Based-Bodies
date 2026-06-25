extends MeshInstance3D

@export var parent_rigidbody: Rigidbody

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	global_transform = parent_rigidbody.global_transform
