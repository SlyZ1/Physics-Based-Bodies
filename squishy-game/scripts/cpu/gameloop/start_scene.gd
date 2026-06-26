class_name StartScene
extends Control
@export var timer: Label
@export var levelcompleted: Control
@export var levelcompletedbutton: Button
const level: PackedScene = preload("res://scene/level_0.tscn")
@export var cp_label: Label

var instanciated_scene: Node = null
var game_time: float = 0.0
var game_runing = false
var checkpoint_passed_timer: int = Time.get_ticks_msec() - 10000

func _restart_everything() -> void:
	if instanciated_scene:
		self.remove_child(instanciated_scene)
	
	levelcompleted.visible = false
	self.mouse_filter = Control.MOUSE_FILTER_PASS
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	instanciated_scene = level.instantiate()
	timer.text = "1"
	instanciated_scene.level_finished.connect(finished_level)
	instanciated_scene.checkpoint_passed.connect(checkpoint_passed)
	timer.text = "2"
	self.add_child(instanciated_scene)
	timer.text = "3"
	game_runing = true
	game_time = 0.0
	

func finished_level() -> void:
	print("level completed")
	game_runing = false
	levelcompleted.visible = true
	self.mouse_filter = Control.MOUSE_FILTER_STOP
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
func checkpoint_passed() -> void:
	checkpoint_passed_timer = Time.get_ticks_msec()
	

func _ready() -> void:
	timer.text = "oui"
	_restart_everything()
	levelcompleted.visible = false
	levelcompletedbutton.pressed.connect(_restart_everything)

func _process(delta: float) -> void:
	if Time.get_ticks_msec() - checkpoint_passed_timer < 1000:
		cp_label.visible = true
	else:
		cp_label.visible = false
		
	if game_runing:
		game_time += delta
		timer.text = str(int(game_time/60)).pad_zeros(2) + " : " + str(int(game_time)%60).pad_zeros(2)
