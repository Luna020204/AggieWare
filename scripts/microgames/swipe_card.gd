extends Control

## SCRUM-72: Swipe Card (outside / travel, Rush Hour).
##
## Drag the Aggie card through the scanner in one smooth left-to-right swipe.
## Mouse and click only. A bad swipe resets the card so you can try again
## until time runs out.
##
## Difficulty (0..2):
##   less time (8 / 7 / 6 s), a narrower "not too fast, not too slow" speed
##   window, and on HARD the scanner slides up and down.

signal round_completed(success: bool)
signal time_changed(seconds_left: float, round_seconds: float)

@export_range(0, 2, 1) var difficulty: int = 0
@export var show_internal_timer: bool = true

const DURATIONS: Array[float] = [8.0, 7.0, 6.0]
## Accepted swipe speed through the scanner, in pixels per real second.
const SPEED_MIN: Array[float] = [200.0, 450.0, 550.0]
const SPEED_MAX: Array[float] = [4000.0, 1800.0, 1400.0]
const ALIGN_TOLERANCE: Array[float] = [70.0, 55.0, 45.0]
const SCANNER_RECT := Rect2(560.0, 250.0, 160.0, 260.0)
const SLOT_HEIGHT := 18.0
const CARD_SIZE := Vector2(190.0, 120.0)
const CARD_HOME := Vector2(150.0, 320.0)
const SCANNER_TRAVEL := 120.0
const METER_MAX_SPEED := 3000.0

var _seconds_left := 0.0
var _ended := false
var _elapsed := 0.0
var _dragging := false
var _drag_offset := Vector2.ZERO
var _entered_usec := -1
var _entered := false
var _aligned := true
var _last_speed := -1.0

var _card: Panel
var _scanner: Panel
var _slot: ColorRect
var _light: Label
var _timer_label: Label
var _status_label: Label
var _meter: Control


func get_round_seconds() -> float:
	return DURATIONS[clampi(difficulty, 0, 2)]


func get_speed_window() -> Vector2:
	return Vector2(SPEED_MIN[difficulty], SPEED_MAX[difficulty])


func _ready() -> void:
	difficulty = clampi(difficulty, 0, 2)
	_build_ui()
	_start_round()


func _process(delta: float) -> void:
	if _ended:
		return
	_elapsed += delta
	_seconds_left = maxf(0.0, _seconds_left - delta)
	_timer_label.text = "TIME  %.1f s" % _seconds_left
	time_changed.emit(_seconds_left, DURATIONS[difficulty])
	if difficulty >= 2:
		_scanner.position.y = SCANNER_RECT.position.y + sin(_elapsed * 2.4) * SCANNER_TRAVEL
	if _seconds_left <= 0.0:
		_finish_round(false, "Time's up — the door stayed locked.")


func _input(event: InputEvent) -> void:
	if not _dragging or _ended:
		return
	if event is InputEventMouseMotion:
		drag_to(event.position, Time.get_ticks_usec())
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		release()
		get_viewport().set_input_as_handled()


func _on_card_input(event: InputEvent) -> void:
	if _ended:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		begin_drag(_card.position + event.position)
		accept_event()


## Public so tests can drive a swipe with exact timestamps.
func begin_drag(at: Vector2) -> void:
	if _ended:
		return
	_dragging = true
	_drag_offset = at - _card.position
	_entered = false
	_entered_usec = -1
	_aligned = true


func drag_to(at: Vector2, usec: int) -> void:
	if not _dragging or _ended:
		return
	_card.position = at - _drag_offset
	var center := _card.position + CARD_SIZE * 0.5
	var scanner_left := _scanner.position.x
	var scanner_right := _scanner.position.x + _scanner.size.x
	var slot_y := _scanner.position.y + _scanner.size.y * 0.5
	if not _entered and center.x >= scanner_left:
		_entered = true
		_entered_usec = usec
	if _entered and center.x <= scanner_right and absf(center.y - slot_y) > ALIGN_TOLERANCE[difficulty]:
		_aligned = false
	if _entered and center.x > scanner_right:
		var seconds := maxf((usec - _entered_usec) / 1000000.0, 0.0001)
		_judge_swipe((scanner_right - scanner_left) / seconds)


func release() -> void:
	if not _dragging:
		return
	_dragging = false
	if not _ended and _entered:
		_reject("Keep dragging all the way through the scanner!")
	elif not _ended:
		_reset_card()


func _judge_swipe(speed: float) -> void:
	_dragging = false
	_last_speed = speed
	_meter.queue_redraw()
	if not _aligned:
		_reject("Missed the slot — line the card up with the scanner.")
	elif speed < SPEED_MIN[difficulty]:
		_reject("▼ Too slow — swipe faster.")
	elif speed > SPEED_MAX[difficulty]:
		_reject("▲ Too fast — swipe slower.")
	else:
		_light.text = "✔"
		_light.add_theme_color_override("font_color", Color("#73e6a8"))
		_card.position.x = _scanner.position.x + _scanner.size.x + 40.0
		_finish_round(true, "✔ Access granted — you're in!")


func _reject(message: String) -> void:
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", Color("#ffb38a"))
	_light.text = "✖"
	_light.add_theme_color_override("font_color", Color("#ff9e9e"))
	_reset_card()


func _reset_card() -> void:
	_dragging = false
	_entered = false
	_card.position = CARD_HOME


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("#13202b")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var sidewalk := ColorRect.new()
	sidewalk.color = Color("#1d2f3d")
	sidewalk.position = Vector2(0.0, 600.0)
	sidewalk.size = Vector2(1280.0, 120.0)
	sidewalk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sidewalk)

	var title := Label.new()
	title.text = "SWIPE CARD"
	title.position = Vector2(48, 35)
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#f5f7ff"))
	add_child(title)

	var instruction := Label.new()
	instruction.text = "One smooth swipe through the scanner."
	instruction.position = Vector2(48, 92)
	instruction.add_theme_font_size_override("font_size", 20)
	instruction.add_theme_color_override("font_color", Color("#b8d4e6"))
	add_child(instruction)

	_timer_label = Label.new()
	_timer_label.position = Vector2(48, 132)
	_timer_label.add_theme_font_size_override("font_size", 22)
	_timer_label.add_theme_color_override("font_color", Color("#ffd166"))
	_timer_label.visible = show_internal_timer
	add_child(_timer_label)

	_scanner = Panel.new()
	_scanner.position = SCANNER_RECT.position
	_scanner.size = SCANNER_RECT.size
	_scanner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scanner.add_theme_stylebox_override("panel", _box(Color("#2b3440"), Color("#8aa0b8")))
	add_child(_scanner)
	_slot = ColorRect.new()
	_slot.color = Color("#0a0d12")
	_slot.position = Vector2(-20.0, SCANNER_RECT.size.y * 0.5 - SLOT_HEIGHT * 0.5)
	_slot.size = Vector2(SCANNER_RECT.size.x + 40.0, SLOT_HEIGHT)
	_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scanner.add_child(_slot)
	_light = Label.new()
	_light.text = "●"
	_light.position = Vector2(64.0, 20.0)
	_light.add_theme_font_size_override("font_size", 30)
	_light.add_theme_color_override("font_color", Color("#ffd166"))
	_scanner.add_child(_light)
	var arrow := Label.new()
	arrow.text = "SWIPE  →"
	arrow.position = Vector2(30.0, SCANNER_RECT.size.y - 60.0)
	arrow.add_theme_font_size_override("font_size", 20)
	arrow.add_theme_color_override("font_color", Color("#c8d6e5"))
	_scanner.add_child(arrow)

	_card = Panel.new()
	_card.size = CARD_SIZE
	_card.mouse_default_cursor_shape = Control.CURSOR_DRAG
	_card.add_theme_stylebox_override("panel", _box(Color("#1f4e8c"), Color("#ffd166")))
	_card.gui_input.connect(_on_card_input)
	add_child(_card)
	var card_text := Label.new()
	card_text.text = "AGGIE CARD\nUC DAVIS"
	card_text.position = Vector2(18.0, 22.0)
	card_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_text.add_theme_font_size_override("font_size", 20)
	card_text.add_theme_color_override("font_color", Color("#ffd166"))
	_card.add_child(card_text)
	var stripe := ColorRect.new()
	stripe.color = Color("#0a0d12")
	stripe.position = Vector2(0.0, CARD_SIZE.y - 30.0)
	stripe.size = Vector2(CARD_SIZE.x, 14.0)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(stripe)

	_meter = Control.new()
	_meter.position = Vector2(820.0, 300.0)
	_meter.size = Vector2(400.0, 90.0)
	_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter.draw.connect(_draw_meter)
	add_child(_meter)

	_status_label = Label.new()
	_status_label.position = Vector2(48, 540)
	_status_label.size = Vector2(1180, 48)
	_status_label.add_theme_font_size_override("font_size", 22)
	add_child(_status_label)


func _draw_meter() -> void:
	var font := get_theme_default_font()
	_meter.draw_string(font, Vector2(0.0, 18.0), "SWIPE SPEED", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#b8d4e6"))
	var bar := Rect2(0.0, 30.0, _meter.size.x, 26.0)
	_meter.draw_rect(bar, Color("#0e161e"))
	var low := clampf(SPEED_MIN[difficulty] / METER_MAX_SPEED, 0.0, 1.0) * bar.size.x
	var high := clampf(SPEED_MAX[difficulty] / METER_MAX_SPEED, 0.0, 1.0) * bar.size.x
	# The OK band is striped as well as green so it reads without colour.
	_meter.draw_rect(Rect2(low, bar.position.y, high - low, bar.size.y), Color("#2f7d57"))
	var x := low
	while x < high:
		_meter.draw_line(Vector2(x, bar.position.y), Vector2(minf(x + 10.0, high), bar.end.y), Color("#73e6a8"), 2.0)
		x += 14.0
	_meter.draw_rect(bar, Color("#8aa0b8"), false, 2.0)
	_meter.draw_string(font, Vector2(0.0, 80.0), "slow", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#8aa0b8"))
	_meter.draw_string(font, Vector2(bar.size.x - 34.0, 80.0), "fast", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#8aa0b8"))
	if _last_speed >= 0.0:
		var px := clampf(_last_speed / METER_MAX_SPEED, 0.0, 1.0) * bar.size.x
		_meter.draw_line(Vector2(px, bar.position.y - 6.0), Vector2(px, bar.end.y + 6.0), Color("#ffffff"), 4.0)


func _start_round() -> void:
	_ended = false
	_elapsed = 0.0
	_seconds_left = DURATIONS[difficulty]
	_last_speed = -1.0
	_scanner.position = SCANNER_RECT.position
	_reset_card()
	_status_label.text = "Grab the card and swipe it left → right through the slot."
	_status_label.add_theme_color_override("font_color", Color("#b8d4e6"))
	time_changed.emit(_seconds_left, DURATIONS[difficulty])


func _finish_round(success: bool, message: String) -> void:
	if _ended:
		return
	_ended = true
	_dragging = false
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", Color("#73e6a8") if success else Color("#ff9e9e"))
	round_completed.emit(success)


func _box(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	return style
