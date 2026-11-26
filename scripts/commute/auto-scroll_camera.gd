extends Camera2D

@export var speed = 350
@onready var Player = %AggieCarPlayer
var can_move := false

func _ready() -> void:
	await get_parent().get_parent().ready
	var microgame = get_parent().get_parent()

	while not microgame.is_playing():
		await get_tree().process_frame

	can_move = true
	microgame.microgame_end.connect(_on_end)

#360 camera y, 720 is lower boundary

func _on_end() -> void:
	can_move = false
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if can_move and Player.global_position.y > global_position.y + 360:
		Player.global_position.y = global_position.y + 360
	elif can_move and Player.global_position.y < global_position.y - 360:
		Player.global_position.y = global_position.y - 360
	if can_move:
		global_position.y -= speed * delta
	
