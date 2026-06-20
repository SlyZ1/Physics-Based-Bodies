extends Node

@export var squishy: Squishy

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var contactPoint: Vector3 = squishy.get_real_center() + Vector3.UP * 0.5
	RenderingServer.global_shader_parameter_set("playerPos", contactPoint)
