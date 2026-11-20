extends Control

## SCRUM-76: Stay Awake (Lecture Hall).
##
## Z's drift toward the sleepy student. Click every Z before it reaches them.
## Mouse and click only. One Z reaching the student fails the round; staying
## awake until the bell wins it.
##
## Difficulty (0..2): more Z's, faster drift, smaller targets.

signal round_completed(success: bool)
signal time_changed(seconds_left: float, round_seconds: float)

@export_range(0, 2, 1) var difficulty: int = 0
@export var show_internal_timer: bool = true

const DURATIONS: Array[float] = [8.0, 7.0, 6.0]
const SPAWN_INTERVALS: Array[float] = [1.1, 0.75, 0.55]
const SPEEDS: Array[float] = [95.0, 135.0, 175.0]
const Z_SIZES: Array[float] = [76.0, 60.0, 46.0]
const STUDENT_CENTER := Vector2(640.0, 470.0)
const STUDENT_RADIUS := 70.0
## Spawn band: away from the title/HUD at the top and the student.
const SPAWN_LEFT := 60.0
const SPAWN_RIGHT := 1220.0
const SPAWN_TOP := 170.0

var _seconds_left := 0.0
var _ended := false
var _spawn_clock := 0.0
var _popped := 0
var _zs: Array[Button] = []
var _rng := RandomNumberGenerator.new()

var _student: Control
var _timer_label: Label
var _status_label: Label


func get_round_seconds() -> float:
	return DURATIONS[clampi(difficulty, 0, 2)]


func _ready() -> void:
	difficulty = clampi(difficulty, 0, 2)
	_rng.randomize()
	_build_ui()
	_start_round()


func _process(delta: float) -> void:
	if _ended:
		return
	_seconds_left = maxf(0.0, _seconds_left - delta)
	_timer_label.text = "BELL IN  %.1f s" % _seconds_left
	time_changed.emit(_seconds_left, DURATIONS[difficulty])
	_spawn_clock += delta
	if _spawn_clock >= SPAWN_INTERVALS[difficulty] and _seconds_left > 0.6:
		_spawn_clock = 0.0
		spawn_z()
	for z: Button in _zs.duplicate():
		var center := z.position + z.size * 0.5
		var to_student := STUDENT_CENTER - center
		if to_student.length() <= STUDENT_RADIUS:
			_finish_round(false, "Zzz… you fell asleep in lecture!")
			return
		z.position += to_student.normalized() * SPEEDS[difficulty] * delta
		z.rotation = sin(Time.get_ticks_msec() * 0.004 + z.get_instance_id()) * 0.25
	_student.queue_redraw()
	if _seconds_left <= 0.0:
		_finish_round(true, "Ding! You stayed awake — %d Z's popped." % _popped)


## Spawns one Z on the top or side edges. Public for tests.
func spawn_z(at: Vector2 = Vector2.INF) -> Button:
	var size := Z_SIZES[difficulty]
	if at == Vector2.INF:
		match _rng.randi_range(0, 2):
			0:
				at = Vector2(_rng.randf_range(SPAWN_LEFT, SPAWN_RIGHT - size), SPAWN_TOP)
			1:
				at = Vector2(SPAWN_LEFT, _rng.randf_range(SPAWN_TOP, 560.0))
			_:
				at = Vector2(SPAWN_RIGHT - size, _rng.randf_range(SPAWN_TOP, 560.0))
	var z := Button.new()
	z.text = "Z"
	z.size = Vector2(size, size)
	z.pivot_offset = z.size * 0.5
	z.position = at
	z.focus_mode = Control.FOCUS_NONE  # mouse only
	z.add_theme_font_size_override("font_size", int(size * 0.62))
	z.add_theme_color_override("font_color", Color("#1a1430"))
	z.add_theme_color_override("font_hover_color", Color("#1a1430"))
	z.add_theme_color_override("font_pressed_color", Color("#1a1430"))
	for state: String in ["normal", "hover", "pressed"]:
		z.add_theme_stylebox_override(state, _bubble(state == "hover"))
	z.button_down.connect(pop_z.bind(z))
	add_child(z)
	_zs.append(z)
	return z


func pop_z(z: Button) -> void:
	if _ended or not _zs.has(z):
		return
	_zs.erase(z)
	_popped += 1
	z.queue_free()
	_status_label.text = "POP!  %d" % _popped


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("#1a1420")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	for row: int in 2:
		var seats := ColorRect.new()
		seats.color = Color("#2b2033") if row == 0 else Color("#33263d")
		seats.position = Vector2(0.0, 640.0 + row * 40.0)
		seats.size = Vector2(1280.0, 40.0)
		seats.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(seats)

	var title := Label.new()
	title.text = "STAY AWAKE"
	title.position = Vector2(48, 35)
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#f5f7ff"))
	add_child(title)

	var instruction := Label.new()
	instruction.text = "Click every Z before it reaches you."
	instruction.position = Vector2(48, 92)
	instruction.add_theme_font_size_override("font_size", 20)
	instruction.add_theme_color_override("font_color", Color("#c9b8e6"))
	add_child(instruction)

	_timer_label = Label.new()
	_timer_label.position = Vector2(48, 132)
	_timer_label.add_theme_font_size_override("font_size", 22)
	_timer_label.add_theme_color_override("font_color", Color("#ffd166"))
	_timer_label.visible = show_internal_timer
	add_child(_timer_label)

	_student = Control.new()
	_student.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_student.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_student.draw.connect(_draw_student)
	add_child(_student)

	_status_label = Label.new()
	_status_label.position = Vector2(48, 590)
	_status_label.size = Vector2(1180, 40)
	_status_label.add_theme_font_size_override("font_size", 22)
	add_child(_status_label)


func _draw_student() -> void:
	var c := STUDENT_CENTER
	# Danger ring: dashed so it reads without colour.
	var segments := 24
	for i: int in segments:
		if i % 2 == 0:
			var a0 := TAU * i / segments
			var a1 := TAU * (i + 1) / segments
			_student.draw_arc(c, STUDENT_RADIUS, a0, a1, 6, Color("#6c5a8c"), 3.0)
	# Desk, head and drooping eyes.
	_student.draw_rect(Rect2(c.x - 140.0, c.y + 52.0, 280.0, 22.0), Color("#5b4636"))
	_student.draw_circle(c, 44.0, Color("#f1c9a5"))
	_student.draw_arc(c + Vector2(0.0, -6.0), 46.0, PI * 1.05, PI * 1.95, 16, Color("#3b2a1e"), 14.0)
	var droop := 1.0 - clampf(_seconds_left / DURATIONS[difficulty], 0.0, 1.0)
	for side: float in [-1.0, 1.0]:
		var eye := c + Vector2(16.0 * side, 2.0)
		_student.draw_line(eye + Vector2(-8.0, 0.0), eye + Vector2(8.0, 0.0), Color("#2a1e14"), 3.0)
		_student.draw_line(eye + Vector2(-8.0, -6.0 + droop * 6.0), eye + Vector2(8.0, -6.0 + droop * 6.0), Color("#2a1e14"), 3.0)


func _start_round() -> void:
	_ended = false
	_popped = 0
	_spawn_clock = SPAWN_INTERVALS[difficulty] * 0.6
	_seconds_left = DURATIONS[difficulty]
	for z: Button in _zs:
		z.queue_free()
	_zs.clear()
	_status_label.text = "Don't let the Z's reach you!"
	_status_label.add_theme_color_override("font_color", Color("#c9b8e6"))
	time_changed.emit(_seconds_left, DURATIONS[difficulty])


func _finish_round(success: bool, message: String) -> void:
	if _ended:
		return
	_ended = true
	for z: Button in _zs:
		z.disabled = true
	_status_label.text = ("✔ " if success else "✖ ") + message
	_status_label.add_theme_color_override("font_color", Color("#73e6a8") if success else Color("#ff9e9e"))
	round_completed.emit(success)


func _bubble(hover: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#f5f0ff") if hover else Color("#c9b8e6")
	style.border_color = Color("#1a1430")
	style.set_border_width_all(3)
	style.set_corner_radius_all(40)
	return style
