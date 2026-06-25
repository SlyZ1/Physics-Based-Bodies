extends Node


@export var cooldown : float = 2
@export var intensity : float = 1
@export var effect_duration : float = 0.5
@export var squishy : Squishy
@export var move : MoveSquishy


@onready var timer: Timer = $CooldownTimer
var is_ready = true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	timer.timeout.connect(_on_timer_timeout)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var speedLines = $SpeedLines.material as ShaderMaterial
	if Input.is_action_just_pressed("shift") and is_ready:
		is_ready = false
		
		var dir = move.get_move_force().normalized()
		squishy.add_glob_vel(intensity * dir)
		
		$CooldownTimer.start(cooldown)
		speedLines.set_shader_parameter("line_density", 1.0)
	
	var time_elapsed = $CooldownTimer.wait_time - $CooldownTimer.time_left
	if  time_elapsed > effect_duration :
		speedLines.set_shader_parameter("line_density", 0.0)
		

	


func _on_timer_timeout() -> void:
	is_ready = true
