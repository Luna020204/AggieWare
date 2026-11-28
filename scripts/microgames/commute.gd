extends MicrogameBase

const ROUND_SECONDS: Array[float] = [9.0, 8.0, 7.0]
var _timer_label: Label
const UI := preload("res://scripts/ui/microgame_ui.gd")
signal microgame_end

@onready var Player = %AggieCarPlayer
@onready var Camera = %Camera2D
	
## Called when the node enters the scene tree for the first time.
#func _ready() -> void:
	#pass # Replace with function body.


## Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
	#pass
	
func _process(delta: float) -> void:
	super._process(delta)

	if is_playing():
		_timer_label.position.y -= Camera.speed * delta
	
func get_round_seconds() -> float:
	return ROUND_SECONDS[clampi(difficulty, 0, 2)]


func _build_ui() -> void:
	var header := UI.build_header(self, "COMMUTE", "DRIVE THROUGH TRAFFIC SAFELY", show_internal_timer)
	_timer_label = header.timer
	
func _reset_game() -> void:
	#_timer_label.text = "TIME %.1f" % _seconds_left
	pass

func _on_timeout() -> void:
	_finish_round(true, "ARRIVING ON TIME!")
	microgame_end.emit()


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body == Player:
		_finish_round(false, "STAY CLEAR OF TRAFFIC!")
		microgame_end.emit()
