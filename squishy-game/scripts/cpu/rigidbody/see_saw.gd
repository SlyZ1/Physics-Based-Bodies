extends Node3D

@onready var child := $Board
@export var mass : float
@export var rotation_threshold : float = PI / 6	



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	child.m = mass
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var global_VecZ = child.global_basis.z
	var angle = child.rotation[2] - PI / 2.0
	var sgn = 1
	if angle < 0:
		sgn = -1
		
	if abs(angle) > rotation_threshold:
		child.rotate_z(-1 * sgn * (abs(angle) - rotation_threshold))
		if -1 * sgn * child.glob_angular_vel.dot(global_VecZ) < 0:
			child.glob_angular_vel = Vector3.ZERO
	pass
