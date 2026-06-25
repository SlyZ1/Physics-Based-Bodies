class_name StartScene
extends Control
@export var timer: Label
@export var levelcompleted: Control
@export var levelcompletedbutton: Button

var playable_scene: Resource = preload("res://scene/simple_squishy.tscn")
var instanciated_scene: Node = null
var game_time: float = 0.0
var game_runing = false

func _restart_everything() -> void:
	if instanciated_scene:
		self.remove_child(instanciated_scene)
	levelcompleted.visible = false
	self.mouse_filter = Control.MOUSE_FILTER_PASS
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	instanciated_scene = playable_scene.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	instanciated_scene.level_finished.connect(finished_level)
	self.add_child(instanciated_scene)
	game_runing = true
	game_time = 0.0

func finished_level() -> void:
	print("level completed")
	game_runing = false
	levelcompleted.visible = true
	self.mouse_filter = Control.MOUSE_FILTER_STOP
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _ready() -> void:
	_restart_everything()
	levelcompleted.visible = false
	levelcompletedbutton.pressed.connect(_restart_everything)

func _process(delta: float) -> void:
	if game_runing:
		game_time += delta
		timer.text = "Time ellapsed: " + str(int(game_time/60)) + ": " + str(int(game_time)%60)
