extends Node3D

var visual_only: bool = false

@export var angular_speed: float = 3.0
@export var local_axis: Vector3 = Vector3.FORWARD

func _physics_process(dt: float) -> void:
	var axis := local_axis.normalized()
	if axis.length_squared() < 1e-8:
		return

	rotate_object_local(axis, angular_speed * dt)

func get_collision_velocity_at_global_point(global_point: Vector3) -> Vector3:
	var global_axis := (global_basis * local_axis).normalized()
	return global_axis.cross(global_point - global_position) * angular_speed

func should_include_collision_mesh(mesh_instance: MeshInstance3D) -> bool:
	return not (mesh_instance.mesh is CylinderMesh)
