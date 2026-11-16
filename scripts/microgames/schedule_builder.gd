extends Control

## SCRUM-71: register every class after pass time opens at 8:00 AM.

signal round_completed(success: bool)
signal time_changed(seconds_left: float, round_seconds: float)

@export_range(0, 2, 1) var difficulty: int = 0

const OPEN_DELAY := 1.5
const WINDOWS: Array[float] = [8.0, 7.0, 6.0]
const CLASS_NAMES: Array[String] = ["ECS 179", "MAT 21D", "UWP 101", "ECS 140A", "STA 100"]
const SLOTS: Array[Vector2] = [
	Vector2(115, 265), Vector2(480, 265), Vector2(845, 265),
	Vector2(300, 390), Vector2(665, 390),
]

var _seconds_left := 0.0
var _registered := 0
var _ended := false
var _shuffle_clock := 0.0
var _buttons: Array[Button] = []
var _clock_label: Label
var _status_label: Label
var _progress_label: Label
var _rng := RandomNumberGenerator.new()


func get_round_seconds() -> float:
	return OPEN_DELAY + WINDOWS[clampi(difficulty, 0, 2)]


func _ready() -> void:
	difficulty = clampi(difficulty, 0, 2)
	_rng.randomize()
	_build_ui()
	_start_round()


func _process(delta: float) -> void:
	if _ended:
		return
	_seconds_left = maxf(0.0, _seconds_left - delta)
	var window_left := maxf(0.0, _seconds_left)
	var total := OPEN_DELAY + WINDOWS[difficulty]
	time_changed.emit(window_left, total)
	if _seconds_left > WINDOWS[difficulty]:
		_clock_label.text = "PASS TIME  7:59 AM"
		return
	_clock_label.text = "PASS TIME  8:00 AM  |  %.1f s left" % window_left
	if _seconds_left <= 0.0:
		_finish_round(false, "Waitlisted! Register faster next time.")
		return
	if difficulty >= 1:
		_shuffle_clock += delta
		if _shuffle_clock >= 1.4:
			_shuffle_clock = 0.0
			_shuffle_unregistered()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("#101a2d")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var title := Label.new()
	title.text = "SCHEDULE BUILDER"
	title.position = Vector2(48, 35)
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#f5f7ff"))
	add_child(title)

	var instruction := Label.new()
	instruction.text = "Wait for 8:00 AM. Register every class before the waitlist fills."
	instruction.position = Vector2(48, 125)
	instruction.add_theme_font_size_override("font_size", 21)
	instruction.add_theme_color_override("font_color", Color("#b8c7e6"))
	add_child(instruction)

	_clock_label = Label.new()
	_clock_label.position = Vector2(48, 175)
	_clock_label.add_theme_font_size_override("font_size", 24)
	_clock_label.add_theme_color_override("font_color", Color("#ffd166"))
	add_child(_clock_label)

	_progress_label = Label.new()
	_progress_label.position = Vector2(48, 565)
	_progress_label.add_theme_font_size_override("font_size", 22)
	_progress_label.add_theme_color_override("font_color", Color("#73b7ff"))
	add_child(_progress_label)

	_status_label = Label.new()
	_status_label.position = Vector2(48, 625)
	_status_label.size = Vector2(1180, 48)
	_status_label.add_theme_font_size_override("font_size", 21)
	_status_label.add_theme_color_override("font_color", Color("#b8c7e6"))
	add_child(_status_label)


func _start_round() -> void:
	_ended = false
	_registered = 0
	_seconds_left = OPEN_DELAY + WINDOWS[difficulty]
	_shuffle_clock = 0.0
	_clock_label.text = "PASS TIME  7:59 AM"
	_status_label.text = "Registration opens at 8:00 AM"
	for button: Button in _buttons:
		button.queue_free()
	_buttons.clear()
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
	time_changed.emit(_seconds_left, _seconds_left)


func _register(index: int) -> void:
	if _ended or _buttons[index].disabled:
		return
	if _seconds_left > WINDOWS[difficulty]:
		_status_label.text = "Too early — wait for 8:00 AM!"
		return
	_buttons[index].disabled = true
	_buttons[index].text = "%s\nRegistered" % CLASS_NAMES[index]
	_registered += 1
	_progress_label.text = "REGISTERED  %d / %d" % [_registered, _buttons.size()]
	_status_label.text = "%s added to your schedule" % CLASS_NAMES[index]
	if _registered == _buttons.size():
		_finish_round(true, "Schedule complete — no waitlists!")


func _shuffle_unregistered() -> void:
	var open_indices: Array[int] = []
	var open_slots: Array[Vector2] = []
	for index: int in _buttons.size():
		if not _buttons[index].disabled:
			open_indices.append(index)
			open_slots.append(_buttons[index].position)
	open_slots.shuffle()
	for item: int in open_indices.size():
		_buttons[open_indices[item]].position = open_slots[item]


func _finish_round(success: bool, message: String) -> void:
	if _ended:
		return
	_ended = true
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", Color("#73e6a8") if success else Color("#ff9e9e"))
	for button: Button in _buttons:
		button.disabled = true
	round_completed.emit(success)
