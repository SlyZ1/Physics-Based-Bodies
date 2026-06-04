extends Interactable

@export var boost_intensity: float

func interact(dt: float, squishy: Squishy) -> void:
	var boost_dir: Vector3 = global_basis.z
	boost_dir = squishy.global_transform.basis.transposed() * boost_dir
	squishy.add_glob_vel(boost_dir * boost_intensity * dt)
