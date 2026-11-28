extends CharacterBody2D


var SPEED = 400.0
var can_move := false

func _ready() -> void:
	await get_parent().get_parent().ready
	var microgame = get_parent().get_parent()

	while not microgame.is_playing():
		await get_tree().process_frame

	can_move = true
	if microgame.difficulty == 0:
		SPEED = 400
	elif microgame.difficulty == 1:
		SPEED = 600
	elif microgame.difficulty == 2:
		SPEED = 800
	microgame.microgame_end.connect(_on_end)


func _on_end() -> void:
	can_move = false
	velocity = Vector2(0,0)
	

func _physics_process(delta: float) -> void:

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := -1
	if direction and can_move:
		velocity.x = direction * SPEED

	move_and_slide()
