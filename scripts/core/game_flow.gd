extends Control

## SCRUM-19: Title, stage select, stage clear, and game-over flow.
##
## Owns the playable week: menus, microgame, HUD, and bike interstitial.

signal stage_selected(stage_index: int)
signal microgame_requested(stage_index: int)
signal stage_cleared(stage_index: int)
signal game_over

enum FlowState { TITLE, STAGE_SELECT, PLAYING, TRANSITION, STAGE_CLEAR, GAME_OVER }

const STAGES: Array[String] = ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY"]
const CANVAS_SCENE := preload("res://scenes/microgames/canvas.tscn")
const SCHEDULE_SCENE := preload("res://scenes/microgames/schedule_builder.tscn")
const FOCUS_SCENE := preload("res://scenes/microgames/stay_focused.tscn")
const GATES_SCENE := preload("res://scenes/microgames/gates.tscn")
const BIKE_SCENE := preload("res://scenes/core/bike_transition.tscn")
const HUD_SCENE := preload("res://scenes/ui/game_hud.tscn")

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
var _center: CenterContainer
var _active_scene: Control
var _hud: Control
var _pending_stage := 0


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
		_retry_stage()


func _build_shell() -> void:
	var background := ColorRect.new()
	background.color = Color("#0d1324")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620.0, 420.0)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#172746"), Color("#38537d")))
	_center.add_child(panel)

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
	_clear_active_scene()
	_center.visible = true
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
	_clear_active_scene()
	_center.visible = true
	if state == FlowState.TITLE:
		lives = 3
		score = 0
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
	_clear_active_scene()
	_selected_stage = clampi(stage_index, 0, STAGES.size() - 1)
	current_stage = _selected_stage
	state = FlowState.PLAYING
	_center.visible = false
	_clear_content()
	var microgame := _scene_for_stage(current_stage).instantiate() as Control
	# The parent flow already owns the pause overlay. Keep a single copy.
	var local_pause := microgame.get_node_or_null("SettingsPauseMenu")
	if local_pause != null:
		microgame.remove_child(local_pause)
		local_pause.free()
	microgame.set("difficulty", mini(current_stage / 2, 2))
	if current_stage == 0 or current_stage == 4:
		microgame.set("show_internal_timer", false)
	microgame.connect("round_completed", _on_round_completed)
	microgame.connect("time_changed", _on_round_time_changed)
	_active_scene = microgame
	add_child(microgame)
	_hud = HUD_SCENE.instantiate() as Control
	add_child(_hud)
	current_prompt = _prompt_for_stage(current_stage)

	stage_selected.emit(current_stage)
	microgame_requested.emit(current_stage)
	var round_seconds: float = microgame.call("get_round_seconds")
	_hud.set_round_status(round_seconds, round_seconds, lives, score, current_stage, STAGES.size())


func _scene_for_stage(stage_index: int) -> PackedScene:
	match stage_index:
		1:
			return SCHEDULE_SCENE
		2:
			return FOCUS_SCENE
		3:
			return GATES_SCENE
		_:
			return CANVAS_SCENE


func _prompt_for_stage(stage_index: int) -> String:
	match stage_index:
		1:
			return "SCHEDULE BUILDER"
		2:
			return "STAY FOCUSED"
		3:
			return "LOGIC GATES"
		_:
			return "CANVAS"


func _on_round_time_changed(seconds_left: float, round_seconds: float) -> void:
	if state == FlowState.PLAYING and is_instance_valid(_hud):
		_hud.set_round_status(seconds_left, round_seconds, lives, score, current_stage, STAGES.size())


func _on_round_completed(success: bool) -> void:
	if state != FlowState.PLAYING:
		return
	if success:
		score += 100
	else:
		lives -= 1
	await get_tree().create_timer(0.8, false).timeout
	if state != FlowState.PLAYING:
		return
	if success:
		show_stage_clear(current_stage + 1)
	elif lives <= 0:
		show_game_over()
	else:
		_begin_transition(current_stage)


func _begin_transition(next_stage_index: int) -> void:
	_clear_active_scene()
	_center.visible = false
	state = FlowState.TRANSITION
	_pending_stage = next_stage_index
	var bike := BIKE_SCENE.instantiate() as Control
	bike.set("next_prompt", _prompt_for_stage(next_stage_index))
	bike.set("lives", lives)
	bike.set("score", score)
	bike.transition_finished.connect(_on_transition_finished)
	_active_scene = bike
	add_child(bike)


func _on_transition_finished(_next_scene_path: String) -> void:
	if state == FlowState.TRANSITION:
		_start_stage(_pending_stage)


func show_stage_clear(next_stage_index: int = -1) -> void:
	_clear_active_scene()
	_center.visible = true
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
		next_button.pressed.connect(_begin_transition.bind(next_stage_index))
	else:
		next_button.text = "Back to Title"
		next_button.pressed.connect(_show_title)
	_content.add_child(next_button)

	stage_cleared.emit(current_stage)


func show_game_over() -> void:
	_clear_active_scene()
	_center.visible = true
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
	retry_button.pressed.connect(_retry_stage)
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
		_begin_transition(next_stage)
	else:
		_show_title()


func _retry_stage() -> void:
	lives = 3
	score = 0
	_start_stage(current_stage)


func _clear_active_scene() -> void:
	if is_instance_valid(_active_scene):
		_active_scene.queue_free()
		_active_scene = null
	if is_instance_valid(_hud):
		_hud.queue_free()
		_hud = null


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
