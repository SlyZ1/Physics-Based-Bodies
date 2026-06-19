extends Node3D

const DEFAULT_CANNONBALL_SCENE := preload("res://prefabs/cannonball.tscn")

var visual_only: bool = true

@export var barrel: Node3D
@export var cannonball_scene: PackedScene
@export var muzzle_offset: float = 0.8
@export var initial_speed: float = 18.0
@export var gravity: float = 20.0
@export var shoot_interval: float = 1.0
@export_enum("Local X", "Local Y", "Local Z", "Local -X", "Local -Y", "Local -Z")
var barrel_launch_axis: String = "Local Y"

var shoot_timer: float = 0.0

func _ready() -> void:
	if barrel == null:
		barrel = find_child("barrel", true, false) as Node3D
	if barrel == null:
		barrel = find_child("Barrel", true, false) as Node3D

func _physics_process(dt: float) -> void:
	shoot_timer -= dt

	if shoot_timer <= 0.0:
		shoot()

func shoot() -> void:
	if barrel == null:
		return

	var ball_scene := cannonball_scene
	if ball_scene == null:
		ball_scene = DEFAULT_CANNONBALL_SCENE

	var direction := (barrel.global_basis * _get_launch_axis()).normalized()
	var ball := ball_scene.instantiate() as Node3D
	var dynamic_colliders: Node = null
	if Squishy.core != null:
		dynamic_colliders = Squishy.core.dynamic_colliders_parent
	if dynamic_colliders == null:
		dynamic_colliders = get_tree().current_scene.get_node_or_null("Dynamic Colliding Objects")
	if dynamic_colliders != null:
		dynamic_colliders.add_child(ball)
	else:
		get_tree().current_scene.add_child(ball)
	ball.global_position = barrel.global_position + direction * muzzle_offset

	if ball.has_method("launch"):
		ball.launch(direction * initial_speed)
	if "gravity" in ball:
		ball.gravity = gravity

	shoot_timer = shoot_interval

func _get_launch_axis() -> Vector3:
	match barrel_launch_axis:
		"Local X":
			return Vector3.RIGHT
		"Local Y":
			return Vector3.UP
		"Local Z":
			return Vector3.BACK
		"Local -X":
			return Vector3.LEFT
		"Local -Y":
			return Vector3.DOWN
		"Local -Z":
			return Vector3.FORWARD
		_:
			return Vector3.UP
