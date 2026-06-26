extends Button

var time: float = 0.0
var original_scale: Vector2

func _ready() -> void:
	original_scale = scale


func _process(delta: float) -> void:
	time += delta
	var size = cos(time * 4.0) * 0.2 + 1.0
	scale = original_scale * Vector2(size, size)
