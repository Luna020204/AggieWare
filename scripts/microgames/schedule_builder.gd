extends "res://scripts/core/microgame_base.gd"

## Register every class after pass time opens at 8:00 AM.
const UI := preload("res://scripts/ui/microgame_ui.gd")
const OPEN_DELAY := 1.5
const WINDOWS: Array[float] = [7.5, 6.5, 5.5]
const CLASS_NAMES: Array[String] = ["ECS 179", "MAT 21D", "UWP 101", "ECS 140A", "STA 100"]
const SLOTS: Array[Vector2] = [
	Vector2(115, 265), Vector2(480, 265), Vector2(845, 265),
	Vector2(300, 390), Vector2(665, 390),
]

var _registered := 0
var _shuffle_clock := 0.0
var _buttons: Array[Button] = []
var _clock_label: Label
var _timer_label: Label
var _art: Control
var _status_label: Label
var _progress_label: Label
var _rng := RandomNumberGenerator.new()


func get_round_seconds() -> float:
	return OPEN_DELAY + WINDOWS[clampi(difficulty, 0, 2)]


func _update_game(delta: float) -> void:
	_timer_label.text = "TIME %.1f" % _seconds_left
	_art.queue_redraw()
	var registration_window := maxf(_round_seconds - OPEN_DELAY, 0.0)
	if _seconds_left > registration_window:
		_clock_label.text = "PASS TIME  7:59 AM"
		return
	_clock_label.text = "PASS TIME  8:00 AM"
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
	UI.add_backdrop(self, "campus")
	_art = UI.pixel_canvas(self, _draw_world)
	var header := UI.build_header(self, "SCHEDULE BUILDER", "WAIT FOR 8:00, THEN REGISTER.", show_internal_timer)
	_timer_label = header.timer
	_clock_label = UI.label(self, "", Vector2(30, 65), 14, UI.TEXT, Vector2(400, 20))
	_progress_label = UI.label(self, "", Vector2(30, 85), 14, UI.TEXT, Vector2(400, 20))
	UI.label(self, "REGISTRAR", Vector2(145, 195), 28, UI.GOLD, Vector2(900, 40))
	_status_label = UI.status_label(self)


func _draw_world() -> void:
	_art.draw_rect(Rect2(100, 190, 30, 500), Color("664331"))
	_art.draw_rect(Rect2(1150, 190, 30, 500), Color("664331"))
	_art.draw_rect(Rect2(80, 175, 1120, 415), Color("674535"))
	_art.draw_rect(Rect2(95, 190, 1090, 385), Color("a27b4e"))
	for row in 12:
		for dot in 27:
			_art.draw_rect(Rect2(110 + dot * 40 + (row % 2) * 10, 205 + row * 30, 5, 5), Color("947044"))
	for button: Button in _buttons:
		var paper := Rect2(button.position, button.size)
		_art.draw_rect(Rect2(paper.position + Vector2(5, 10), paper.size), Color("614839"))
		_art.draw_rect(paper, Color("b7ccb0") if button.disabled else Color("f1e2b9"))
		_art.draw_rect(Rect2(paper.position + Vector2(8, 8), Vector2(8, 8)), Color("b45844"))
		_art.draw_rect(Rect2(paper.position + Vector2(paper.size.x - 16, 8), Vector2(8, 8)), Color("b45844"))
		_art.draw_rect(Rect2(paper.position + Vector2(15, paper.size.y - 12), Vector2(paper.size.x - 30, 4)), Color("c2ba94"))

func _reset_game() -> void:
	_registered = 0
	_shuffle_clock = 0.0
	_clock_label.text = "PASS TIME  7:59 AM"
	_timer_label.text = "TIME %.1f" % _seconds_left
	UI.set_status(_status_label, "")
	UI.clear_nodes(_buttons)
	var class_count := 3 + difficulty
	_progress_label.text = "REGISTERED  0 / %d" % class_count
	for index: int in class_count:
		var button := Button.new()
		button.text = "%s\nREGISTER" % CLASS_NAMES[index]
		button.position = SLOTS[index]
		button.size = Vector2(310, 90)
		button.focus_mode = Control.FOCUS_NONE
		UI.flat_button(button, 21)
		button.add_theme_color_override("font_color", Color("263344"))
		button.add_theme_color_override("font_hover_color", Color("46604b"))
		button.add_theme_color_override("font_pressed_color", Color("46604b"))
		button.add_theme_color_override("font_disabled_color", Color("46604b"))
		button.pressed.connect(_register.bind(index))
		add_child(button)
		_buttons.append(button)
	_art.queue_redraw()


func _register(index: int) -> void:
	if not can_interact() or index < 0 or index >= _buttons.size() or _buttons[index].disabled:
		return
	if _seconds_left > maxf(_round_seconds - OPEN_DELAY, 0.0):
		show_feedback("WAIT UNTIL 8:00!", UI.REJECT)
		return
	_buttons[index].disabled = true
	_buttons[index].text = "%s\nREGISTERED" % CLASS_NAMES[index]
	_registered += 1
	_progress_label.text = "REGISTERED  %d / %d" % [_registered, _buttons.size()]
	_art.queue_redraw()
	if _registered == _buttons.size():
		_finish_round(true, "REGISTERED!")


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
	_finish_round(false, "WAITLISTED!")


func _update_intro_progress(elapsed: float, duration: float) -> void:
	_clock_label.visible = duration <= 0.0 or elapsed >= duration
	_progress_label.visible = _clock_label.visible


func _show_result(_success: bool, _message: String) -> void:
	_clock_label.hide()
	_progress_label.hide()
	for button: Button in _buttons:
		button.disabled = true
	_art.queue_redraw()
