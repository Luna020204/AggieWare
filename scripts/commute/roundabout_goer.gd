extends CharacterBody2D
##ADD SPRITE CHANGES BASED ON DIRECTION

@export var speed = 400
@onready var sprite_2d: Sprite2D = $Sprite2D
var can_move := false

func _ready() -> void:
	await get_parent().get_parent().ready
	var microgame = get_parent().get_parent()

	while not microgame.is_playing():
		await get_tree().process_frame

	can_move = true
	microgame.microgame_end.connect(_on_end)


func _on_end(success:bool) -> void:
	can_move = false
	if success == false:
		velocity = Vector2(0,0) * speed
	elif success == true:
		velocity = Vector2(0,1) * speed
	

func _physics_process(_delta: float) -> void:
	if can_move:
		var direction := Input.get_vector("game_left", "game_right", "game_up", "game_down")
		velocity = direction * speed
	
	if Input.is_action_pressed("game_left"):
		sprite_2d.flip_h = false
		sprite_2d.rotation_degrees = 0
	elif Input.is_action_pressed("game_right"):
		sprite_2d.flip_h = true
		sprite_2d.rotation_degrees = 0
	elif Input.is_action_pressed("game_up"):
		sprite_2d.flip_h = false
		sprite_2d.rotation_degrees = 90.0
	elif Input.is_action_pressed("game_down"):
		sprite_2d.flip_h = true
		sprite_2d.rotation_degrees = 90.0

	move_and_slide()
