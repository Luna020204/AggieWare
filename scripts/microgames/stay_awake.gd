extends Control

## SCRUM-76: Stay Awake (Lecture Hall).
##
## In the ECS 179 lecture hall, where the class is playing a game on the
## projector screen, Z's drift toward a drowsy student. Click every
## Z before it reaches them. Mouse and click only. One Z reaching the student
## fails the round; staying awake until the bell wins it.
##
## Follows the AggieWare format standard: the round opens with the student
## walking into the lecture building while the title and instruction show
## (WalkInIntro; the timer waits, a click skips it),
## only the timer and a pop counter during play, and results as centred pops.
## Art is pixel art drawn at 1/5 scale (tools/art/gen_stay_awake_art.py) and
## shown at 5x with nearest filtering.
##
## Difficulty (0..2): more Z's, faster drift, smaller targets.

signal round_completed(success: bool)
signal time_changed(seconds_left: float, round_seconds: float)

@export_range(0, 2, 1) var difficulty: int = 0
@export var show_internal_timer: bool = true

const DURATIONS: Array[float] = [8.0, 7.0, 6.0]
## The walk-in intro: the student's feet from the walkway to the entrance,
## and the entrance doors, in exterior-art pixels.
const INTRO_SECONDS := WalkInIntro.DURATION
const WALK_PATH: Array[Vector2] = [Vector2(70, 150), Vector2(120, 134), Vector2(210, 122)]
const WALKER_SIZE := Vector2(16.0, 30.0)
const DOOR_RECT := Rect2(194.0, 84.0, 32.0, 38.0)
const SPAWN_INTERVALS: Array[float] = [1.1, 0.75, 0.55]
const SPEEDS: Array[float] = [95.0, 135.0, 175.0]
## Z sprites are 15, 12 and 9 px, shown at 5x.
const Z_SIZES: Array[float] = [75.0, 60.0, 45.0]
const STUDENT_CENTER := Vector2(640.0, 470.0)
const STUDENT_RADIUS := 70.0
## The student sprite is 28x26 with the head centred at (14, 6).
const STUDENT_SIZE := Vector2(28.0, 26.0)
const STUDENT_HEAD := Vector2(14.0, 6.0)
## The student looks drowsy while a Z is this close.
const DROWSY_DISTANCE := 240.0
## Spawn band: away from the timer at the top left and the student.
const SPAWN_LEFT := 60.0
const SPAWN_RIGHT := 1220.0
const SPAWN_TOP := 170.0
const PX := 5.0
const ART := "res://assets/art/microgames/stay_awake/"
const HALL_TEXTURE := preload(ART + "lecture_hall.png")
const AWAKE_TEXTURE := preload(ART + "student_awake.png")
const DROWSY_TEXTURE := preload(ART + "student_drowsy.png")
const BUILDING_TEXTURE := preload(ART + "building_exterior.png")
const BUILDING_DOOR_TEXTURE := preload(ART + "building_door_open.png")
## The same student who walks into Peet's in Swipe Card.
const WALKER_TEXTURES := [
	preload("res://assets/art/microgames/swipe_card/student_walk_0.png"),
	preload("res://assets/art/microgames/swipe_card/student_walk_1.png"),
	preload("res://assets/art/microgames/swipe_card/student_walk_2.png"),
]
const PROFESSOR_TEXTURE := preload(ART + "professor.png")
const SCREEN_TEXTURES := [preload(ART + "projector_game_0.png"), preload(ART + "projector_game_1.png")]
## The projected game and the professor, in scene pixels (see the art script).
const SCREEN_RECT := Rect2(88.0, 50.0, 84.0, 26.0)
const PROFESSOR_POS := Vector2(92.0, 66.0)
const PROFESSOR_SIZE := Vector2(16.0, 30.0)
const SCREEN_FRAME_SECONDS := 0.35
const Z_TEXTURES := [preload(ART + "z_15.png"), preload(ART + "z_12.png"), preload(ART + "z_9.png")]

var _seconds_left := 0.0
var _intro_left := 0.0
var _ended := false
var _spawn_clock := 0.0
var _popped := 0
var _zs: Array[Button] = []
var _rng := RandomNumberGenerator.new()

var _screen: TextureRect
var _screen_clock := 0.0
var _student: TextureRect
var _ring: Control
var _timer_label: Label
var _count_label: Label
var _walk_in: WalkInIntro
var _overlay: MicrogameOverlay
## Result messages (the overlay's pop label).
var _status_label: Label


func get_round_seconds() -> float:
	return DURATIONS[clampi(difficulty, 0, 2)]


## Time before the round timer starts, for tools that wait for a timeout.
func get_intro_seconds() -> float:
	return INTRO_SECONDS


## Ends the intro at once. Public for tests.
func skip_intro() -> void:
	_intro_left = 0.0
	_update_intro()


## Lays out the intro for the current moment of its timeline.
func _update_intro() -> void:
	var running := _intro_left > 0.0
	var title_alpha := _walk_in.show_at(INTRO_SECONDS - _intro_left if running else INTRO_SECONDS)
	_overlay.set_intro(running, title_alpha)


func _ready() -> void:
	difficulty = clampi(difficulty, 0, 2)
	_rng.randomize()
	_build_ui()
	_start_round()


func _process(delta: float) -> void:
	_screen_clock += delta
	_screen.texture = SCREEN_TEXTURES[int(_screen_clock / SCREEN_FRAME_SECONDS) % SCREEN_TEXTURES.size()]
	if _ended:
		return
	if _intro_left > 0.0:
		_intro_left = maxf(0.0, _intro_left - delta)
		_update_intro()
		return
	_seconds_left = maxf(0.0, _seconds_left - delta)
	_timer_label.text = "TIME %.1f" % _seconds_left
	time_changed.emit(_seconds_left, DURATIONS[difficulty])
	_spawn_clock += delta
	if _spawn_clock >= SPAWN_INTERVALS[difficulty] and _seconds_left > 0.6:
		_spawn_clock = 0.0
		spawn_z()
	var nearest := INF
	for z: Button in _zs.duplicate():
		var center := z.position + z.size * 0.5
		var to_student := STUDENT_CENTER - center
		nearest = minf(nearest, to_student.length())
		if to_student.length() <= STUDENT_RADIUS:
			_finish_round(false, "ZZZ... YOU FELL ASLEEP!")
			return
		z.position += to_student.normalized() * SPEEDS[difficulty] * delta
	_student.texture = DROWSY_TEXTURE if nearest < DROWSY_DISTANCE else AWAKE_TEXTURE
	if _seconds_left <= 0.0:
		_finish_round(true, "DING! YOU STAYED AWAKE!\n%d Z'S POPPED" % _popped)


func _input(event: InputEvent) -> void:
	if _intro_left > 0.0 and not _ended and event is InputEventMouseButton and event.pressed:
		skip_intro()
		get_viewport().set_input_as_handled()


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
	z.flat = true
	z.icon = Z_TEXTURES[difficulty]
	z.expand_icon = true
	z.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	z.size = Vector2(size, size)
	z.position = at
	z.focus_mode = Control.FOCUS_NONE  # mouse only
	z.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		z.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	z.add_theme_color_override("icon_hover_color", Color(1.0, 1.0, 0.8))
	z.button_down.connect(pop_z.bind(z))
	add_child(z)
	# Keep Z's under the walk-in scene and the text overlay.
	move_child(z, _walk_in.get_index())
	_zs.append(z)
	return z


func pop_z(z: Button) -> void:
	if _ended or not _zs.has(z):
		return
	_zs.erase(z)
	_popped += 1
	z.queue_free()
	_count_label.text = "POPPED %d" % _popped


func _build_ui() -> void:
	# Pixel art stays crisp only with nearest filtering; children inherit it.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	PixelText.apply_theme(self)

	var hall := TextureRect.new()
	hall.texture = HALL_TEXTURE
	hall.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hall.stretch_mode = TextureRect.STRETCH_SCALE
	hall.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hall)

	# The game on the projector, then the professor standing in front of it.
	_screen = _pixel_rect(SCREEN_TEXTURES[0], SCREEN_RECT.position * PX, SCREEN_RECT.size * PX)
	add_child(_screen)
	add_child(_pixel_rect(PROFESSOR_TEXTURE, PROFESSOR_POS * PX, PROFESSOR_SIZE * PX))

	_student = TextureRect.new()
	_student.texture = AWAKE_TEXTURE
	_student.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_student.stretch_mode = TextureRect.STRETCH_SCALE
	_student.size = STUDENT_SIZE * PX
	_student.position = STUDENT_CENTER - STUDENT_HEAD * PX
	_student.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_student)

	_ring = Control.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ring.draw.connect(_draw_ring)
	add_child(_ring)

	# Top left: the timer, with the pop counter under it.
	_timer_label = PixelText.label(28, Color("#ffd166"))
	_timer_label.position = Vector2(32, 24)
	_timer_label.visible = show_internal_timer
	add_child(_timer_label)
	_count_label = PixelText.label(21, Color("#f5f7ff"), "POPPED 0")
	_count_label.position = Vector2(32, 66)
	add_child(_count_label)

	_walk_in = WalkInIntro.new()
	add_child(_walk_in)
	_walk_in.build(BUILDING_TEXTURE, BUILDING_DOOR_TEXTURE, DOOR_RECT, WALKER_TEXTURES, WALKER_SIZE, WALK_PATH)

	_overlay = MicrogameOverlay.new()
	add_child(_overlay)
	_overlay.build("STAY AWAKE", "Click the Z's before you fall asleep!")
	_status_label = _overlay.status_label


func _pixel_rect(texture: Texture2D, at: Vector2, rect_size: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.position = at
	rect.size = rect_size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## The danger ring around the student's head: pixel dashes, so it reads
## without colour.
func _draw_ring() -> void:
	var steps := 28
	for i: int in steps:
		if i % 2 == 0:
			var angle := TAU * i / steps
			var at := STUDENT_CENTER + Vector2(cos(angle), sin(angle)) * STUDENT_RADIUS
			var snapped := (at / PX).floor() * PX
			_ring.draw_rect(Rect2(snapped - Vector2(PX, PX) * 0.5, Vector2(PX, PX)), Color("#e2d8ff"))


func _start_round() -> void:
	_ended = false
	_popped = 0
	_spawn_clock = SPAWN_INTERVALS[difficulty] * 0.6
	_seconds_left = DURATIONS[difficulty]
	_intro_left = INTRO_SECONDS
	for z: Button in _zs:
		z.queue_free()
	_zs.clear()
	_count_label.text = "POPPED 0"
	_timer_label.text = "TIME %.1f" % _seconds_left
	_overlay.clear_pop()
	_update_intro()
	time_changed.emit(_seconds_left, DURATIONS[difficulty])


func _finish_round(success: bool, message: String) -> void:
	if _ended:
		return
	_ended = true
	_intro_left = 0.0
	_update_intro()
	for z: Button in _zs:
		z.disabled = true
	_overlay.pop(("✓ " if success else "✗ ") + message, Color("#73e6a8") if success else Color("#ff9e9e"), 42)
	round_completed.emit(success)
