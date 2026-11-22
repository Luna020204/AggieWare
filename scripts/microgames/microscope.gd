extends Control

## SCRUM-84: Microscope (Lecture Hall, science).
##
## Pan the microscope with UP / LEFT / DOWN / RIGHT to find the new Aggie
## bacteria (gold, with an "A" and two horns) on the slide. Hold it in the
## crosshair for a moment, or press ACTION while it is in the crosshair.
## A mini-map shows where you are on the slide.
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
const MINIMAP_RECT := Rect2(830.0, 410.0, 360.0, 230.0)
const BUG_RADIUS := 26.0
## Decoy kinds; "gold" (same colour, no A, no horns) only appears from NORMAL.
const DECOY_KINDS: Array[String] = ["blue", "rod", "gold"]

var camera := Vector2.ZERO
var _seconds_left := 0.0
var _ended := false
var _lock_time := 0.0
var _slide_size := Vector2.ZERO
var _target_pos := Vector2.ZERO
var _bugs: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()

var _view: Control
var _overlay: Control
var _minimap: Control
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
	_timer_label.text = "TIME  %.1f s" % _seconds_left
	time_changed.emit(_seconds_left, DURATIONS[difficulty])
	var direction := Vector2(
		InputActions.get_strength(InputActions.ACTION_RIGHT) - InputActions.get_strength(InputActions.ACTION_LEFT),
		InputActions.get_strength(InputActions.ACTION_DOWN) - InputActions.get_strength(InputActions.ACTION_UP)
	)
	move_camera(direction, delta)
	if InputActions.is_just_pressed(InputActions.ACTION_CONFIRM):
		confirm()
	if _ended:
		return
	if is_target_in_crosshair():
		_lock_time += delta
		_status_label.text = "Focusing…"
		if _lock_time >= LOCK_SECONDS:
			_finish_round(true, "✔ Found the Aggie bacteria!")
			return
	else:
		_lock_time = 0.0
	if _seconds_left <= 0.0:
		_finish_round(false, "✖ Time's up — the Aggie bacteria got away.")


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


## ACTION: confirm immediately if the target is in the crosshair.
func confirm() -> void:
	if _ended:
		return
	if is_target_in_crosshair():
		_finish_round(true, "✔ Found the Aggie bacteria!")
	else:
		_status_label.text = "Not that one — look for the gold one with an A."


func _start_round() -> void:
	_ended = false
	_lock_time = 0.0
	_seconds_left = DURATIONS[difficulty]
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
	_status_label.text = "Find the gold bacteria with an A and horns."
	_status_label.add_theme_color_override("font_color", Color("#c9e6d4"))
	_view.queue_redraw()
	_minimap.queue_redraw()
	time_changed.emit(_seconds_left, DURATIONS[difficulty])


func _finish_round(success: bool, message: String) -> void:
	if _ended:
		return
	_ended = true
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", Color("#73e6a8") if success else Color("#ff9e9e"))
	_overlay.queue_redraw()
	round_completed.emit(success)


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("#10201a")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var title := Label.new()
	title.text = "MICROSCOPE"
	title.position = Vector2(48, 35)
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#f5f7ff"))
	add_child(title)

	var instruction := Label.new()
	instruction.text = "Arrow keys to pan. Center the Aggie bacteria."
	instruction.position = Vector2(48, 92)
	instruction.add_theme_font_size_override("font_size", 20)
	instruction.add_theme_color_override("font_color", Color("#c9e6d4"))
	add_child(instruction)

	_timer_label = Label.new()
	_timer_label.position = Vector2(48, 132)
	_timer_label.add_theme_font_size_override("font_size", 22)
	_timer_label.add_theme_color_override("font_color", Color("#ffd166"))
	_timer_label.visible = show_internal_timer
	add_child(_timer_label)

	_view = Control.new()
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.draw.connect(_draw_view)
	add_child(_view)

	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)

	var find_label := Label.new()
	find_label.text = "FIND THIS"
	find_label.position = Vector2(830.0, 170.0)
	find_label.add_theme_font_size_override("font_size", 20)
	find_label.add_theme_color_override("font_color", Color("#c9e6d4"))
	add_child(find_label)

	var map_label := Label.new()
	map_label.text = "SLIDE MAP"
	map_label.position = Vector2(830.0, 378.0)
	map_label.add_theme_font_size_override("font_size", 18)
	map_label.add_theme_color_override("font_color", Color("#c9e6d4"))
	add_child(map_label)

	_minimap = Control.new()
	_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_minimap.draw.connect(_draw_minimap)
	add_child(_minimap)

	_status_label = Label.new()
	_status_label.position = Vector2(48, 615)
	_status_label.size = Vector2(1180, 40)
	_status_label.add_theme_font_size_override("font_size", 22)
	add_child(_status_label)


func _draw_view() -> void:
	var radius := VIEW_RADII[difficulty]
	var c := EYEPIECE_CENTER
	_view.draw_circle(c, radius, Color("#e9f2d8"))
	for bug: Dictionary in _bugs:
		var screen: Vector2 = c + (bug["pos"] - camera)
		if screen.distance_to(c) < radius + 10.0:
			_draw_bug(_view, screen, bug["kind"], bug["rot"], 1.0)


func _draw_overlay() -> void:
	var radius := VIEW_RADII[difficulty]
	var c := EYEPIECE_CENTER
	# Mask everything outside the eyepiece with a thick ring.
	# (bugs are drawn at most ~44 px past the edge, so 48 px is enough).
	_overlay.draw_arc(c, radius + 24.0, 0.0, TAU, 96, Color("#10201a"), 48.0)
	_overlay.draw_arc(c, radius, 0.0, TAU, 96, Color("#3b5c4c"), 8.0)
	var ink := Color("#2b3d34")
	_overlay.draw_arc(c, LOCK_RADIUS, 0.0, TAU, 48, ink, 3.0)
	_overlay.draw_line(c + Vector2(-radius, 0.0), c + Vector2(-LOCK_RADIUS, 0.0), ink, 2.0)
	_overlay.draw_line(c + Vector2(LOCK_RADIUS, 0.0), c + Vector2(radius, 0.0), ink, 2.0)
	_overlay.draw_line(c + Vector2(0.0, -radius), c + Vector2(0.0, -LOCK_RADIUS), ink, 2.0)
	_overlay.draw_line(c + Vector2(0.0, LOCK_RADIUS), c + Vector2(0.0, radius), ink, 2.0)
	# Reference card.
	var card := Rect2(830.0, 200.0, 160.0, 150.0)
	_overlay.draw_rect(card, Color("#e9f2d8"))
	_overlay.draw_rect(card, Color("#3b5c4c"), false, 3.0)
	_draw_bug(_overlay, card.get_center(), "aggie", 0.0, 1.6)


func _draw_minimap() -> void:
	var r := MINIMAP_RECT
	var scale := minf(r.size.x / _slide_size.x, r.size.y / _slide_size.y)
	var map := Rect2(r.position, _slide_size * scale)
	_minimap.draw_rect(map, Color("#1c3328"))
	_minimap.draw_rect(map, Color("#6f9c86"), false, 2.0)
	var view_radius := VIEW_RADII[difficulty] * scale
	_minimap.draw_arc(map.position + camera * scale, view_radius, 0.0, TAU, 32, Color("#ffd166"), 2.0)
	_minimap.draw_circle(map.position + camera * scale, 3.0, Color("#ffd166"))


func _draw_bug(canvas: Control, at: Vector2, kind: String, rot: float, size: float) -> void:
	canvas.draw_set_transform(at, rot, Vector2(size, size))
	match kind:
		"rod":
			canvas.draw_rect(Rect2(-30.0, -10.0, 60.0, 20.0), Color("#7fb069"))
			canvas.draw_rect(Rect2(-30.0, -10.0, 60.0, 20.0), Color("#355e3b"), false, 2.0)
		"blue":
			_blob(canvas, Color("#7aa7d8"), Color("#2c4f7c"))
			canvas.draw_circle(Vector2(-8.0, -4.0), 5.0, Color("#2c4f7c"))
			canvas.draw_circle(Vector2(9.0, 5.0), 4.0, Color("#2c4f7c"))
		"gold":
			_blob(canvas, Color("#e8b84a"), Color("#8a5f12"))
			canvas.draw_circle(Vector2(0.0, 0.0), 6.0, Color("#8a5f12"))
		"aggie":
			for side: float in [-1.0, 1.0]:
				canvas.draw_colored_polygon(PackedVector2Array([Vector2(12.0 * side, -14.0), Vector2(26.0 * side, -32.0), Vector2(4.0 * side, -18.0)]), Color("#8a5f12"))
			_blob(canvas, Color("#e8b84a"), Color("#8a5f12"))
			canvas.draw_string(get_theme_default_font(), Vector2(-9.0, 9.0), "A", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#1f3d7a"))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _blob(canvas: Control, fill: Color, edge: Color) -> void:
	var points := PackedVector2Array()
	for i: int in 20:
		var a := TAU * i / 20.0
		points.append(Vector2(cos(a) * BUG_RADIUS * 1.15, sin(a) * BUG_RADIUS * 0.85))
	canvas.draw_colored_polygon(points, fill)
	points.append(points[0])
	canvas.draw_polyline(points, edge, 2.0)
