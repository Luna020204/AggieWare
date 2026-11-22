extends Control

## SCRUM-72: Swipe Card (Rush Hour).
##
## Pay with Aggie Cash at the Peet's Coffee counter on campus: pull your Aggie
## Card out of a wallet full of cards and drag it through the card reader in
## one smooth left-to-right swipe. Mouse and click only. Any card can be
## pulled, but only the Aggie Card is accepted. A bad swipe or the wrong card
## goes back into the wallet so you can try again until time runs out.
##
## The round opens outside the Peet's on campus: the title and instruction show
## in the sky while a student walks up the steps and in through the door, then
## the scene fades to the counter and the timer starts. A click skips this.
## Results pop up in the middle of the screen and fade.
##
## Art is pixel art drawn at 1/5 scale (tools/art/gen_swipe_card_art.py) and
## shown at 5x with nearest filtering. Text uses the AggiePixel font
## (tools/art/gen_pixel_font.py), which is 7 px tall, so font sizes are
## multiples of 7.
##
## Difficulty (0..2):
##   less time (9 / 8 / 7 s), more cards in the wallet (2 / 3 / 4, with a
##   look-alike license on HARD), a narrower "not too fast, not too slow"
##   speed window, and on HARD the reader slides up and down.

signal round_completed(success: bool)
signal time_changed(seconds_left: float, round_seconds: float)

@export_range(0, 2, 1) var difficulty: int = 0
@export var show_internal_timer: bool = true

const DURATIONS: Array[float] = [9.0, 8.0, 7.0]
## The walk-in intro (WalkInIntro): its length, the student's feet from below
## the steps to the door, and the door, all in exterior-art pixels.
const INTRO_SECONDS := WalkInIntro.DURATION
const WALK_PATH: Array[Vector2] = [Vector2(130, 150), Vector2(150, 126), Vector2(211, 118)]
const WALKER_SIZE := Vector2(16.0, 30.0)
const DOOR_RECT := Rect2(196.0, 74.0, 30.0, 44.0)
## Accepted swipe speed through the scanner, in pixels per real second.
const SPEED_MIN: Array[float] = [200.0, 450.0, 550.0]
const SPEED_MAX: Array[float] = [4000.0, 1800.0, 1400.0]
const ALIGN_TOLERANCE: Array[float] = [70.0, 55.0, 45.0]
## Cards in the wallet besides the Aggie Card, per difficulty.
const DECOYS := [["credit"], ["credit", "rewards"], ["credit", "rewards", "license"]]
const ART := "res://assets/art/microgames/swipe_card/"
const BACKGROUND_TEXTURE := preload(ART + "coffee_counter_bg.png")
const EXTERIOR_TEXTURE := preload(ART + "peets_exterior.png")
const DOOR_OPEN_TEXTURE := preload(ART + "peets_door_open.png")
const WALKER_TEXTURES := [
	preload(ART + "student_walk_0.png"),
	preload(ART + "student_walk_1.png"),
	preload(ART + "student_walk_2.png"),
]
const READER_TEXTURE := preload(ART + "card_reader.png")
const WALLET_BACK_TEXTURE := preload(ART + "wallet_back.png")
const WALLET_FRONT_TEXTURE := preload(ART + "wallet_front.png")
const CARD_TEXTURES := {
	"aggie": preload(ART + "aggie_card.png"),
	"credit": preload(ART + "credit_card.png"),
	"rewards": preload(ART + "rewards_card.png"),
	"license": preload(ART + "license_card.png"),
}
const PX := 5.0
## The reader art is 32x52 with its slot on rows 24-26.
const SCANNER_RECT := Rect2(560.0, 250.0, 160.0, 260.0)
const SLOT_TOP := 120.0
const SLOT_HEIGHT := 15.0
## The card art is 48x30.
const CARD_SIZE := Vector2(240.0, 150.0)
## The open wallet: a 60x40 back drawn behind the cards and a 60x30 pocket
## drawn in front of them, 10 px below the back's top edge.
const WALLET_POS := Vector2(40.0, 380.0)
const WALLET_SLOTS := 4
const SCANNER_TRAVEL := 120.0
const METER_MAX_SPEED := 3000.0

var _seconds_left := 0.0
var _intro_left := 0.0
var _ended := false
var _elapsed := 0.0
var _dragging := false
var _drag_offset := Vector2.ZERO
var _entered_usec := -1
var _entered := false
var _aligned := true
var _last_speed := -1.0

## The Aggie Card, wherever it sits in the wallet this round.
var _card: TextureRect
var _cards: Array[TextureRect] = []
var _held: TextureRect
var _scanner: TextureRect
var _slot: ColorRect
var _light: Label
var _timer_label: Label
## Shared text layer: intro title, result pops and the dim behind them.
var _overlay: MicrogameOverlay
## The intro's title and instruction (the overlay's).
var _intro: Control
var _walk_in: WalkInIntro
## The walk-in's outside scene and student, for tests.
var _exterior: Control
var _walker: TextureRect
## Result messages (the overlay's pop label).
var _status_label: Label
var _meter: Control


func get_round_seconds() -> float:
	return DURATIONS[clampi(difficulty, 0, 2)]


## Time before the round timer starts, for tools that wait for a timeout.
func get_intro_seconds() -> float:
	return INTRO_SECONDS


func get_speed_window() -> Vector2:
	return Vector2(SPEED_MIN[difficulty], SPEED_MAX[difficulty])


## Where a card rests in the wallet.
func card_home(card: TextureRect) -> Vector2:
	return card.get_meta("home")


func card_id(card: TextureRect) -> String:
	return card.get_meta("id")


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
	_build_ui()
	_start_round()


func _process(delta: float) -> void:
	if _ended:
		return
	if _intro_left > 0.0:
		_intro_left = maxf(0.0, _intro_left - delta)
		_update_intro()
		return
	_elapsed += delta
	_seconds_left = maxf(0.0, _seconds_left - delta)
	_timer_label.text = "TIME %.1f" % _seconds_left
	time_changed.emit(_seconds_left, DURATIONS[difficulty])
	if difficulty >= 2:
		_scanner.position.y = SCANNER_RECT.position.y + sin(_elapsed * 2.4) * SCANNER_TRAVEL
	if _seconds_left <= 0.0:
		_finish_round(false, "TIME'S UP!\nThe line moved on without you.")


func _input(event: InputEvent) -> void:
	if _intro_left > 0.0 and not _ended:
		if event is InputEventMouseButton and event.pressed:
			skip_intro()
			get_viewport().set_input_as_handled()
		return
	if not _dragging or _ended:
		return
	if event is InputEventMouseMotion:
		drag_to(event.position, Time.get_ticks_usec())
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		release()
		get_viewport().set_input_as_handled()


func _on_card_input(event: InputEvent, card: TextureRect) -> void:
	if _ended or _dragging or _intro_left > 0.0:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		begin_drag(card.position + event.position, card)
		accept_event()


## Public so tests can drive a swipe with exact timestamps. Defaults to the
## Aggie Card.
func begin_drag(at: Vector2, card: TextureRect = null) -> void:
	if _ended:
		return
	_held = card if card != null else _card
	_held.z_index = 2
	_dragging = true
	_drag_offset = at - _held.position
	_entered = false
	_entered_usec = -1
	_aligned = true


func drag_to(at: Vector2, usec: int) -> void:
	if not _dragging or _ended:
		return
	_held.position = at - _drag_offset
	var center := _held.position + CARD_SIZE * 0.5
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
		_reject("Keep dragging all the way through!")
	elif not _ended:
		_reset_card()


func _judge_swipe(speed: float) -> void:
	_dragging = false
	_last_speed = speed
	_meter.queue_redraw()
	if not _aligned:
		_reject("Missed the slot!")
	elif speed < SPEED_MIN[difficulty]:
		_reject("▼ Too slow!")
	elif speed > SPEED_MAX[difficulty]:
		_reject("▲ Too fast!")
	elif _held != _card:
		_reject("✗ Card declined!\nThat's not your Aggie Card.")
	else:
		_light.text = "✓"
		_light.add_theme_color_override("font_color", Color("#73e6a8"))
		_held.position.x = _scanner.position.x + _scanner.size.x + 40.0
		_finish_round(true, "✓ Aggie Cash accepted!\nEnjoy your coffee!")


func _reject(message: String) -> void:
	_overlay.pop(message, Color("#ffb38a"), 28)
	_light.text = "✗"
	_light.add_theme_color_override("font_color", Color("#ff9e9e"))
	_reset_card()


## Puts the held card back in its wallet slot.
func _reset_card() -> void:
	_dragging = false
	_entered = false
	if _held != null:
		_held.position = card_home(_held)
		_held.z_index = 0
		_held = null


func _wallet_slot(slot: int) -> Vector2:
	return WALLET_POS + Vector2(4.0 + 2.0 * slot, -14.0 + 6.0 * slot) * PX


func _build_ui() -> void:
	# Pixel art stays crisp only with nearest filtering; children inherit it.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	PixelText.apply_theme(self)

	add_child(_pixel_rect(BACKGROUND_TEXTURE, Vector2.ZERO, Vector2(1280.0, 720.0)))

	_scanner = _pixel_rect(READER_TEXTURE, SCANNER_RECT.position, SCANNER_RECT.size)
	add_child(_scanner)
	# The art already has the slot; this extends it past both sides of the reader.
	_slot = ColorRect.new()
	_slot.color = Color("#0a0d12")
	_slot.position = Vector2(-20.0, SLOT_TOP)
	_slot.size = Vector2(SCANNER_RECT.size.x + 40.0, SLOT_HEIGHT)
	_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scanner.add_child(_slot)
	_light = Label.new()
	_light.text = "●"
	_light.position = Vector2(62.0, 18.0)
	_light.add_theme_font_size_override("font_size", 28)
	_light.add_theme_color_override("font_color", Color("#ffd166"))
	_scanner.add_child(_light)
	var arrow := Label.new()
	arrow.text = "SWIPE →"
	arrow.position = Vector2(20.0, -34.0)
	arrow.add_theme_font_size_override("font_size", 21)
	arrow.add_theme_color_override("font_color", Color("#1e1d22"))
	_scanner.add_child(arrow)

	# Wallet: back, then the cards from the back slot forward, then the pocket.
	add_child(_pixel_rect(WALLET_BACK_TEXTURE, WALLET_POS, Vector2(60.0, 40.0) * PX))
	for i: int in DECOYS[difficulty].size() + 1:
		var card := _pixel_rect(null, Vector2.ZERO, CARD_SIZE)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_default_cursor_shape = Control.CURSOR_DRAG
		card.gui_input.connect(_on_card_input.bind(card))
		add_child(card)
		_cards.append(card)
	var pocket := _pixel_rect(WALLET_FRONT_TEXTURE, WALLET_POS + Vector2(0.0, 10.0 * PX), Vector2(60.0, 30.0) * PX)
	# The pocket hides the lower part of each card, and so blocks clicks there.
	pocket.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(pocket)

	# Top left: the timer, with the swipe speed meter under it.
	_timer_label = PixelText.label(28, Color("#ffd166"))
	_timer_label.position = Vector2(32, 24)
	_timer_label.visible = show_internal_timer
	add_child(_timer_label)
	_meter = Control.new()
	_meter.position = Vector2(32.0, 70.0)
	_meter.size = Vector2(400.0, 90.0)
	_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter.draw.connect(_draw_meter)
	add_child(_meter)

	# The intro's outside scene, over everything until the fade.
	_walk_in = WalkInIntro.new()
	add_child(_walk_in)
	_walk_in.build(EXTERIOR_TEXTURE, DOOR_OPEN_TEXTURE, DOOR_RECT, WALKER_TEXTURES, WALKER_SIZE, WALK_PATH)
	_exterior = _walk_in.scene
	_walker = _walk_in.walker

	_overlay = MicrogameOverlay.new()
	add_child(_overlay)
	_overlay.build("SWIPE CARD", "Find your Aggie Card, then swipe!")
	_intro = _overlay.intro
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


func _draw_meter() -> void:
	var font := get_theme_default_font()
	PixelText.draw_shadowed(_meter, font, Vector2(0.0, 16.0), "SWIPE SPEED", 14, Color("#f5f7ff"))
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
	PixelText.draw_shadowed(_meter, font, Vector2(0.0, 80.0), "SLOW", 14, Color("#f5f7ff"))
	PixelText.draw_shadowed(_meter, font, Vector2(bar.size.x - 46.0, 80.0), "FAST", 14, Color("#f5f7ff"))
	if _last_speed >= 0.0:
		var px := clampf(_last_speed / METER_MAX_SPEED, 0.0, 1.0) * bar.size.x
		_meter.draw_line(Vector2(px, bar.position.y - 6.0), Vector2(px, bar.end.y + 6.0), Color("#ffffff"), 4.0)


func _start_round() -> void:
	_ended = false
	_elapsed = 0.0
	_seconds_left = DURATIONS[difficulty]
	_intro_left = INTRO_SECONDS
	_overlay.clear_pop()
	_last_speed = -1.0
	_scanner.position = SCANNER_RECT.position
	_held = null
	_reset_card()
	_deal_cards()
	_update_intro()
	_timer_label.text = "TIME %.1f" % _seconds_left
	time_changed.emit(_seconds_left, DURATIONS[difficulty])


## Shuffles the cards into the front-most wallet slots.
func _deal_cards() -> void:
	var ids: Array = ["aggie"] + DECOYS[difficulty]
	ids.shuffle()
	var first_slot := WALLET_SLOTS - ids.size()
	for i: int in ids.size():
		var card := _cards[i]
		card.texture = CARD_TEXTURES[ids[i]]
		card.set_meta("id", ids[i])
		card.set_meta("home", _wallet_slot(first_slot + i))
		card.position = card_home(card)
		card.z_index = 0
		if ids[i] == "aggie":
			_card = card


func _finish_round(success: bool, message: String) -> void:
	if _ended:
		return
	_ended = true
	_dragging = false
	_intro_left = 0.0
	_update_intro()
	_overlay.pop(message, Color("#73e6a8") if success else Color("#ff9e9e"), 42)
	round_completed.emit(success)
