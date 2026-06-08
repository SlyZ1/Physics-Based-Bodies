extends Interactable

@export var spring_intensity: float
@export var spring_cooldown: float = 0.1

var cooldown_timer: float
var can_spring: bool = true

func interact(dt: float, squishy: Squishy) -> void:
	if !can_spring: return
	can_spring = false

	var spring_dir: Vector3 = global_basis.y
	spring_dir = squishy.global_transform.basis.transposed() * spring_dir
	spring_dir = spring_dir.normalized()
	squishy.add_glob_vel(- spring_dir * spring_dir.dot(squishy.glob_vel))
	squishy.add_glob_vel(spring_dir * spring_intensity)

func _process(delta: float) -> void:
	super(delta)

	if !can_spring:
		cooldown_timer += delta
	if cooldown_timer > spring_cooldown:
		can_spring = true
		cooldown_timer = 0
