extends MeshInstance3D

const WALL_SCENE: PackedScene = preload("res://prefabs/default_rigidbody.tscn")
const WALL_MASS: float = 1.0e10

@export var walls_per_second: float = 0.25
@export var slit_width: float = 2.0
@export var travel_distance: float = 30.0
@export var wall_speed: float = 8.0
@export var wall_width: float = 12.0
@export var wall_height: float = 8.0
@export var wall_thickness: float = 1.0
@export var pane_thickness: float = 0.25
@export var slit_edge_angle_degrees: float = 0.0
@export var groundNode: MeshInstance3D = null
@export var dynamicDad: Node = null

var _spawn_timer: float = 0.0

func _process(delta: float) -> void:
	if walls_per_second <= 0.0:
		return

	_spawn_timer -= delta
	while _spawn_timer <= 0.0:
		_spawn_wall()
		_spawn_timer += 1.0 / walls_per_second

func _spawn_wall() -> void:
	var wall_parts: Array[Rigidbody] = []
	var pane_size := _get_pane_thickness()
	var side_width: float = max((wall_width - slit_width) * 0.5, pane_size * 2.0)
	var side_offset: float = slit_width * 0.5 + side_width * 0.5

	wall_parts.append_array(_create_minecart_half("Left", -side_offset, side_width, pane_size, 1.0))
	wall_parts.append_array(_create_minecart_half("Right", side_offset, side_width, pane_size, -1.0))

	for wall_part in wall_parts:
		if wall_part != null:
			_launch_wall_part(wall_part)

func _create_minecart_half(part_prefix: String, side_center: float, side_width: float, pane_size: float, slit_angle_sign: float) -> Array[Rigidbody]:
	var wall_parts: Array[Rigidbody] = []

	wall_parts.append(_create_wall_part(
		"MinecartWall%sBottom" % part_prefix,
		Vector3(side_center, -wall_height * 0.5 + pane_size * 0.5, 0.0),
		Vector3(side_width, pane_size, wall_thickness),
		slit_angle_sign
	))
	wall_parts.append(_create_wall_part(
		"MinecartWall%sOuterSide" % part_prefix,
		Vector3(side_center + sign(side_center) * (side_width * 0.5 - pane_size * 0.5), 0.0, 0.0),
		Vector3(pane_size, wall_height, wall_thickness),
		slit_angle_sign
	))
	wall_parts.append(_create_wall_part(
		"MinecartWall%sInnerSide" % part_prefix,
		Vector3(side_center - sign(side_center) * (side_width * 0.5 - pane_size * 0.5), 0.0, 0.0),
		Vector3(pane_size, wall_height, wall_thickness),
		slit_angle_sign
	))
	wall_parts.append(_create_wall_part(
		"MinecartWall%sFront" % part_prefix,
		Vector3(side_center, 0.0, -wall_thickness * 0.5 + pane_size * 0.5),
		Vector3(side_width, wall_height, pane_size),
		slit_angle_sign
	))
	wall_parts.append(_create_wall_part(
		"MinecartWall%sBack" % part_prefix,
		Vector3(side_center, 0.0, wall_thickness * 0.5 - pane_size * 0.5),
		Vector3(side_width, wall_height, pane_size),
		slit_angle_sign
	))

	return wall_parts

func _create_wall_part(part_name: String, local_offset: Vector3, size: Vector3, slit_angle_sign: float) -> Rigidbody:
	var wall_part := WALL_SCENE.instantiate() as Rigidbody
	if wall_part == null:
		return null

	wall_part.name = part_name
	wall_part.m = WALL_MASS
	wall_part.visible = true
	wall_part.is_sleeping = false
	wall_part.ground_nodes = _get_ground_nodes()
	wall_part.restrict_linX = true
	wall_part.restrict_linY = true
	wall_part.restrict_linZ = false
	wall_part.restrict_angX = true
	wall_part.restrict_angY = true
	wall_part.restrict_angZ = true

	var parent := dynamicDad if dynamicDad != null else get_tree().current_scene
	parent.add_child(wall_part)

	var spawn_position := global_position + _to_world_offset(local_offset, slit_angle_sign)
	wall_part.global_transform = Transform3D(_get_wall_basis(size, slit_angle_sign), spawn_position)
	wall_part.initial_pos = wall_part.global_position
	return wall_part

func _launch_wall_part(wall_part: Rigidbody) -> void:
	wall_part.glob_acc = Vector3.ZERO
	wall_part.glob_vel = Vector3.ZERO
	wall_part.glob_angular_acc = Vector3.ZERO
	wall_part.glob_angular_vel = Vector3.ZERO
	wall_part.add_vel(_get_travel_direction() * wall_speed)
	_delete_after_travel(wall_part, wall_part.global_position)

func _delete_after_travel(wall_part: Rigidbody, start_position: Vector3) -> void:
	while is_instance_valid(wall_part):
		if wall_part.global_position.distance_to(start_position) >= travel_distance:
			wall_part.queue_free()
			return
		await get_tree().process_frame

func _get_wall_basis(size: Vector3, slit_angle_sign: float) -> Basis:
	var angle := deg_to_rad(slit_edge_angle_degrees) * slit_angle_sign
	var side_direction := _get_side_direction()
	var travel_direction := _get_travel_direction()
	var side_axis := (side_direction * cos(angle) + travel_direction * sin(angle)).normalized()
	var travel_axis := (travel_direction * cos(angle) - side_direction * sin(angle)).normalized()
	return Basis(
		side_axis * size.x,
		Vector3.UP * size.y,
		travel_axis * size.z
	)

func _to_world_offset(local_offset: Vector3, slit_angle_sign: float) -> Vector3:
	var angle := deg_to_rad(slit_edge_angle_degrees) * slit_angle_sign
	var side_direction := _get_side_direction()
	var travel_direction := _get_travel_direction()
	var side_axis := (side_direction * cos(angle) + travel_direction * sin(angle)).normalized()
	var travel_axis := (travel_direction * cos(angle) - side_direction * sin(angle)).normalized()
	return (
		side_axis * local_offset.x
		+ Vector3.UP * local_offset.y
		+ travel_axis * local_offset.z
	)

func _get_pane_thickness() -> float:
	var max_pane_size: float = min(min(wall_width, wall_height), wall_thickness) * 0.5
	return clamp(pane_thickness, 0.01, max_pane_size)

func _get_travel_direction() -> Vector3:
	return global_transform.basis.y.normalized()

func _get_side_direction() -> Vector3:
	var side := _get_travel_direction().cross(Vector3.UP).normalized()
	if side.length_squared() < 1.0e-6:
		return global_transform.basis.x.normalized()
	return side

func _get_ground_nodes() -> Array[Node3D]:
	var ground_nodes: Array[Node3D] = []
	if groundNode != null:
		ground_nodes.append(groundNode)
	return ground_nodes
