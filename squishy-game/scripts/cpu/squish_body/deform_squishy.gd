extends Node
class_name DeformSquishy

@export var squishy : Squishy
@export var cam_container: Node3D 
@export var intensity = 100.0

var horz_flatten = false
var vert_flatten = false

var vert_flatten_dir: Vector3 = Vector3.RIGHT

var vertices : PackedVector3Array
var N : int

func _ready() -> void :
	await squishy.ready
	vertices = squishy.get_pos()
	N = vertices.size()
	squishy.teleported.connect(_on_squishy_teleported)
	
func _on_squishy_teleported() -> void:
	vertices = squishy.get_pos()
	N = vertices.size()

func flatten_field(normal: Vector3, axis: Vector3) -> Vector3:
	var n = normal.normalized()
	var a = axis.normalized()

	var pole = abs(n.dot(a))
	var equator = 1.0 - pole

	var to_center = -n

	var radial = n - a * n.dot(a)

	if radial.length() > 1e-6:
		radial = radial.normalized()
	else:
		radial = Vector3.ZERO

	return to_center * pole + radial * equator

func _process(dt: float) -> void:		
	for i in range(N):
		var v = (vertices[i] - squishy.get_local_real_center()).normalized()
		var acc_dir = Vector3.ZERO
		if horz_flatten:
			acc_dir += flatten_field(v, Vector3.UP)

		if vert_flatten:
			acc_dir += flatten_field(v, vert_flatten_dir)

		acc_dir = acc_dir.normalized()	
		squishy.add_loc_acc(acc_dir * intensity, i)



func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("lmb"):
		horz_flatten = true
	elif event.is_action_released("lmb"):
		horz_flatten = false

	if event.is_action_pressed("rmb"):
		if !vert_flatten: vert_flatten_dir = cam_container.basis.x
		vert_flatten = true
	elif event.is_action_released("rmb"):
		vert_flatten = false
