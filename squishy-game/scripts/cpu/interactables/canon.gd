extends MeshInstance3D

const CANONBALL_SCENE: PackedScene = preload("res://prefabs/default_rigidbody.tscn")
const CANONBALL_MASS: float = 1.0e12
const SPAWN_OFFSET: float = 2.0
const CANONBALL_LIFETIME: float = 1.0
const SPIN_FORCE: float = 12.0

@export var canon_force: float = 40.0
@export var balls_per_second: float = 1.0
@export var canonball_scale: Vector3 = Vector3(0.45, 0.45, 0.45)
@export var groundNode:MeshInstance3D =null
@export var dynamicDad:Node = null

var _shoot_timer: float = 0.0

func _process(delta: float) -> void:
	if balls_per_second <= 0:
		return

	_shoot_timer -= delta
	while _shoot_timer <= 0.0:
		_spawn_canonball()
		_shoot_timer += 1.0 / balls_per_second

func _spawn_canonball() -> void:
	var canonball := CANONBALL_SCENE.instantiate() as Rigidbody
	if canonball == null:
		return
	canonball.name = "Canonball"
	canonball.m = CANONBALL_MASS
	canonball.scale = canonball_scale
	canonball.visible = true
	canonball.is_sleeping = false
	canonball.ground_nodes = [groundNode as Node3D]
	dynamicDad.add_child(canonball)

	canonball.global_position = global_position + _get_shoot_direction() * SPAWN_OFFSET
	canonball.global_rotation = global_rotation
	canonball.initial_pos = canonball.global_position
	get_tree().create_timer(CANONBALL_LIFETIME).timeout.connect(canonball.queue_free)
	await get_tree().process_frame
	_shoot_canonball(canonball)

func _shoot_canonball(canonball: Rigidbody) -> void:
	if !is_instance_valid(canonball):
		return
	canonball.is_sleeping = false
	canonball.glob_acc = Vector3.ZERO
	canonball.glob_vel = Vector3.ZERO
	canonball.glob_angular_acc = Vector3.ZERO
	canonball.glob_angular_vel = Vector3.ZERO
	canonball.add_vel(_get_shoot_direction() * canon_force)
	canonball.add_angular_vel(_get_random_spin())

func _get_shoot_direction() -> Vector3:
	return global_transform.basis.y.normalized()

func _get_random_spin() -> Vector3:
	return Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	).normalized() * SPIN_FORCE
