extends "res://scripts/core/microgame_base.gd"

## Register every class after pass time opens at 8:00 AM.
const UI := preload("res://scripts/ui/microgame_ui.gd")
const OPEN_DELAY := 1.5
const WINDOWS: Array[float] = [8.0, 7.0, 6.0]
const CLASS_NAMES: Array[String] = ["ECS 179", "MAT 21D", "UWP 101", "ECS 140A", "STA 100"]
const SLOTS: Array[Vector2] = [
	Vector2(115, 265), Vector2(480, 265), Vector2(845, 265),
	Vector2(300, 390), Vector2(665, 390),
]

var _registered := 0
var _shuffle_clock := 0.0
var _buttons: Array[Button] = []
var _clock_label: Label
var _status_label: Label
var _progress_label: Label
var _rng := RandomNumberGenerator.new()


func get_round_seconds() -> float:
	return OPEN_DELAY + WINDOWS[clampi(difficulty, 0, 2)]


func _update_game(delta: float) -> void:
	var registration_window := maxf(_round_seconds - OPEN_DELAY, 0.0)
	if _seconds_left > registration_window:
		_clock_label.text = "PASS TIME  7:59 AM"
		return
	_clock_label.text = "PASS TIME  8:00 AM"
	if show_internal_timer:
		_clock_label.text += "  |  %.1f s left" % _seconds_left
	if _seconds_left <= 0.0:
		return
	if difficulty >= 1:
		# Only count the portion of this frame after registration opened.
		_shuffle_clock += minf(delta, registration_window - _seconds_left)
		while _shuffle_clock >= 1.4:
			_shuffle_clock -= 1.4
			_shuffle_unregistered()


func _build_ui() -> void:
	_rng.randomize()
	var header := UI.build_header(self, "SCHEDULE BUILDER", "Wait for 8:00 AM. Register every class before the waitlist fills.")
	# Pass time is the gameplay cue, so it remains visible in hosted rounds.
	_clock_label = header.timer
	_progress_label = UI.label(self, "", Vector2(48, 565), 22, Color("#73b7ff"))
	_status_label = UI.label(self, "", Vector2(48, 640), 20, UI.MUTED)


func _reset_game() -> void:
	_registered = 0
	_shuffle_clock = 0.0
	_clock_label.text = "PASS TIME  7:59 AM"
	UI.set_status(_status_label, "Registration opens at 8:00 AM")
	UI.clear_nodes(_buttons)
	var class_count := 3 + difficulty
	_progress_label.text = "REGISTERED  0 / %d" % class_count
	for index: int in class_count:
		var button := Button.new()
		button.text = "%s\nRegister" % CLASS_NAMES[index]
		button.position = SLOTS[index]
		button.size = Vector2(310, 90)
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(_register.bind(index))
		add_child(button)
		_buttons.append(button)


func _register(index: int) -> void:
	if not can_interact() or index < 0 or index >= _buttons.size() or _buttons[index].disabled:
		return
	if _seconds_left > maxf(_round_seconds - OPEN_DELAY, 0.0):
		UI.set_status(_status_label, "Too early — wait for 8:00 AM!", "warning")
		return
	_buttons[index].disabled = true
	_buttons[index].text = "%s\nRegistered" % CLASS_NAMES[index]
	_registered += 1
	_progress_label.text = "REGISTERED  %d / %d" % [_registered, _buttons.size()]
	UI.set_status(_status_label, "%s added to your schedule" % CLASS_NAMES[index], "success")
	if _registered == _buttons.size():
		_finish_round(true, "Schedule complete — no waitlists!")


func _shuffle_unregistered() -> void:
	var open_indices: Array[int] = []
	var open_slots: Array[Vector2] = []
	for index: int in _buttons.size():
		if not _buttons[index].disabled:
			open_indices.append(index)
			open_slots.append(_buttons[index].position)
	for index: int in range(open_slots.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, index)
		var saved := open_slots[index]
		open_slots[index] = open_slots[swap_index]
		open_slots[swap_index] = saved
	for item: int in open_indices.size():
		_buttons[open_indices[item]].position = open_slots[item]


func _on_timeout() -> void:
	_finish_round(false, "Waitlisted! Register faster next time.")


func _show_result(success: bool, message: String) -> void:
	UI.set_status(_status_label, message, "success" if success else "error")
	for button: Button in _buttons:
		button.disabled = true
