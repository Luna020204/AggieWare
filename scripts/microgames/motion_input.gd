extends MicrogameBase

const ROUND_SECONDS: Array[float] = [9.0, 8.0, 7.0]
var _timer_label: Label
const UI := preload("res://scripts/ui/microgame_ui.gd")

@onready var Fighter = %Fighter
@onready var QCF = %QCF
@onready var Semi = %Semi
@onready var Circle = %Circle
@onready var Fireball = %Fireball

var qcf_1 = preload("res://assets/art/microgames/motion_input/qcf_1.png")
var qcf_2 = preload("res://assets/art/microgames/motion_input/qcf_2.png")
var qcf_3 = preload("res://assets/art/microgames/motion_input/qcf_3.png")

var semi_1 = preload("res://assets/art/microgames/motion_input/semi_1.png")
var semi_2 = preload("res://assets/art/microgames/motion_input/semi_2.png")
var semi_3 = preload("res://assets/art/microgames/motion_input/semi_3.png")
var semi_4 = preload("res://assets/art/microgames/motion_input/semi_4.png")
var semi_5 = preload("res://assets/art/microgames/motion_input/semi_5.png")

var circle_1 = preload("res://assets/art/microgames/motion_input/360_1.png")
var circle_2 = preload("res://assets/art/microgames/motion_input/360_2.png")
var circle_3 = preload("res://assets/art/microgames/motion_input/360_3.png")
var circle_4 = preload("res://assets/art/microgames/motion_input/360_4.png")
var circle_5 = preload("res://assets/art/microgames/motion_input/360_5.png")
var circle_6 = preload("res://assets/art/microgames/motion_input/360_6.png")

var fighter_shoot = preload("res://assets/art/microgames/motion_input/fighter_shoot.png")
	
func get_round_seconds() -> float:
	return ROUND_SECONDS[clampi(difficulty, 0, 2)]
	
func play() -> void:
	if difficulty == 0:
		QCF.visible = true
		qcf_sequence()
	elif difficulty == 1:
		pass
	elif difficulty == 2:
		pass
		
func qcf_sequence() -> void:
	if Input.is_action_pressed("game_down"):
		QCF.texture = qcf_1
	else:
		_finish_round(false, "FAILED TO INPUT SEQUENCE!")
	
	if Input.is_action_pressed("game_right"):
		QCF.texture = qcf_2
	else:
		_finish_round(false, "FAILED TO INPUT SEQUENCE!")
		
	if Input.is_action_pressed("game_mash"):
		QCF.texture = qcf_3
		success()
	else:
		_finish_round(false, "FAILED TO INPUT SEQUENCE!")
		

func success() -> void:
	Fighter.texture = fighter_shoot
	Fireball.visible = true
	_finish_round(true, "PERFORMED THE MOTION INPUT!")
		
	

func _build_ui() -> void:
	var header := UI.build_header(self, "MOTION INPUT", "PERFORM INPUTS IN CORRECT SEQUENCE", show_internal_timer)
	_timer_label = header.timer
	

func _on_timeout() -> void:
	_finish_round(false, "FAILED TO INPUT SEQUENCE!")

#_finish_round(true, "WENT THROUGH THE ROUNDABOUT!")
