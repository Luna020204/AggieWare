extends Control

## SCRUM-77: move a blue shield to intercept distracting thoughts.

signal round_completed(success: bool)
signal time_changed(seconds_left: float, round_seconds: float)

@export_range(0, 2, 1) var difficulty: int = 0

const DURATIONS: Array[float] = [8.0, 7.0, 6.0]
const SPAWN_INTERVALS: Array[float] = [1.3, 0.95, 0.7]
const SPEEDS: Array[float] = [210.0, 275.0, 335.0]
const THOUGHTS: Array[String] = ["PHONE", "SNACK", "SOCIAL MEDIA", "NAP", "TEXTS"]

var _seconds_left := 0.0
var _spawn_clock := 0.0
var _blocked := 0
var _ended := false
var _shield: PanelContainer
var _status_label: Label
var _timer_label: Label
var _thoughts: Array[Control] = []
var _rng := RandomNumberGenerator.new()


func get_round_seconds() -> float:
	return DURATIONS[clampi(difficulty, 0, 2)]


func _ready() -> void:
	difficulty = clampi(difficulty, 0, 2)
	_rng.randomize()
	_build_ui()
	_start_round()


func _input(event: InputEvent) -> void:
	if _ended:
		return
	if event is InputEventMouseMotion:
		_shield.position.x = clampf(event.position.x - _shield.size.x * 0.5, 30.0, 1080.0)


func _process(delta: float) -> void:
	if _ended:
		return
	var direction := InputActions.get_strength(InputActions.ACTION_RIGHT) - InputActions.get_strength(InputActions.ACTION_LEFT)
	_shield.position.x = clampf(_shield.position.x + direction * 650.0 * delta, 30.0, 1080.0)
	_seconds_left = maxf(0.0, _seconds_left - delta)
	_timer_label.text = "EXAM  %.1f s" % _seconds_left
	time_changed.emit(_seconds_left, DURATIONS[difficulty])
	_spawn_clock += delta
	if _spawn_clock >= SPAWN_INTERVALS[difficulty]:
		_spawn_clock = 0.0
		_spawn_thought()
	for thought: Control in _thoughts.duplicate():
		thought.position.y += SPEEDS[difficulty] * delta
		if thought.get_global_rect().intersects(_shield.get_global_rect()):
			_blocked += 1
			_status_label.text = "Blocked %d distractions" % _blocked
			_remove_thought(thought)
		elif thought.position.y > 570.0:
			_finish_round(false, "A thought got through — refocus and try again!")
			return
	if _seconds_left <= 0.0:
		_finish_round(true, "Exam complete — you stayed focused!")


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("#101a2d")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var title := Label.new()
	title.text = "STAY FOCUSED"
	title.position = Vector2(48, 35)
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#f5f7ff"))
	add_child(title)
	var instruction := Label.new()
	instruction.text = "Move the blue shield with the mouse or Left / Right to block distractions."
	instruction.position = Vector2(48, 126)
	instruction.add_theme_font_size_override("font_size", 19)
	instruction.add_theme_color_override("font_color", Color("#b8c7e6"))
	add_child(instruction)
	_timer_label = Label.new()
	_timer_label.position = Vector2(48, 185)
	_timer_label.add_theme_font_size_override("font_size", 24)
	_timer_label.add_theme_color_override("font_color", Color("#ffd166"))
	add_child(_timer_label)
	var floor := ColorRect.new()
	floor.color = Color("#2d4b74")
	floor.position = Vector2(40, 610)
	floor.size = Vector2(1200, 4)
	floor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(floor)
	_shield = PanelContainer.new()
	_shield.position = Vector2(555, 550)
	_shield.size = Vector2(170, 50)
	_shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shield_style := StyleBoxFlat.new()
	shield_style.bg_color = Color("#2776d0")
	shield_style.border_color = Color("#a5d4ff")
	shield_style.set_border_width_all(3)
	shield_style.set_corner_radius_all(12)
	_shield.add_theme_stylebox_override("panel", shield_style)
	add_child(_shield)
	var shield_label := Label.new()
	shield_label.text = "FOCUS SHIELD"
	shield_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shield_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	shield_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shield.add_child(shield_label)
	_status_label = Label.new()
	_status_label.position = Vector2(48, 640)
	_status_label.add_theme_font_size_override("font_size", 20)
	_status_label.add_theme_color_override("font_color", Color("#b8c7e6"))
	add_child(_status_label)


func _start_round() -> void:
	_ended = false
	_blocked = 0
	_seconds_left = DURATIONS[difficulty]
	_spawn_clock = 0.0
	_status_label.text = "Block the thoughts until the exam ends"
	_timer_label.text = "EXAM  %.1f s" % _seconds_left
	for thought: Control in _thoughts:
		thought.queue_free()
	_thoughts.clear()
	time_changed.emit(_seconds_left, DURATIONS[difficulty])


func _spawn_thought() -> void:
	var thought := PanelContainer.new()
	thought.position = Vector2(_rng.randf_range(50.0, 1070.0), 245.0)
	thought.size = Vector2(160.0, 46.0)
	thought.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#a64359")
	style.set_corner_radius_all(8)
	thought.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = THOUGHTS[_rng.randi_range(0, THOUGHTS.size() - 1)]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thought.add_child(label)
	add_child(thought)
	_thoughts.append(thought)


func _remove_thought(thought: Control) -> void:
	_thoughts.erase(thought)
	thought.queue_free()


func _finish_round(success: bool, message: String) -> void:
	if _ended:
		return
	_ended = true
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", Color("#73e6a8") if success else Color("#ff9e9e"))
	round_completed.emit(success)
