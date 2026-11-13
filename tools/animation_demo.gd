extends Node2D

@onready var controller = $Character/AnimationController
@onready var status: Label = $UI/Panel/Status
var difficulty: float = 1.0


func _ready() -> void:
	for state in controller.STATES:
		var button := Button.new()
		button.text = String(state).capitalize()
		button.pressed.connect(func(): controller.set_state(state))
		$UI/Panel/States.add_child(button)
	$UI/Panel/Reset.pressed.connect(func(): controller.reset_for_microgame(difficulty))
	$UI/Panel/Difficulty.value_changed.connect(_on_difficulty_changed)
	controller.state_changed.connect(func(_state): _update_status())
	_update_status()


func _on_difficulty_changed(value: float) -> void:
	difficulty = value
	controller.set_difficulty(value)
	_update_status()


func _update_status() -> void:
	status.text = "State: %s | Difficulty: %d | Speed: %.2fx" % [
		controller.current_state, difficulty, controller.playback_speed]
