extends MicrogameBase

const ROUND_SECONDS: Array[float] = [9.0, 8.0, 7.0]
var _timer_label: Label
const UI := preload("res://scripts/ui/microgame_ui.gd")
signal microgame_end(outcome:bool)
var success:bool

@onready var Player = %Player
	
func get_round_seconds() -> float:
	return ROUND_SECONDS[clampi(difficulty, 0, 2)]


func _build_ui() -> void:
	var header := UI.build_header(self, "ROUNDABOUT", "PASS THROUGH THE ROUNDABOUT SAFELY", show_internal_timer)
	_timer_label = header.timer
	
func _reset_game() -> void:
	#_timer_label.text = "TIME %.1f" % _seconds_left
	pass

func _on_timeout() -> void:
	_finish_round(false, "FAILED TO MAKE THE ROUNDABOUT!")
	success = false
	microgame_end.emit(success)


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body == Player:
		_finish_round(true, "WENT THROUGH THE ROUNDABOUT!")
		success = true
		microgame_end.emit(success)


func _on_wrong_way_up_body_entered(body: Node2D) -> void:
	if body == Player:
		_finish_round(false, "WRONG WAY!")
		success = false
		microgame_end.emit(success)
