extends Control

## SCRUM-23: Variable Not in Scope (Lecture Hall).
##
## A short C++ snippet on the student's laptop fails to compile because one
## variable was never declared. Click the quick-fix line that declares it
## before time runs out. Mouse and click only; no typing. A wrong click fails
## the round.
##
## Follows the AggieWare format standard: the round opens with the student
## walking into the lecture building while the title and instruction show
## (WalkInIntro; the timer waits, a click skips it), only the timer during
## play, and results as centred pops. The scene is pixel art drawn at 1/5
## scale (tools/art/gen_variable_scope_art.py) and shown at 5x; the code on
## the laptop is in AggieMono, a pixel font with lower case
## (tools/art/gen_mono_font.py), because `y` and `Y` must look different.
##
## Difficulty (0..2):
##   less time (9 / 7 / 5.5 s), more choices (2 / 3 / 4),
##   look-alike options (int Y = 5; / missing semicolon / itn typo),
##   and on HARD the choices shuffle positions while you read.

signal round_completed(success: bool)
signal time_changed(seconds_left: float, round_seconds: float)

@export_range(0, 2, 1) var difficulty: int = 0
@export var show_internal_timer: bool = true

const DURATIONS: Array[float] = [9.0, 7.0, 5.5]
const CHOICE_COUNTS: Array[int] = [2, 3, 4]
const SHUFFLE_INTERVAL := 1.6
## Each set is [first operand, second operand, result] variable names.
const NAME_SETS: Array = [
	["x", "y", "z"],
	["a", "b", "sum"],
	["width", "height", "area"],
	["count", "step", "total"],
	["i", "j", "k"],
	["base", "bonus", "score"],
]
const OPERATORS: Array[String] = ["+", "-", "*"]
## The walk-in intro reuses the lecture building from Stay Awake: the
## student's feet from the walkway to the entrance, and the doors.
const INTRO_SECONDS := WalkInIntro.DURATION
const WALK_PATH: Array[Vector2] = [Vector2(70, 150), Vector2(120, 134), Vector2(210, 122)]
const WALKER_SIZE := Vector2(16.0, 30.0)
const DOOR_RECT := Rect2(194.0, 84.0, 32.0, 38.0)
const BUILDING_TEXTURE := preload("res://assets/art/microgames/stay_awake/building_exterior.png")
const BUILDING_DOOR_TEXTURE := preload("res://assets/art/microgames/stay_awake/building_door_open.png")
const WALKER_TEXTURES := [
	preload("res://assets/art/microgames/swipe_card/student_walk_0.png"),
	preload("res://assets/art/microgames/swipe_card/student_walk_1.png"),
	preload("res://assets/art/microgames/swipe_card/student_walk_2.png"),
]
const SEAT_TEXTURE := preload("res://assets/art/microgames/variable_scope/lecture_seat.png")
const MONO := preload("res://assets/fonts/aggie_mono.fnt")
## AggieMono is 8 px tall; 24 shows it at 3x, 16 at 2x.
const CODE_SIZE := 24
const SMALL_SIZE := 16
const CHAR_WIDTH := 18.0  # one 6 px cell at 3x
const LINE_GAP := 6
## Where things sit on the laptop screen (see the art script's regions).
const TAB_POS := Vector2(166.0, 94.0)
const GUTTER_X := 167.0
const CODE_POS := Vector2(215.0, 138.0)
const TERMINAL_POS := Vector2(170.0, 470.0)
const CHOICE_X := 740.0
const CHOICE_TOP := 140.0
const CHOICE_GAP := 72.0
const CHOICE_SIZE := Vector2(365.0, 60.0)
const PX := 5.0
const KEYWORD := Color("#c792ea")
const CODE_TEXT := Color("#d8dee9")
const DIM_TEXT := Color("#5c6370")
const ERROR_TEXT := Color("#ff6b7a")
const GOOD_TEXT := Color("#73e6a8")

var _seconds_left := 0.0
var _intro_left := 0.0
var _ended := false
var _shuffle_clock := 0.0
var _missing := "y"
var _declared := "x"
var _result := "z"
var _value := 5
var _declared_value := 3
var _expression := "x + y"
var _correct_line := ""
var _fixed := false
var _choice_buttons: Array[Button] = []
var _rng := RandomNumberGenerator.new()

var _code_label: RichTextLabel
var _gutter_label: Label
## The compiler output in the laptop's terminal panel.
var _error_label: Label
var _squiggle: Control
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
	if difficulty >= 2:
		_shuffle_clock += delta
		if _shuffle_clock >= SHUFFLE_INTERVAL:
			_shuffle_clock = 0.0
			_shuffle_choices()
	if _seconds_left <= 0.0:
		_show_needed_line()
		_finish_round(false, "TIME'S UP! STILL BROKEN.")


func _input(event: InputEvent) -> void:
	if _intro_left > 0.0 and not _ended and event is InputEventMouseButton and event.pressed:
		skip_intro()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	# Pixel art stays crisp only with nearest filtering; children inherit it.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	PixelText.apply_theme(self)
	var mono: FontFile = MONO
	mono.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY

	var seat := TextureRect.new()
	seat.texture = SEAT_TEXTURE
	seat.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	seat.stretch_mode = TextureRect.STRETCH_SCALE
	seat.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	seat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(seat)

	# The editor on the laptop: tab name, line numbers, code, error squiggle.
	add_child(_mono_label("main.cpp", SMALL_SIZE, CODE_TEXT, TAB_POS))
	_gutter_label = _mono_label("", CODE_SIZE, DIM_TEXT, Vector2(GUTTER_X, CODE_POS.y))
	_gutter_label.add_theme_constant_override("line_spacing", LINE_GAP)
	add_child(_gutter_label)
	_code_label = RichTextLabel.new()
	_code_label.bbcode_enabled = true
	_code_label.fit_content = true
	_code_label.scroll_active = false
	_code_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_code_label.position = CODE_POS
	_code_label.size = Vector2(520.0, 220.0)
	_code_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_code_label.add_theme_font_override("normal_font", mono)
	_code_label.add_theme_font_size_override("normal_font_size", CODE_SIZE)
	_code_label.add_theme_color_override("default_color", CODE_TEXT)
	_code_label.add_theme_constant_override("line_separation", LINE_GAP)
	add_child(_code_label)
	_squiggle = Control.new()
	_squiggle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_squiggle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_squiggle.draw.connect(_draw_squiggle)
	add_child(_squiggle)

	# The terminal panel under the editor.
	_error_label = _mono_label("", CODE_SIZE, ERROR_TEXT, TERMINAL_POS)
	_error_label.add_theme_constant_override("line_spacing", LINE_GAP)
	add_child(_error_label)

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
	_overlay.build("NOT IN SCOPE", "Click the line that fixes the build!")
	_status_label = _overlay.status_label


func _mono_label(text: String, font_size: int, color: Color, at: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", MONO)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _start_round() -> void:
	_ended = false
	_fixed = false
	_shuffle_clock = 0.0
	_seconds_left = DURATIONS[difficulty]
	_intro_left = INTRO_SECONDS
	var names: Array = NAME_SETS[_rng.randi_range(0, NAME_SETS.size() - 1)]
	var missing_first := _rng.randf() < 0.5
	_missing = names[0] if missing_first else names[1]
	_declared = names[1] if missing_first else names[0]
	_result = names[2]
	_value = _rng.randi_range(1, 9)
	_declared_value = _rng.randi_range(1, 9)
	var op: String = OPERATORS[_rng.randi_range(0, OPERATORS.size() - 1)]
	_expression = "%s %s %s" % [names[0], op, names[1]]
	_correct_line = "int %s = %d;" % [_missing, _value]

	_render_code(false)
	_error_label.text = "main.cpp:3: error:\n'%s' was not declared in this scope" % _missing
	_error_label.add_theme_color_override("font_color", ERROR_TEXT)

	for button: Button in _choice_buttons:
		button.queue_free()
	_choice_buttons.clear()
	var lines := build_choices()
	for index: int in lines.size():
		var button := _choice_button(lines[index])
		button.set_meta("correct", lines[index] == _correct_line)
		button.position = _slot_position(index)
		add_child(button)
		# Keep choices under the walk-in scene and the text overlay.
		move_child(button, _walk_in.get_index())
		_choice_buttons.append(button)
	_timer_label.text = "TIME %.1f" % _seconds_left
	_overlay.clear_pop()
	_update_intro()
	time_changed.emit(_seconds_left, DURATIONS[difficulty])


## A quick-fix suggestion on the editor: flat pixel rows, no rounded boxes.
func _choice_button(line: String) -> Button:
	var button := Button.new()
	button.text = line
	button.size = CHOICE_SIZE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE  # mouse only
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", MONO)
	button.add_theme_font_size_override("font_size", CODE_SIZE)
	button.add_theme_color_override("font_color", CODE_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", DIM_TEXT)
	button.add_theme_stylebox_override("normal", _row_style(Color("#2a2f3c"), Color("#3a4152")))
	button.add_theme_stylebox_override("hover", _row_style(Color("#34405a"), Color("#e8a048")))
	button.add_theme_stylebox_override("pressed", _row_style(Color("#34405a"), Color("#ffd166")))
	button.add_theme_stylebox_override("disabled", _row_style(Color("#23262f"), Color("#2c313c")))
	button.pressed.connect(_choose.bind(button))
	return button


## A flat row with a 5 px bar on the left (one art pixel), like an IDE list.
func _row_style(background: Color, bar: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = bar
	style.border_width_left = int(PX)
	style.content_margin_left = 20
	style.content_margin_right = 12
	return style


## Returns the shuffled candidate lines for the current puzzle. Exactly one is
## the correct declaration; the rest are decoys picked by difficulty.
func build_choices() -> Array[String]:
	var obvious: Array[String] = [
		"%s == %d;" % [_missing, _value],
		"int %s = %d;" % [_declared, _value],
	]
	var lookalike: Array[String] = [
		"int %s = %d;" % [_missing.to_upper() if _missing.length() == 1 else _missing.capitalize(), _value],
		"%s = %d;" % [_missing, _value],
	]
	var sneaky: Array[String] = [
		"int %s = %d" % [_missing, _value],
		"itn %s = %d;" % [_missing, _value],
	]
	obvious.shuffle()
	lookalike.shuffle()
	sneaky.shuffle()
	var decoys: Array[String] = []
	match difficulty:
		0:
			decoys = [obvious[0]]
		1:
			decoys = [obvious[0], lookalike[0]]
		_:
			# HARD: the case look-alike is always present.
			decoys = [lookalike[0] if lookalike[0].begins_with("int ") else lookalike[1], sneaky[0], obvious[0]]
	var lines: Array[String] = [_correct_line]
	for line: String in decoys:
		if not lines.has(line):
			lines.append(line)
	lines.resize(mini(lines.size(), CHOICE_COUNTS[difficulty]))
	lines.shuffle()
	return lines


func _render_code(fixed: bool) -> void:
	_fixed = fixed
	var kw := "[color=#%s]int[/color]" % KEYWORD.to_html(false)
	var lines: Array[String] = [
		"%s main() {" % kw,
		"  %s %s = %d;" % [kw, _declared, _declared_value],
	]
	if fixed:
		lines.append("  [color=#%s]%s[/color]" % [GOOD_TEXT.to_html(false), _correct_line])
	lines.append("  %s %s = %s;" % [kw, _result, _expression])
	lines.append("  [color=#%s]return[/color] %s;" % [KEYWORD.to_html(false), _result])
	lines.append("}")
	_code_label.text = "\n".join(lines)
	var numbers: Array[String] = []
	for i: int in lines.size():
		numbers.append(str(i + 1))
	_gutter_label.text = "\n".join(numbers)
	_squiggle.queue_redraw()


## The red pixel zigzag under the expression that uses the missing variable
## (line 3, until the fix goes in above it).
func _draw_squiggle() -> void:
	if _fixed:
		return
	var column := ("  int %s = " % _result).length()
	var line_height := float(CODE_SIZE + LINE_GAP)
	var start := CODE_POS + Vector2(column * CHAR_WIDTH, 2.0 * line_height + CODE_SIZE + 2.0)
	var dot := Vector2(3.0, 3.0)  # one font pixel at 3x
	var steps := int(_expression.length() * CHAR_WIDTH / dot.x)
	for i: int in steps:
		var lift := 0.0 if i % 4 < 2 else dot.y
		_squiggle.draw_rect(Rect2(start + Vector2(i * dot.x, lift), dot), ERROR_TEXT)


func _slot_position(index: int) -> Vector2:
	return Vector2(CHOICE_X, CHOICE_TOP + index * CHOICE_GAP)


func _shuffle_choices() -> void:
	var order: Array = range(_choice_buttons.size())
	order.shuffle()
	for index: int in _choice_buttons.size():
		var button := _choice_buttons[index]
		var target := _slot_position(order[index])
		var tween := create_tween()
		tween.tween_property(button, "position", target, 0.18)


func _choose(button: Button) -> void:
	if _ended or _intro_left > 0.0:
		return
	var correct: bool = button.get_meta("correct")
	button.set_meta("chosen", true)
	var mark := GOOD_TEXT if correct else ERROR_TEXT
	button.add_theme_color_override("font_color", mark)
	button.add_theme_color_override("font_hover_color", mark)
	button.add_theme_stylebox_override("normal", _row_style(Color("#2a2f3c"), mark))
	button.add_theme_stylebox_override("hover", _row_style(Color("#2a2f3c"), mark))
	if correct:
		_render_code(true)
		_error_label.text = "Build succeeded.\n0 errors."
		_error_label.add_theme_color_override("font_color", GOOD_TEXT)
		_finish_round(true, "COMPILED!")
	else:
		_show_needed_line()
		_finish_round(false, "STILL BROKEN!")


## After a miss, the terminal shows the line that was needed.
func _show_needed_line() -> void:
	_error_label.text = "main.cpp:3: error:\nneeded  %s" % _correct_line


func _finish_round(success: bool, message: String) -> void:
	if _ended:
		return
	_ended = true
	_intro_left = 0.0
	_update_intro()
	for other: Button in _choice_buttons:
		other.disabled = not other.has_meta("chosen")
	_overlay.pop(("✓ " if success else "✗ ") + message, GOOD_TEXT if success else Color("#ff9e9e"), 42)
	round_completed.emit(success)
