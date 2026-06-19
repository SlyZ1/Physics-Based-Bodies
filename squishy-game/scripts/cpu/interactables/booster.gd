extends Interactable

var visual_only: bool = true

@export var boost_intensity: float
@export_enum("Local Z", "Local -Z", "Local X", "Local -X", "Local Y", "Local -Y")
var boost_axis: String = "Local Z"

var armed: bool = true

func _process(_dt: float) -> void:
	if Squishy.core == null:
		return

	var squishy_pos: Vector3 = Squishy.core.get_real_center()
	var is_inside := squishy_pos.distance_to(global_position) < distance_threshold

	if is_inside and armed:
		interact(0.0, Squishy.core)
		armed = false
	elif !is_inside:
		armed = true

func interact(_dt: float, squishy: Squishy) -> void:
	var boost_dir: Vector3 = global_basis * _get_boost_axis()
	boost_dir = squishy.global_transform.basis.transposed() * boost_dir
	squishy.add_glob_vel(boost_dir.normalized() * boost_intensity)

func _get_boost_axis() -> Vector3:
	match boost_axis:
		"Local Z":
			return Vector3.BACK
		"Local -Z":
			return Vector3.FORWARD
		"Local X":
			return Vector3.RIGHT
		"Local -X":
			return Vector3.LEFT
		"Local Y":
			return Vector3.UP
		"Local -Y":
			return Vector3.DOWN
		_:
			return Vector3.BACK
