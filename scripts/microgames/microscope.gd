extends Control

## SCRUM-84: Microscope (science lab).
##
## Pan the microscope with UP / LEFT / DOWN / RIGHT to find the new Aggie
## bacteria (gold, with an "A" and two horns) on the slide. Hold it in the
## crosshair for a moment, or press ACTION while it is in the crosshair.
## The clipboard on the wall shows the bacteria to find; the monitor on the
## bench maps where you are on the slide.
##
## Follows the AggieWare format standard: the round opens with the student,
## in a lab coat and goggles, walking into the lab building while the title
## and instruction show (WalkInIntro; the timer waits, a click skips it), only
## the timer during play, and results as centred pops. Art is pixel art drawn
## at 1/5 scale (tools/art/gen_microscope_art.py) and shown at 5x with nearest
## filtering; the slide view snaps to the same 5 px grid.
##
## Difficulty (0..2): bigger slide, more look-alike bacteria, smaller view,
## less time.

signal round_completed(success: bool)
signal time_changed(seconds_left: float, round_seconds: float)

@export_range(0, 2, 1) var difficulty: int = 0
@export var show_internal_timer: bool = true

const DURATIONS: Array[float] = [10.0, 9.0, 8.0]
const SLIDE_SIZES: Array[Vector2] = [Vector2(1200, 900), Vector2(1600, 1200), Vector2(2000, 1500)]
const DECOY_COUNTS: Array[int] = [5, 10, 16]
const VIEW_RADII: Array[float] = [190.0, 160.0, 130.0]
const PAN_SPEED := 620.0
const LOCK_RADIUS := 42.0
const LOCK_SECONDS := 0.35
const EYEPIECE_CENTER := Vector2(430.0, 410.0)
## The monitor's screen in the lab art, where the slide map is drawn.
const MINIMAP_RECT := Rect2(900.0, 420.0, 280.0, 160.0)
const BUG_RADIUS := 26.0
## Decoy kinds; "gold" (same colour, no A, no horns) only appears from NORMAL.
const DECOY_KINDS: Array[String] = ["blue", "rod", "gold"]
## Faint specks on the slide, so panning reads even where there are no bacteria.
const SPECKS_PER_MEGAPIXEL := 90
const MISS_FLASH_SECONDS := 0.35
const RIM_WIDTH := 15.0
## The walk-in intro: the student's feet up the walkway to the entrance, and
## the entrance doors, in exterior-art pixels.
const INTRO_SECONDS := WalkInIntro.DURATION
const WALK_PATH: Array[Vector2] = [Vector2(128, 158), Vector2(128, 123)]
const WALKER_SIZE := Vector2(16.0, 30.0)
const DOOR_RECT := Rect2(116.0, 94.0, 24.0, 28.0)
## The bacteria to find, on the clipboard sheet, in scene pixels.
const CLIPBOARD_BUG_POS := Vector2(182.0, 45.0)
const PX := 5.0
const ART := "res://assets/art/microgames/microscope/"
const LAB_TEXTURE := preload(ART + "lab_interior.png")
const BUILDING_TEXTURE := preload(ART + "lab_building.png")
const BUILDING_DOOR_TEXTURE := preload(ART + "lab_door_open.png")
## The student in a lab coat and goggles: standing, then two stepping frames.
const WALKER_TEXTURES := [
	preload(ART + "student_coat_0.png"),
	preload(ART + "student_coat_1.png"),
	preload(ART + "student_coat_2.png"),
]
const BUG_TEXTURES := {
	"aggie": preload(ART + "bacteria_aggie.png"),
	"gold": preload(ART + "bacteria_gold.png"),
	"blue": preload(ART + "bacteria_blue.png"),
	"rod": preload(ART + "bacteria_rod.png"),
}
const SLIDE_COLOR := Color("#e9f2d8")
const SPECK_COLOR := Color("#cddcb8")
const RIM_COLOR := Color("#3c4048")
const RIM_LIGHT := Color("#8c929c")
const INK := Color(0.17, 0.24, 0.2, 0.75)
const LOCK_COLOR := Color("#e8b84a")
const MISS_COLOR := Color("#d9534f")

var camera := Vector2.ZERO
var _seconds_left := 0.0
var _intro_left := 0.0
var _ended := false
var _lock_time := 0.0
var _miss_flash := 0.0
var _slide_size := Vector2.ZERO
var _target_pos := Vector2.ZERO
var _bugs: Array[Dictionary] = []
var _specks: Array[Vector2] = []
var _rng := RandomNumberGenerator.new()

## The eyepiece: a pixel disc that clips the slide view drawn inside it.
var _eyepiece: Control
var _view: Control
## The crosshair and lock ring, over the eyepiece.
var _reticle: Control
var _minimap: Control
var _timer_label: Label
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
	if _ended:
		return
	if _intro_left > 0.0:
		_intro_left = maxf(0.0, _intro_left - delta)
		_update_intro()
		return
	_seconds_left = maxf(0.0, _seconds_left - delta)
	_timer_label.text = "TIME %.1f" % _seconds_left
	time_changed.emit(_seconds_left, DURATIONS[difficulty])
	if _miss_flash > 0.0:
		_miss_flash = maxf(0.0, _miss_flash - delta)
		_reticle.queue_redraw()
	var direction := Vector2(
		InputActions.get_strength(InputActions.ACTION_RIGHT) - InputActions.get_strength(InputActions.ACTION_LEFT),
		InputActions.get_strength(InputActions.ACTION_DOWN) - InputActions.get_strength(InputActions.ACTION_UP)
	)
	move_camera(direction, delta)
	if InputActions.is_just_pressed(InputActions.ACTION_CONFIRM):
		confirm()
	if _ended:
		return
	var was_locking := _lock_time > 0.0
	if is_target_in_crosshair():
		_lock_time += delta
		if _lock_time >= LOCK_SECONDS:
			_finish_round(true, "FOUND THE AGGIE BACTERIA!")
			return
	else:
		_lock_time = 0.0
	if was_locking != (_lock_time > 0.0):
		_reticle.queue_redraw()
	if _seconds_left <= 0.0:
		_finish_round(false, "TIME'S UP! IT GOT AWAY.")


func _input(event: InputEvent) -> void:
	if _intro_left > 0.0 and not _ended and event is InputEventMouseButton and event.pressed:
		skip_intro()
		get_viewport().set_input_as_handled()


## Moves the view across the slide. Public for tests.
func move_camera(direction: Vector2, delta: float) -> void:
	if _ended:
		return
	if direction.length() > 1.0:
		direction = direction.normalized()
	camera = (camera + direction * PAN_SPEED * delta).clamp(Vector2.ZERO, _slide_size)
	_view.queue_redraw()
	_minimap.queue_redraw()


func is_target_in_crosshair() -> bool:
	return camera.distance_to(_target_pos) <= LOCK_RADIUS


## ACTION: confirm immediately if the target is in the crosshair; otherwise
## the crosshair flashes red.
func confirm() -> void:
	if _ended:
		return
	if is_target_in_crosshair():
		_finish_round(true, "FOUND THE AGGIE BACTERIA!")
	else:
		_miss_flash = MISS_FLASH_SECONDS
		_reticle.queue_redraw()


func _start_round() -> void:
	_ended = false
	_lock_time = 0.0
	_miss_flash = 0.0
	_seconds_left = DURATIONS[difficulty]
	_intro_left = INTRO_SECONDS
	_slide_size = SLIDE_SIZES[difficulty]
	camera = _slide_size * 0.5
	var margin := Vector2(80.0, 80.0)
	# Target: somewhere away from the starting view.
	while true:
		_target_pos = Vector2(_rng.randf_range(margin.x, _slide_size.x - margin.x), _rng.randf_range(margin.y, _slide_size.y - margin.y))
		if _target_pos.distance_to(camera) > VIEW_RADII[difficulty] * 1.6:
			break
	_bugs.clear()
	_bugs.append({"pos": _target_pos, "kind": "aggie", "rot": _rng.randf_range(-0.5, 0.5)})
	var kinds := DECOY_KINDS.slice(0, 2 if difficulty == 0 else 3)
	var tries := 0
	while _bugs.size() < DECOY_COUNTS[difficulty] + 1 and tries < 500:
		tries += 1
		var pos := Vector2(_rng.randf_range(margin.x, _slide_size.x - margin.x), _rng.randf_range(margin.y, _slide_size.y - margin.y))
		var clear := true
		for bug: Dictionary in _bugs:
			if pos.distance_to(bug["pos"]) < BUG_RADIUS * 4.0:
				clear = false
				break
		if clear:
			_bugs.append({"pos": pos, "kind": kinds[_rng.randi_range(0, kinds.size() - 1)], "rot": _rng.randf_range(-1.0, 1.0)})
	_specks.clear()
	for i: int in int(_slide_size.x * _slide_size.y / 1000000.0 * SPECKS_PER_MEGAPIXEL):
		_specks.append(Vector2(_rng.randf_range(0.0, _slide_size.x), _rng.randf_range(0.0, _slide_size.y)))
	_timer_label.text = "TIME %.1f" % _seconds_left
	_overlay.clear_pop()
	_update_intro()
	_view.queue_redraw()
	_reticle.queue_redraw()
	_minimap.queue_redraw()
	time_changed.emit(_seconds_left, DURATIONS[difficulty])


func _finish_round(success: bool, message: String) -> void:
	if _ended:
		return
	_ended = true
	_intro_left = 0.0
	_miss_flash = 0.0
	_update_intro()
	_reticle.queue_redraw()
	_overlay.pop(("✓ " if success else "✗ ") + message, Color("#73e6a8") if success else Color("#ff9e9e"), 42)
	round_completed.emit(success)


func _build_ui() -> void:
	# Pixel art stays crisp only with nearest filtering; children inherit it.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	PixelText.apply_theme(self)

	add_child(_pixel_rect(LAB_TEXTURE, Vector2.ZERO, Vector2(1280.0, 720.0)))
	# The bacteria to find, on the clipboard.
	var reference: Texture2D = BUG_TEXTURES["aggie"]
	add_child(_pixel_rect(reference, CLIPBOARD_BUG_POS * PX, reference.get_size() * PX))

	# The eyepiece: a dark rim, then the slide clipped to a pixel disc.
	var rim := Control.new()
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rim.draw.connect(_draw_rim.bind(rim))
	add_child(rim)
	_eyepiece = Control.new()
	_eyepiece.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_eyepiece.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_eyepiece.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_eyepiece.draw.connect(func() -> void: _pixel_disc(_eyepiece, EYEPIECE_CENTER, VIEW_RADII[difficulty], SLIDE_COLOR))
	add_child(_eyepiece)
	_view = Control.new()
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.draw.connect(_draw_view)
	_eyepiece.add_child(_view)
	_reticle = Control.new()
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reticle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reticle.draw.connect(_draw_reticle)
	add_child(_reticle)

	_minimap = Control.new()
	_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_minimap.draw.connect(_draw_minimap)
	add_child(_minimap)

	# Top left: the timer only.
	_timer_label = PixelText.label(28, Color("#ffd166"))
	_timer_label.position = Vector2(32, 24)
	_timer_label.visible = show_internal_timer
	add_child(_timer_label)

	_walk_in = WalkInIntro.new()
	add_child(_walk_in)
	_walk_in.build(BUILDING_TEXTURE, BUILDING_DOOR_TEXTURE, DOOR_RECT, WALKER_TEXTURES, WALKER_SIZE, WALK_PATH)

	_overlay = MicrogameOverlay.new()
	add_child(_overlay)
	_overlay.build("MICROSCOPE", "Arrow keys to find the Aggie bacteria!")
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


## A disc made of whole 5 px pixels, row by row.
func _pixel_disc(canvas: Control, center: Vector2, radius: float, color: Color) -> void:
	var rows := int(ceil(radius / PX))
	for row: int in range(-rows, rows):
		var mid := (row + 0.5) * PX
		if absf(mid) >= radius:
			continue
		var half := floorf(sqrt(radius * radius - mid * mid) / PX) * PX
		canvas.draw_rect(Rect2(center.x - half, center.y + row * PX, half * 2.0, PX), color)


func _draw_rim(canvas: Control) -> void:
	var radius := VIEW_RADII[difficulty]
	_pixel_disc(canvas, EYEPIECE_CENTER + Vector2(-PX, -PX), radius + RIM_WIDTH, RIM_LIGHT)
	_pixel_disc(canvas, EYEPIECE_CENTER, radius + RIM_WIDTH, RIM_COLOR)


## The slide under the lens: specks and bacteria, snapped to the pixel grid.
func _draw_view() -> void:
	var radius := VIEW_RADII[difficulty]
	var c := EYEPIECE_CENTER
	for speck: Vector2 in _specks:
		var at := _snap(c + speck - camera)
		if at.distance_to(c) < radius + PX:
			_view.draw_rect(Rect2(at, Vector2(PX, PX)), SPECK_COLOR)
	for bug: Dictionary in _bugs:
		var screen: Vector2 = c + (bug["pos"] - camera)
		if screen.distance_to(c) < radius + 50.0:
			_draw_bug(_view, screen, bug["kind"], bug["rot"])


## Draws a bacterium centred at `at`. Pixel art does not rotate freely, so
## `rot` picks a mirror image (and stands rods on end).
func _draw_bug(canvas: Control, at: Vector2, kind: String, rot: float) -> void:
	var texture: Texture2D = BUG_TEXTURES[kind]
	var size := texture.get_size() * PX
	if kind == "rod" and absf(rot) > 0.5:
		canvas.draw_set_transform(_snap(at), PI * 0.5, Vector2.ONE)
		canvas.draw_texture_rect(texture, Rect2(_snap(-size * 0.5), size), false)
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var rect := Rect2(_snap(at - size * 0.5), size)
	if rot < 0.0 and kind != "aggie":
		rect = Rect2(rect.position + Vector2(size.x, 0.0), Vector2(-size.x, size.y))
	canvas.draw_texture_rect(texture, rect, false)


## The crosshair and the lock ring: dark ink, gold while locking on, red after
## a miss.
func _draw_reticle() -> void:
	var radius := VIEW_RADII[difficulty]
	var c := EYEPIECE_CENTER
	var color := INK
	if _miss_flash > 0.0:
		color = MISS_COLOR
	elif _lock_time > 0.0 or (_ended and is_target_in_crosshair()):
		color = LOCK_COLOR
	var half := Vector2(PX, PX) * 0.5
	for i: int in range(int(LOCK_RADIUS / PX) + 2, int(radius / PX) - 1):
		if i % 2 == 0:
			for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				_reticle.draw_rect(Rect2(c + direction * i * PX - half, Vector2(PX, PX)), color)
	var steps := 20
	for i: int in steps:
		if i % 2 == 0:
			var angle := TAU * i / steps
			var at := _snap(c + Vector2(cos(angle), sin(angle)) * LOCK_RADIUS - half)
			_reticle.draw_rect(Rect2(at, Vector2(PX, PX)), color)


## The slide map on the bench monitor: the slide, the view and where it is.
func _draw_minimap() -> void:
	var r := MINIMAP_RECT
	var scale := minf(r.size.x / _slide_size.x, r.size.y / _slide_size.y)
	var map_size := _snap(_slide_size * scale)
	var map := Rect2(_snap(r.position + (r.size - map_size) * 0.5), map_size)
	var edge := Color("#6f9c86")
	_minimap.draw_rect(map, Color("#1c3a2c"))
	for gx: int in range(1, 4):
		for gy: int in range(1, 3):
			var dot := _snap(map.position + map.size * Vector2(gx / 4.0, gy / 3.0))
			_minimap.draw_rect(Rect2(dot, Vector2(PX, PX)), Color("#2f5a44"))
	_minimap.draw_rect(Rect2(map.position, Vector2(map.size.x, PX)), edge)
	_minimap.draw_rect(Rect2(map.position + Vector2(0.0, map.size.y - PX), Vector2(map.size.x, PX)), edge)
	_minimap.draw_rect(Rect2(map.position, Vector2(PX, map.size.y)), edge)
	_minimap.draw_rect(Rect2(map.position + Vector2(map.size.x - PX, 0.0), Vector2(PX, map.size.y)), edge)
	var here := map.position + camera * scale
	var half := Vector2(PX, PX) * 0.5
	var view_radius := maxf(VIEW_RADII[difficulty] * scale, PX * 3.0)
	var steps := 16
	for i: int in steps:
		if i % 2 == 0:
			var angle := TAU * i / steps
			var at := _snap(here + Vector2(cos(angle), sin(angle)) * view_radius - half)
			if map.grow(-PX).encloses(Rect2(at, Vector2(PX, PX))):
				_minimap.draw_rect(Rect2(at, Vector2(PX, PX)), Color("#ffd166"))
	_minimap.draw_rect(Rect2(_snap(here - half), Vector2(PX, PX)), Color("#ffd166"))
	# A glint across the glass, so it reads as a screen.
	var glare := Color(1.0, 1.0, 1.0, 0.12)
	for i: int in 6:
		_minimap.draw_rect(Rect2(r.position + Vector2(PX * (2 + i), PX * (7 - i)), Vector2(PX, PX)), glare)
		_minimap.draw_rect(Rect2(r.position + Vector2(PX * (5 + i), PX * (7 - i)), Vector2(PX, PX)), glare)


func _snap(at: Vector2) -> Vector2:
	return (at / PX).round() * PX
