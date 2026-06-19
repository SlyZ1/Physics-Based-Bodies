extends Node3D

var visual_only: bool = false

@export_enum("Random", "Vertical", "Horizontal")
var slit_mode: String = "Random"

@export_group("Wall")
@export var wall_width: float = 5.0
@export var wall_height: float = 4.0
@export var wall_thickness: float = 0.35
@export var vertical_slit_width: float = 0.9
@export var horizontal_slit_height: float = 0.9
@export var slit_center_offset: float = 0.0
@export var wall_color: Color = Color(0.75, 0.16, 0.12, 1.0)

@export_group("Motion")
@export_enum("Node Forward", "Node Backward", "World Forward", "World Backward", "World Right", "World Left", "Custom")
var travel_direction: String = "Node Forward"
@export var custom_travel_direction: Vector3 = Vector3.FORWARD
@export var speed: float = 3.0
@export var travel_distance: float = 12.0

var start_position: Vector3
var distance_traveled: float = 0.0
var material: StandardMaterial3D

func get_collision_velocity_at_global_point(_global_point: Vector3) -> Vector3:
	return _get_travel_direction() * speed

func uses_two_sided_collision() -> bool:
	return true

func _ready() -> void:
	randomize()
	start_position = position
	material = StandardMaterial3D.new()
	material.albedo_color = wall_color
	_spawn_new_wall()

func _physics_process(dt: float) -> void:
	var direction := _get_travel_direction()
	if direction.length_squared() < 1e-8:
		return
	
	position += direction * speed * dt
	distance_traveled += speed * dt
	
	if distance_traveled >= travel_distance:
		_spawn_new_wall()

func _spawn_new_wall() -> void:
	position = start_position
	distance_traveled = 0.0
	
	for child in get_children():
		remove_child(child)
		child.queue_free()
	
	var mode: String = _choose_slit_mode()
	if mode == "Vertical":
		_build_vertical_slit()
	else:
		_build_horizontal_slit()

func _choose_slit_mode() -> String:
	if slit_mode == "Random":
		return "Vertical" if randi() % 2 == 0 else "Horizontal"
	return slit_mode

func _get_travel_direction() -> Vector3:
	match travel_direction:
		"Node Forward":
			return (global_basis * Vector3.FORWARD).normalized()
		"Node Backward":
			return (global_basis * Vector3.BACK).normalized()
		"World Forward":
			return Vector3.FORWARD
		"World Backward":
			return Vector3.BACK
		"World Right":
			return Vector3.RIGHT
		"World Left":
			return Vector3.LEFT
		"Custom":
			return custom_travel_direction.normalized()
		_:
			return (global_basis * Vector3.FORWARD).normalized()

func _build_vertical_slit() -> void:
	var gap := clampf(vertical_slit_width, 0.0, wall_width)
	var center := clampf(slit_center_offset, -wall_width * 0.5 + gap * 0.5, wall_width * 0.5 - gap * 0.5)
	var left_edge := -wall_width * 0.5
	var gap_left := center - gap * 0.5
	var gap_right := center + gap * 0.5
	var right_edge := wall_width * 0.5
	
	_add_block(Vector3((left_edge + gap_left) * 0.5, wall_height * 0.5, 0.0), Vector3(gap_left - left_edge, wall_height, wall_thickness))
	_add_block(Vector3((gap_right + right_edge) * 0.5, wall_height * 0.5, 0.0), Vector3(right_edge - gap_right, wall_height, wall_thickness))

func _build_horizontal_slit() -> void:
	var gap := clampf(horizontal_slit_height, 0.0, wall_height)
	var center := clampf(wall_height * 0.5 + slit_center_offset, gap * 0.5, wall_height - gap * 0.5)
	var bottom_edge := 0.0
	var gap_bottom := center - gap * 0.5
	var gap_top := center + gap * 0.5
	var top_edge := wall_height
	
	_add_block(Vector3(0.0, (bottom_edge + gap_bottom) * 0.5, 0.0), Vector3(wall_width, gap_bottom - bottom_edge, wall_thickness))
	_add_block(Vector3(0.0, (gap_top + top_edge) * 0.5, 0.0), Vector3(wall_width, top_edge - gap_top, wall_thickness))

func _add_block(local_position: Vector3, size: Vector3) -> void:
	if size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
		return
	
	var mesh := BoxMesh.new()
	mesh.size = size
	
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.position = local_position
	mesh_instance.material_override = material
	add_child(mesh_instance)
