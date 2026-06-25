extends Button

var time: float = 0.0

func _ready() -> void:
	pass


func _process(delta: float) -> void:
	time += delta
	var size = cos(time * 4.0) * 0.2 + 2.0
	self.scale = Vector2(size, size)
