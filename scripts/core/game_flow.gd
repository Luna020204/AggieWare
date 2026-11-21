extends Control
## Owns menu navigation, day/round sequencing, score, lives, and shared overlays.
## The editable WeekPlan contains the collection; games never route themselves.

signal stage_selected(stage_index: int)
signal microgame_requested(stage_index: int)
signal stage_cleared(stage_index: int)
signal game_over

enum FlowState { TITLE, STAGE_SELECT, PLAYING, RESULT, TRANSITION, STAGE_CLEAR, GAME_OVER }

const BIKE_SCENE := preload("res://scenes/core/bike_transition.tscn")
const HUD_SCENE := preload("res://scenes/ui/game_hud.tscn")

@export var week_plan: WeekPlan
@export_range(0.0, 3.0, 0.05) var result_delay := 0.8
@export_range(0.01, 10.0, 0.1) var bike_duration := 3.0

var state: FlowState = FlowState.TITLE
var current_stage := 0
var current_round := 0
var lives := 3
var score := 0
var current_prompt := "PLAY"

var _content: VBoxContainer
var _header_label: Label
var _subtitle_label: Label
var _stage_buttons: Array[Button] = []
var _selected_stage := 0
var _center: CenterContainer
var _active_scene: Control
var _hud: Control
var _pending_stage := 0
var _pending_round := 0
var _run_token := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if week_plan == null:
		week_plan = load("res://scenes/core/default_week.tres") as WeekPlan
	_build_shell()
	var errors := week_plan.validate() if week_plan != null else PackedStringArray(["No week plan is assigned."])
	if not errors.is_empty():
		_show_configuration_error("\n".join(errors))
		return
	_show_title()


func _unhandled_key_input(event: InputEvent) -> void:
	if get_tree().paused or (event is InputEventKey and event.echo):
		return
	# Native focused buttons handle their own GUI keys first. Only custom action
	# keys that GUI did not consume reach here, so one press activates one screen.
	if state == FlowState.STAGE_SELECT:
		if event.is_action_pressed(InputActions.ACTION_UP):
			_set_selected_stage(_selected_stage - 1)
		elif event.is_action_pressed(InputActions.ACTION_DOWN):
			_set_selected_stage(_selected_stage + 1)
		elif event.is_action_pressed(InputActions.ACTION_CONFIRM):
			_start_stage(_selected_stage)
		else:
			return
	elif event.is_action_pressed(InputActions.ACTION_CONFIRM):
		match state:
			FlowState.TITLE:
				_show_stage_select()
			FlowState.STAGE_CLEAR:
				_advance_after_clear()
			FlowState.GAME_OVER:
				_retry_stage()
			_:
				return
	else:
		return
	get_viewport().set_input_as_handled()


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
	_center.show()
	state = FlowState.TITLE
	_header_label.text = "AGGIEWARE"
	_subtitle_label.text = "A week of tiny games at UC Davis"
	_clear_content()
	_add_message("Bike across campus, survive class, and reach the ECS 179 final.")
	var start_button := _add_button("Start Week", _show_stage_select)
	start_button.custom_minimum_size.y = 54.0
	start_button.add_theme_font_size_override("font_size", 22)
	start_button.grab_focus()
	_add_message("Use the arrow keys / WASD to choose · Confirm to continue")


func _show_stage_select() -> void:
	var starting_week := state == FlowState.TITLE
	_clear_active_scene()
	_center.show()
	if starting_week:
		lives = 3
		score = 0
	state = FlowState.STAGE_SELECT
	_header_label.text = "SELECT A DAY"
	_subtitle_label.text = "Choose where your week begins"
	_clear_content()
	_stage_buttons.clear()
	for index: int in week_plan.stages.size():
		var stage := week_plan.stages[index]
		var stage_button := _add_button("%d   %s   ·   %d round%s" % [index + 1, stage.title, stage.games.size(), "s" if stage.games.size() != 1 else ""], _start_stage.bind(index))
		stage_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		stage_button.focus_entered.connect(_remember_selected_stage.bind(index))
		_stage_buttons.append(stage_button)
	_set_selected_stage(_selected_stage)


func _start_stage(stage_index: int) -> void:
	_selected_stage = clampi(stage_index, 0, week_plan.stages.size() - 1)
	stage_selected.emit(_selected_stage)
	_start_round(_selected_stage, 0)


func _start_round(stage_index: int, round_index: int) -> void:
	_clear_active_scene()
	current_stage = clampi(stage_index, 0, week_plan.stages.size() - 1)
	var stage := week_plan.stages[current_stage]
	current_round = clampi(round_index, 0, stage.games.size() - 1)
	var definition := stage.games[current_round]
	var packed := definition.load_scene()
	if packed == null:
		_show_configuration_error("Cannot load: " + definition.scene_path)
		return
	var candidate := packed.instantiate()
	if not candidate is MicrogameBase:
		candidate.free()
		_show_configuration_error("Microgame must extend MicrogameBase: " + definition.scene_path)
		return
	var microgame := candidate as MicrogameBase
	microgame.managed_by_flow = true
	microgame.show_internal_timer = false
	microgame.difficulty = definition.difficulty
	microgame.prompt = definition.prompt
	microgame.duration_override = definition.round_seconds_override
	microgame.round_completed.connect(_on_round_completed.bind(_run_token))
	microgame.time_changed.connect(_on_round_time_changed.bind(_run_token))
	current_prompt = definition.prompt
	state = FlowState.PLAYING
	_center.hide()
	_clear_content()
	# The HUD is ready before the game's initial time_changed signal fires.
	_hud = HUD_SCENE.instantiate() as Control
	add_child(_hud)
	_active_scene = microgame
	add_child(microgame)
	move_child(_hud, get_child_count() - 1)
	microgame_requested.emit(current_stage)


func _scene_for_stage(stage_index: int) -> PackedScene:
	return week_plan.stages[stage_index].games[0].load_scene()


func _prompt_for_stage(stage_index: int, round_index: int = 0) -> String:
	return week_plan.stages[stage_index].games[round_index].prompt


func _on_round_time_changed(seconds_left: float, round_seconds: float, token: int = -1) -> void:
	if token != -1 and token != _run_token:
		return
	if (state == FlowState.PLAYING or state == FlowState.RESULT) and is_instance_valid(_hud):
		var stage := week_plan.stages[current_stage]
		_hud.set_round_status(seconds_left, round_seconds, lives, score, current_stage, week_plan.stages.size(), current_round, stage.games.size(), stage.games[current_round].title)


func _on_round_completed(success: bool, token: int = -1) -> void:
	if state != FlowState.PLAYING or (token != -1 and token != _run_token):
		return
	# Reserve this result synchronously before waiting, so duplicate signals and
	# callbacks from an earlier run cannot award points or remove lives twice.
	state = FlowState.RESULT
	var result_token := _run_token
	if success:
		score += 100
	else:
		lives -= 1
	var microgame := _active_scene as MicrogameBase
	if microgame != null:
		_on_round_time_changed(microgame.get_seconds_left(), microgame._round_seconds)
	await get_tree().create_timer(maxf(result_delay, 0.0), false).timeout
	if not is_inside_tree() or state != FlowState.RESULT or result_token != _run_token:
		return
	if success:
		if current_round + 1 < week_plan.stages[current_stage].games.size():
			_begin_transition(current_stage, current_round + 1)
		else:
			show_stage_clear(current_stage + 1)
	elif lives <= 0:
		show_game_over()
	else:
		_begin_transition(current_stage, current_round)


func _begin_transition(next_stage_index: int, next_round_index: int = 0) -> void:
	_clear_active_scene()
	_center.hide()
	state = FlowState.TRANSITION
	_pending_stage = next_stage_index
	_pending_round = next_round_index
	var bike := BIKE_SCENE.instantiate() as Control
	bike.set("managed_by_flow", true)
	bike.set("next_prompt", week_plan.stages[next_stage_index].games[next_round_index].title)
	bike.set("transition_duration", bike_duration)
	bike.set("lives", lives)
	bike.set("score", score)
	bike.transition_finished.connect(_on_transition_finished.bind(_run_token))
	_active_scene = bike
	add_child(bike)


func _on_transition_finished(_next_scene_path: String, token: int = -1) -> void:
	if state == FlowState.TRANSITION and (token == -1 or token == _run_token):
		_start_round(_pending_stage, _pending_round)


func show_stage_clear(_next_stage_index: int = -1) -> void:
	_clear_active_scene()
	_center.show()
	state = FlowState.STAGE_CLEAR
	_header_label.text = "DAY CLEAR!"
	_subtitle_label.text = "%s complete · Score: %d" % [week_plan.stages[current_stage].title, score]
	_clear_content()
	var next_stage := current_stage + 1
	if next_stage < week_plan.stages.size():
		_add_message("Nice work. Get ready for the next challenge.")
		_add_button("Continue to %s" % week_plan.stages[next_stage].title, _advance_after_clear).grab_focus()
	else:
		_add_message("You made it through the week!")
		_add_button("Back to Title", _show_title).grab_focus()
	stage_cleared.emit(current_stage)


func show_game_over() -> void:
	_clear_active_scene()
	_center.show()
	state = FlowState.GAME_OVER
	_header_label.text = "GAME OVER"
	_subtitle_label.text = "%s · Final score: %d" % [week_plan.stages[current_stage].title, score]
	_clear_content()
	_add_message("The week is not over yet. Try the day again.")
	_add_button("Retry %s" % week_plan.stages[current_stage].title, _retry_stage).grab_focus()
	game_over.emit()


func set_playing_context(prompt_text: String, new_lives: int, new_score: int) -> void:
	current_prompt = prompt_text
	lives = new_lives
	score = new_score


func _advance_after_clear() -> void:
	if state != FlowState.STAGE_CLEAR:
		return
	var next_stage := current_stage + 1
	if next_stage < week_plan.stages.size():
		_begin_transition(next_stage)
	else:
		_show_title()


func _retry_stage() -> void:
	lives = 3
	score = 0
	_start_stage(current_stage)


func _clear_active_scene() -> void:
	_run_token += 1
	if is_instance_valid(_active_scene):
		remove_child(_active_scene)
		_active_scene.queue_free()
	_active_scene = null
	if is_instance_valid(_hud):
		remove_child(_hud)
		_hud.queue_free()
	_hud = null


func _set_selected_stage(stage_index: int) -> void:
	_selected_stage = clampi(stage_index, 0, week_plan.stages.size() - 1)
	if not _stage_buttons.is_empty():
		_stage_buttons[_selected_stage].grab_focus()


func _remember_selected_stage(index: int) -> void:
	_selected_stage = index


func _clear_content() -> void:
	_stage_buttons.clear()
	for child: Node in _content.get_children():
		# Detach now, defer deletion: a button may still be emitting pressed.
		_content.remove_child(child)
		child.queue_free()


func _show_configuration_error(message: String) -> void:
	_clear_active_scene()
	_center.show()
	state = FlowState.GAME_OVER
	set_process_unhandled_key_input(false)
	_header_label.text = "WEEK PLAN NEEDS ATTENTION"
	_subtitle_label.text = "Check the Week Plan resource in the Inspector."
	_clear_content()
	_add_message(message)
	push_error(message)


func _add_message(message: String) -> Label:
	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(label)
	return label


func _add_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 42.0
	button.pressed.connect(callback)
	_content.add_child(button)
	return button


func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	return style
