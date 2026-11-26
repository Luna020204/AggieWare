extends CharacterBody2D

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

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	await get_parent().get_parent().ready
	var microgame = get_parent().get_parent()

	while not microgame.is_playing():
		await get_tree().process_frame
		
	QCF.visible = false
	Semi.visible = false
	Circle.visible = false
	Fireball.visible = false
	
	play(microgame)

func play(microgame: MicrogameBase):
	if microgame.difficulty == 0:
		QCF.visible = true
		qcf_sequence(microgame)
	elif microgame.difficulty == 1:
		Semi.visible = true
		semi_sequence(microgame)
	elif microgame.difficulty == 2:
		Circle.visible = true
		circle_sequence(microgame)

func qcf_sequence(microgame:MicrogameBase) -> void:
	while not Input.is_action_just_pressed("game_down"):
		await get_tree().process_frame
	QCF.texture = qcf_1
	while not Input.is_action_just_pressed("game_right"):
		await get_tree().process_frame
	QCF.texture = qcf_2
	while not Input.is_action_just_pressed("game_mash"):
		await get_tree().process_frame
	QCF.texture = qcf_3
	
	Fighter.texture = fighter_shoot
	Fireball.visible = true
	microgame._finish_round(true, "SUCCESSFULLY EXECUTED MOTION INPUT")

func circle_sequence(microgame:MicrogameBase) -> void:
	while not Input.is_action_just_pressed("game_right"):
		await get_tree().process_frame
	Circle.texture = circle_1
	while not Input.is_action_just_pressed("game_down"):
		await get_tree().process_frame
	Circle.texture = circle_2
	while not Input.is_action_just_pressed("game_left"):
		await get_tree().process_frame
	Circle.texture = circle_3
	while not Input.is_action_just_pressed("game_up"):
		await get_tree().process_frame
	Circle.texture = circle_4
	while not Input.is_action_just_pressed("game_right"):
		await get_tree().process_frame
	Circle.texture = circle_5
	while not Input.is_action_just_pressed("game_mash"):
		await get_tree().process_frame
	Circle.texture = circle_6

	Fighter.texture = fighter_shoot
	Fireball.visible = true
	microgame._finish_round(true, "SUCCESSFULLY EXECUTED MOTION INPUT")

func semi_sequence(microgame:MicrogameBase) -> void:
	while not Input.is_action_just_pressed("game_right"):
		await get_tree().process_frame
	Semi.texture = semi_1
	while not Input.is_action_just_pressed("game_down"):
		await get_tree().process_frame
	Semi.texture = semi_2
	while not Input.is_action_just_pressed("game_left"):
		await get_tree().process_frame
	Semi.texture = semi_3
	while not Input.is_action_just_pressed("game_right"):
		await get_tree().process_frame
	Semi.texture = semi_4
	while not Input.is_action_just_pressed("game_mash"):
		await get_tree().process_frame
	Semi.texture = semi_5

	Fighter.texture = fighter_shoot
	Fireball.visible = true
	microgame._finish_round(true, "SUCCESSFULLY EXECUTED MOTION INPUT")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
		
