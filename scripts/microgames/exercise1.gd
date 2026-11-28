extends MicrogameBase

const ROUND_SECONDS: Array[float] = [9.0, 8.0, 7.0]
var _timer_label: Label
const UI := preload("res://scripts/ui/microgame_ui.gd")
signal microgame_end(outcome:bool)
var success:bool
@onready var BringerSprite = %BringerSprite
@onready var WarriorSprite = %WarriorSprite

@onready var Bringer = %Bringer
	
func get_round_seconds() -> float:
	return ROUND_SECONDS[clampi(difficulty, 0, 2)]


func _build_ui() -> void:
	var header := UI.build_header(self, "EXERCISE 1", "STRIKE THE BOSS AT THE RIGHT TIME", show_internal_timer)
	_timer_label = header.timer
	
func _reset_game() -> void:
	#_timer_label.text = "TIME %.1f" % _seconds_left
	pass

func _on_timeout() -> void:
	_finish_round(false, "FAILED TO DEFEAT BOSS!")
	success = false
	microgame_end.emit(success)


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body == Bringer and success == false:
		BringerSprite.play("Attack")
		WarriorSprite.play("Death")
		_finish_round(false, "FAILED TO DEFEAT BOSS!")
		microgame_end.emit(success)
