extends Control

## SCRUM-23: Variable Not in Scope (Lecture Hall).
##
## A short C++ snippet fails to compile because one variable was never
## declared. Click the candidate line that declares it before time runs out.
## Mouse and click only; no typing. A wrong click fails the round.
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
const CHOICE_TOP := 190.0
const CHOICE_GAP := 104.0

var _seconds_left := 0.0
var _ended := false
var _shuffle_clock := 0.0
var _missing := "y"
var _declared := "x"
var _result := "z"
var _value := 5
var _declared_value := 3
var _expression := "x + y"
var _correct_line := ""
var _choice_buttons: Array[Button] = []
var _rng := RandomNumberGenerator.new()

var _code_label: RichTextLabel
var _error_label: Label
var _timer_label: Label
var _status_label: Label
var _mono: SystemFont


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
	if difficulty >= 2:
		_shuffle_clock += delta
		if _shuffle_clock >= SHUFFLE_INTERVAL:
			_shuffle_clock = 0.0
			_shuffle_choices()
	if _seconds_left <= 0.0:
		_finish_round(false, "Time's up — the build is still red!")


func _build_ui() -> void:
	_mono = SystemFont.new()
	_mono.font_names = PackedStringArray(["Consolas", "Cascadia Mono", "Courier New", "DejaVu Sans Mono", "monospace"])

	var background := ColorRect.new()
	background.color = Color("#1a1420")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	# Lecture hall: rows of seats along the bottom edge.
	for row: int in 2:
		var seats := ColorRect.new()
		seats.color = Color("#2b2033") if row == 0 else Color("#33263d")
		seats.position = Vector2(0.0, 676.0 + row * 22.0)
		seats.size = Vector2(1280.0, 22.0)
		seats.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(seats)

	var title := Label.new()
	title.text = "NOT IN SCOPE"
	title.position = Vector2(48, 35)
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#f5f7ff"))
	add_child(title)

	var instruction := Label.new()
	instruction.text = "Lecture Hall · Click the line that fixes the compile error."
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

	# Projector screen holding the code.
	var screen := PanelContainer.new()
	screen.position = Vector2(48, 180)
	screen.size = Vector2(620, 190)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_theme_stylebox_override("panel", _panel_style(Color("#0f1117"), Color("#6c5a8c")))
	add_child(screen)
	_code_label = RichTextLabel.new()
	_code_label.bbcode_enabled = true
	_code_label.fit_content = true
	_code_label.scroll_active = false
	_code_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_code_label.add_theme_font_override("normal_font", _mono)
	_code_label.add_theme_font_override("bold_font", _mono)
	_code_label.add_theme_font_size_override("normal_font_size", 24)
	_code_label.add_theme_font_size_override("bold_font_size", 24)
	screen.add_child(_code_label)

	var error_panel := PanelContainer.new()
	error_panel.position = Vector2(48, 390)
	error_panel.size = Vector2(620, 84)
	error_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	error_panel.add_theme_stylebox_override("panel", _panel_style(Color("#2a1216"), Color("#ff6b7a")))
	add_child(error_panel)
	_error_label = Label.new()
	_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error_label.add_theme_font_override("font", _mono)
	_error_label.add_theme_font_size_override("font_size", 19)
	_error_label.add_theme_color_override("font_color", Color("#ff9e9e"))
	error_panel.add_child(_error_label)

	var pick := Label.new()
	pick.text = "Add which line?"
	pick.position = Vector2(740, 146)
	pick.add_theme_font_size_override("font_size", 22)
	pick.add_theme_color_override("font_color", Color("#c9b8e6"))
	add_child(pick)

	_status_label = Label.new()
	_status_label.position = Vector2(48, 500)
	_status_label.size = Vector2(1180, 48)
	_status_label.add_theme_font_size_override("font_size", 22)
	_status_label.add_theme_color_override("font_color", Color("#c9b8e6"))
	add_child(_status_label)


func _start_round() -> void:
	_ended = false
	_shuffle_clock = 0.0
	_seconds_left = DURATIONS[difficulty]
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
	_error_label.text = "main.cpp:3: error: '%s' was not declared in this scope" % _missing
	_status_label.text = "Which declaration makes it compile?"
	_status_label.add_theme_color_override("font_color", Color("#c9b8e6"))

	for button: Button in _choice_buttons:
		button.queue_free()
	_choice_buttons.clear()
	var lines := build_choices()
	for index: int in lines.size():
		var button := Button.new()
		button.text = lines[index]
		button.set_meta("correct", lines[index] == _correct_line)
		button.position = _slot_position(index)
		button.size = Vector2(492, 84)
		button.focus_mode = Control.FOCUS_NONE  # mouse only
		button.add_theme_font_override("font", _mono)
		button.add_theme_font_size_override("font_size", 26)
		button.add_theme_stylebox_override("normal", _panel_style(Color("#241c30"), Color("#6c5a8c")))
		button.add_theme_stylebox_override("hover", _panel_style(Color("#33284a"), Color("#c9b8e6")))
		button.add_theme_stylebox_override("pressed", _panel_style(Color("#33284a"), Color("#ffd166")))
		button.add_theme_stylebox_override("disabled", _panel_style(Color("#1d1726"), Color("#3d3350")))
		button.pressed.connect(_choose.bind(button))
		add_child(button)
		_choice_buttons.append(button)
	time_changed.emit(_seconds_left, DURATIONS[difficulty])


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
	var lines: Array[String] = [
		"[color=#c792ea]int[/color] main() {",
		"    [color=#c792ea]int[/color] %s = %d;" % [_declared, _declared_value],
	]
	if fixed:
		lines.append("    [color=#73e6a8]%s[/color]" % _correct_line)
		lines.append("    [color=#c792ea]int[/color] %s = %s;" % [_result, _expression])
	else:
		lines.append("    [color=#c792ea]int[/color] %s = [bgcolor=#5a1d26]%s[/bgcolor];" % [_result, _expression])
	lines.append("    [color=#c792ea]return[/color] %s;" % _result)
	lines.append("}")
	_code_label.text = "\n".join(lines)


func _slot_position(index: int) -> Vector2:
	return Vector2(740.0, CHOICE_TOP + index * CHOICE_GAP)


func _shuffle_choices() -> void:
	var order: Array = range(_choice_buttons.size())
	order.shuffle()
	for index: int in _choice_buttons.size():
		var button := _choice_buttons[index]
		var target := _slot_position(order[index])
		var tween := create_tween()
		tween.tween_property(button, "position", target, 0.18)


func _choose(button: Button) -> void:
	if _ended:
		return
	var correct: bool = button.get_meta("correct")
	for other: Button in _choice_buttons:
		other.disabled = true
	button.disabled = false
	button.add_theme_color_override("font_color", Color("#73e6a8") if correct else Color("#ff9e9e"))
	if correct:
		_render_code(true)
		_error_label.text = "Build succeeded. 0 errors."
		_error_label.add_theme_color_override("font_color", Color("#73e6a8"))
		_finish_round(true, "Compiled! %s is in scope." % _missing)
	else:
		_finish_round(false, "Still broken — you needed  %s" % _correct_line)


func _finish_round(success: bool, message: String) -> void:
	if _ended:
		return
	_ended = true
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", Color("#73e6a8") if success else Color("#ff9e9e"))
	round_completed.emit(success)


func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style
