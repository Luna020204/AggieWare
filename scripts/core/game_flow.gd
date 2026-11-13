extends Control

## SCRUM-19: Title, stage select, stage clear, and game-over flow.
##
## This scene owns presentation and emits signals for the eventual stage
## manager. It does not assume how microgame scenes are instantiated, so the
## manager can connect to `microgame_requested` without scene conflicts.

signal stage_selected(stage_index: int)
signal microgame_requested(stage_index: int)
signal stage_cleared(stage_index: int)
signal game_over

enum FlowState { TITLE, STAGE_SELECT, PLAYING, STAGE_CLEAR, GAME_OVER }

const STAGES: Array[String] = ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY"]

var state: FlowState = FlowState.TITLE
var current_stage := 0
var lives := 3
var score := 0
var current_prompt := "CANVAS"

var _content: VBoxContainer
var _header_label: Label
var _subtitle_label: Label
var _stage_buttons: Array[Button] = []
var _selected_stage := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build_shell()
	_show_title()


func _process(_delta: float) -> void:
	if state == FlowState.TITLE and InputActions.is_just_pressed(InputActions.ACTION_CONFIRM):
		_show_stage_select()
	elif state == FlowState.STAGE_SELECT:
		if InputActions.is_just_pressed(InputActions.ACTION_UP):
			_set_selected_stage(_selected_stage - 1)
		elif InputActions.is_just_pressed(InputActions.ACTION_DOWN):
			_set_selected_stage(_selected_stage + 1)
		elif InputActions.is_just_pressed(InputActions.ACTION_CONFIRM):
			_start_stage(_selected_stage)
	elif state == FlowState.STAGE_CLEAR and InputActions.is_just_pressed(InputActions.ACTION_CONFIRM):
		_advance_after_clear()
	elif state == FlowState.GAME_OVER and InputActions.is_just_pressed(InputActions.ACTION_CONFIRM):
		_start_stage(current_stage)


func _build_shell() -> void:
	var background := ColorRect.new()
	background.color = Color("#0d1324")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620.0, 420.0)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#172746"), Color("#38537d")))
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 42)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_right", 42)
	margin.add_theme_constant_override("margin_bottom", 36)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)

	_header_label = Label.new()
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_label.add_theme_font_size_override("font_size", 38)
	_header_label.add_theme_color_override("font_color", Color("#f5f7ff"))
	layout.add_child(_header_label)

	_subtitle_label = Label.new()
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.add_theme_font_size_override("font_size", 18)
	_subtitle_label.add_theme_color_override("font_color", Color("#b8c7e6"))
	layout.add_child(_subtitle_label)

	layout.add_child(HSeparator.new())
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	layout.add_child(_content)


func _show_title() -> void:
	state = FlowState.TITLE
	_header_label.text = "AGGIEWARE"
	_subtitle_label.text = "A week of tiny games at UC Davis"
	_clear_content()

	var body := Label.new()
	body.text = "Bike across campus, survive class, and reach the ECS 179 final."
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(body)

	var start_button := Button.new()
	start_button.text = "Start Week"
	start_button.custom_minimum_size = Vector2(0.0, 54.0)
	start_button.add_theme_font_size_override("font_size", 22)
	start_button.pressed.connect(_show_stage_select)
	_content.add_child(start_button)

	var hint := Label.new()
	hint.text = "Press Enter / Space"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color("#879ac1"))
	_content.add_child(hint)


func _show_stage_select() -> void:
	state = FlowState.STAGE_SELECT
	_header_label.text = "SELECT A DAY"
	_subtitle_label.text = "Choose where your week begins"
	_clear_content()
	_stage_buttons.clear()

	for index: int in STAGES.size():
		var stage_button := Button.new()
		stage_button.text = "%d   %s" % [index + 1, STAGES[index]]
		stage_button.custom_minimum_size = Vector2(0.0, 42.0)
		stage_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		stage_button.pressed.connect(_start_stage.bind(index))
		_content.add_child(stage_button)
		_stage_buttons.append(stage_button)

	_set_selected_stage(_selected_stage)


func _start_stage(stage_index: int) -> void:
	_selected_stage = clampi(stage_index, 0, STAGES.size() - 1)
	current_stage = _selected_stage
	state = FlowState.PLAYING
	_header_label.text = STAGES[current_stage]
	_subtitle_label.text = "Stage %d · Lives: %d · Score: %d" % [current_stage + 1, lives, score]
	_clear_content()

	var ready_label := Label.new()
	ready_label.text = "Next microgame: %s" % current_prompt
	ready_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ready_label.add_theme_font_size_override("font_size", 26)
	_content.add_child(ready_label)

	var hint := Label.new()
	hint.text = "The stage manager can now load the requested microgame."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color("#b8c7e6"))
	_content.add_child(hint)

	stage_selected.emit(current_stage)
	microgame_requested.emit(current_stage)


func show_stage_clear(next_stage_index: int = -1) -> void:
	state = FlowState.STAGE_CLEAR
	_header_label.text = "STAGE CLEAR!"
	_subtitle_label.text = "%s complete · Score: %d" % [STAGES[current_stage], score]
	_clear_content()

	var message := Label.new()
	message.text = "Nice work. Get ready for the next challenge."
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(message)

	var next_button := Button.new()
	if next_stage_index >= 0 and next_stage_index < STAGES.size():
		next_button.text = "Continue to %s" % STAGES[next_stage_index]
		next_button.pressed.connect(_start_stage.bind(next_stage_index))
	else:
		next_button.text = "Back to Title"
		next_button.pressed.connect(_show_title)
	_content.add_child(next_button)

	stage_cleared.emit(current_stage)


func show_game_over() -> void:
	state = FlowState.GAME_OVER
	_header_label.text = "GAME OVER"
	_subtitle_label.text = "%s · Final score: %d" % [STAGES[current_stage], score]
	_clear_content()

	var message := Label.new()
	message.text = "The week is not over yet. Try the stage again."
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(message)

	var retry_button := Button.new()
	retry_button.text = "Retry %s" % STAGES[current_stage]
	retry_button.pressed.connect(_start_stage.bind(current_stage))
	_content.add_child(retry_button)
	game_over.emit()


func set_playing_context(prompt: String, new_lives: int, new_score: int) -> void:
	current_prompt = prompt
	lives = new_lives
	score = new_score
	if state == FlowState.PLAYING:
		_subtitle_label.text = "Stage %d · Lives: %d · Score: %d" % [current_stage + 1, lives, score]


func _advance_after_clear() -> void:
	var next_stage := current_stage + 1
	if next_stage < STAGES.size():
		_start_stage(next_stage)
	else:
		_show_title()


func _set_selected_stage(stage_index: int) -> void:
	_selected_stage = clampi(stage_index, 0, STAGES.size() - 1)
	for index: int in _stage_buttons.size():
		_stage_buttons[index].button_pressed = index == _selected_stage
	if _stage_buttons.size() > 0:
		_stage_buttons[_selected_stage].grab_focus()


func _clear_content() -> void:
	for child: Node in _content.get_children():
		# A transition can be triggered from a Button.pressed signal. Freeing the
		# button synchronously while that signal is being emitted causes Godot to
		# reject the operation as a locked-object free.
		child.queue_free()


func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	return style
