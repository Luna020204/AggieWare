extends "res://scripts/core/microgame_base.gd"

## Register every class after pass time opens at 8:00 AM.
const UI := preload("res://scripts/ui/microgame_ui.gd")
const OPEN_DELAY := 1.5
const WINDOWS: Array[float] = [7.5, 6.5, 5.5]
const CLASS_NAMES: Array[String] = ["ECS 179", "MAT 21D", "UWP 101", "ECS 140A", "STA 100"]
const SLOTS: Array[Vector2] = [
	Vector2(50, 300), Vector2(50, 365), Vector2(50, 430),
	Vector2(50, 495), Vector2(50, 560),
]
const NAVY := Color("022851")
const BLUE := Color("31577d")
const GOLD := Color("e8b923")
const CREAM := Color("fff8e6")
const INK := Color("173956")
const MUTED_INK := Color("526678")

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
	_art = UI.pixel_canvas(self, _draw_world)
	var header := UI.build_header(self, "SCHEDULE BUILDER", "WAIT FOR 8:00, THEN REGISTER.", show_internal_timer)
	_timer_label = header.timer
	UI.label(self, "myucdavis", Vector2(260, 18), 21, UI.ACCENT, Vector2(190, 30))
	UI.label(self, "ACADEMICS", Vector2(485, 18), 14, UI.TEXT, Vector2(150, 30))
	UI.label(self, "STUDENT LIFE", Vector2(675, 18), 14, UI.TEXT, Vector2(190, 30))
	UI.label(self, "My Schedule", Vector2(45, 75), 28, INK, Vector2(320, 35))
	UI.label(self, "ADD / SEARCH COURSES", Vector2(390, 80), 14, INK, Vector2(270, 25))
	UI.label(self, "CREATE NEW SCHEDULE", Vector2(690, 80), 14, INK, Vector2(275, 25))
	UI.label(self, "REGISTER ALL", Vector2(1000, 80), 14, INK, Vector2(200, 25))
	UI.label(self, "SEARCH FOR COURSES", Vector2(55, 125), 21, INK, Vector2(380, 25))
	UI.label(self, "CRN, SUBJECT, INSTRUCTOR, OR KEYWORD", Vector2(60, 164), 14, MUTED_INK, Vector2(640, 25))
	UI.label(self, "SEARCH", Vector2(492, 193), 21, UI.TEXT, Vector2(170, 30))
	UI.label(self, "SCHEDULE 1", Vector2(65, 245), 21, INK, Vector2(220, 30))
	_clock_label = UI.label(self, "", Vector2(280, 245), 21, INK, Vector2(300, 30))
	_progress_label = UI.label(self, "", Vector2(605, 245), 21, INK, Vector2(270, 30))
	UI.label(self, "SUGGESTED COURSES", Vector2(925, 245), 21, INK, Vector2(310, 30))
	UI.label(self, "COMPUTER SCIENCE", Vector2(935, 300), 14, INK, Vector2(280, 30))
	UI.label(self, "PREVIOUSLY SAVED", Vector2(925, 390), 21, INK, Vector2(300, 30))
	UI.label(self, "COURSE DETAILS", Vector2(935, 450), 14, INK, Vector2(280, 30))
	UI.label(self, "COURSE SECTIONS", Vector2(935, 500), 14, INK, Vector2(280, 30))
	_status_label = UI.status_label(self)
	_art.queue_redraw()


func _draw_world() -> void:
	_rect(0, 0, 1280, 720, Color("f6f8fa"))
	_rect(0, 0, 1280, 55, NAVY)
	_rect(0, 55, 1280, 60, Color.WHITE)
	_rect(370, 65, 865, 42, GOLD)
	_rect(370, 65, 865, 4, Color("f5d675"))
	for x in [670, 975]:
		_rect(x, 69, 3, 38, Color("c49018"))
	_rect(40, 120, 1195, 100, CREAM)
	_rect(40, 120, 1195, 32, Color("ead59a"))
	_rect(50, 185, 420, 28, Color.WHITE)
	_rect(50, 185, 420, 2, Color("bdc8d2"))
	_rect(475, 185, 160, 28, NAVY)
	_rect(40, 230, 850, 430, Color("e5eaf0"))
	_rect(40, 230, 850, 55, Color("ccd5e0"))
	_rect(910, 230, 325, 145, CREAM)
	_rect(910, 230, 325, 55, Color("ead59a"))
	_rect(925, 290, 295, 60, Color.WHITE)
	_rect(910, 380, 325, 210, CREAM)
	_rect(910, 380, 325, 55, Color("ead59a"))
	_rect(925, 440, 295, 130, Color.WHITE)
	_rect(925, 485, 295, 2, Color("cbd3dd"))
	for button: Button in _buttons:
		var box := Rect2(button.position, button.size)
		_art.draw_rect(Rect2(box.position + Vector2(3, 4), box.size), Color("c2ccd5"))
		_art.draw_rect(box, Color("e9f4ea") if button.disabled else Color.WHITE)
		_art.draw_rect(Rect2(box.position, Vector2(box.size.x, 2)), Color("c8d3df"))
		_art.draw_rect(Rect2(box.position + Vector2(610, 7), Vector2(190, 42)), BLUE if button.disabled else NAVY)
		_art.draw_rect(Rect2(box.position + Vector2(610, 7), Vector2(190, 3)), Color("6684a0"))
	_rect(40, 670, 1195, 2, Color("cbd3dd"))


func _rect(x: float, y: float, width: float, height: float, color: Color) -> void:
	_art.draw_rect(Rect2(x, y, width, height), color)


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
		button.position = SLOTS[index]
		button.size = Vector2(810, 55)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		UI.flat_button(button, 21)
		button.pressed.connect(_register.bind(index))
		add_child(button)
		UI.label(button, CLASS_NAMES[index], Vector2(15, 15), 21, INK, Vector2(210, 30))
		UI.label(button, "OPEN  /  0 WAITLIST", Vector2(245, 19), 14, MUTED_INK, Vector2(360, 25))
		var action := UI.label(button, "REGISTER", Vector2(625, 16), 21, UI.TEXT, Vector2(170, 30))
		action.name = "ActionLabel"
		_buttons.append(button)
	_art.queue_redraw()


func _register(index: int) -> void:
	if not can_interact() or index < 0 or index >= _buttons.size() or _buttons[index].disabled:
		return
	if _seconds_left > maxf(_round_seconds - OPEN_DELAY, 0.0):
		show_feedback("WAIT UNTIL 8:00!", UI.REJECT)
		return
	_buttons[index].disabled = true
	var action: Label = _buttons[index].get_node("ActionLabel")
	action.text = "DONE"
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
	_art.queue_redraw()


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
