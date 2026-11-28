extends CharacterBody2D


@export var speed = 400
@onready var Microgame = get_parent()
var can_move := false

func _ready() -> void:
	await get_parent().get_parent().ready
	var microgame = get_parent().get_parent()

	while not microgame.is_playing():
		await get_tree().process_frame

	can_move = true
	microgame.microgame_end.connect(_on_end)


func _on_end() -> void:
	can_move = false
	velocity = Vector2(0,0)

func _physics_process(_delta: float) -> void:
	if can_move:
		var direction := Input.get_vector("game_left", "game_right", "game_up", "game_down")
		velocity = direction * speed

	move_and_slide()
