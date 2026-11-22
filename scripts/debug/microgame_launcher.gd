extends Control
## Debug host for every catalog game, using the same lifecycle as the week.

const HUD_SCENE := preload("res://scenes/ui/game_hud.tscn")
const UI := preload("res://scripts/ui/microgame_ui.gd")
const SPEEDS: Array[float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
const RESULT_DELAY := 1.4

var selected_index := 0
var difficulty := 0
var speed_index := 2
var last_result := ""
var show_prompt := true
var _menu: CenterContainer
var _game_buttons: Array[Button] = []
var _difficulty_buttons: Array[Button] = []
var _speed_option: OptionButton
var _result_label: Label
var _launch_button: Button
var _debug_bar: PanelContainer
var _debug_label: Label
var _active: Control
var _hud: Control
var _running := false
var _elapsed := 0.0
var _round_seconds := 0.0
var _run_token := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	UI.apply_theme(self)
	_build_menu()
	_build_debug_bar()
	_apply_cmdline_args()


func _process(delta: float) -> void:
	if _running and is_instance_valid(_active) and _active.can_interact():
		_elapsed += delta


func _unhandled_key_input(event: InputEvent) -> void:
	if get_tree().paused or not _menu.visible or (event is InputEventKey and event.echo):
		return
	if event.is_action_pressed(InputActions.ACTION_UP):
		_select_game(selected_index - 1)
	elif event.is_action_pressed(InputActions.ACTION_DOWN):
		_select_game(selected_index + 1)
	elif event.is_action_pressed(InputActions.ACTION_LEFT):
		_set_difficulty(difficulty - 1)
	elif event.is_action_pressed(InputActions.ACTION_RIGHT):
		_set_difficulty(difficulty + 1)
	elif event.is_action_pressed(InputActions.ACTION_CONFIRM):
		launch()
	else:
		return
	get_viewport().set_input_as_handled()


func launch(index: int = selected_index, new_difficulty: int = difficulty, new_speed_index: int = speed_index) -> void:
	stop()
	_select_game(index)
	_set_difficulty(new_difficulty)
	_set_speed(new_speed_index)
	var entry: Dictionary = MicrogameCatalog.ENTRIES[selected_index]
	var microgame: Variant = MicrogameCatalog.instantiate(entry, difficulty)
	if microgame == null:
		last_result = "Could not load %s" % entry["scene"]
		_result_label.text = last_result
		push_error(last_result)
		return
	var problems := MicrogameCatalog.contract_problems(microgame)
	if not problems.is_empty():
		microgame.free()
		last_result = "%s: %s" % [entry["title"], ", ".join(problems)]
		_result_label.text = last_result
		push_error(last_result)
		return
	microgame.playback_speed = SPEEDS[speed_index]
	microgame.result_seconds = RESULT_DELAY
	if not show_prompt:
		microgame.prompt_seconds = 0.0
	microgame.round_completed.connect(_on_round_completed.bind(_run_token))
	microgame.time_changed.connect(_on_time_changed.bind(_run_token))
	microgame.result_finished.connect(_on_result_finished.bind(_run_token))
	_elapsed = 0.0
	_running = true
	_menu.hide()
	_debug_bar.show()
	_debug_label.text = "TEST  %s | %s | %sx" % [entry["title"], MicrogameCatalog.DIFFICULTY_NAMES[difficulty], _speed_text()]
	_hud = HUD_SCENE.instantiate() as Control
	add_child(_hud)
	_hud.bind_game(microgame)
	_active = microgame
	add_child(microgame)
	_round_seconds = microgame.get_round_duration()
	move_child(_hud, get_child_count() - 1)
	move_child(_debug_bar, get_child_count() - 1)


func stop() -> void:
	_run_token += 1
	_running = false
	if is_instance_valid(_active):
		remove_child(_active)
		_active.queue_free()
	_active = null
	if is_instance_valid(_hud):
		remove_child(_hud)
		_hud.queue_free()
	_hud = null
	_debug_bar.hide()
	_menu.show()
	_result_label.text = last_result if last_result != "" else "Pick a microgame and press Launch."


func _on_time_changed(seconds_left: float, round_seconds: float, token: int = -1) -> void:
	if (token == -1 or token == _run_token) and _running and is_instance_valid(_hud):
		var entry: Dictionary = MicrogameCatalog.ENTRIES[selected_index]
		_hud.set_round_status(seconds_left, round_seconds, 3, 0, 0, 1, 0, 1, entry["title"])


func _on_round_completed(success: bool, token: int = -1) -> void:
	if not _running or (token != -1 and token != _run_token):
		return
	_running = false
	_elapsed = _round_seconds - _active.get_seconds_left()
	var entry: Dictionary = MicrogameCatalog.ENTRIES[selected_index]
	last_result = "Last run: %s | %s | %sx | %s after %.1f s" % [
		entry["title"], MicrogameCatalog.DIFFICULTY_NAMES[difficulty], _speed_text(),
		"WIN" if success else "FAIL", _elapsed,
	]
	print("[launcher] ", last_result)
	_debug_label.text = "WIN" if success else "FAIL"


func _on_result_finished(token: int = -1) -> void:
	if not _running and is_instance_valid(_active) and (token == -1 or token == _run_token):
		stop()

func _select_game(index: int) -> void:
	selected_index = clampi(index, 0, MicrogameCatalog.ENTRIES.size() - 1)
	for i: int in _game_buttons.size():
		_game_buttons[i].button_pressed = i == selected_index


func _set_difficulty(value: int) -> void:
	difficulty = clampi(value, 0, 2)
	for i: int in _difficulty_buttons.size():
		_difficulty_buttons[i].button_pressed = i == difficulty


func _set_speed(index: int) -> void:
	speed_index = clampi(index, 0, SPEEDS.size() - 1)
	if _speed_option != null:
		_speed_option.select(speed_index)


func _speed_text() -> String:
	return str(SPEEDS[speed_index])


## Optional: godot --path . res://scenes/debug/microgame_launcher.tscn -- --microgame=gates --difficulty=2 --speed=1.5
func _apply_cmdline_args() -> void:
	var game_id := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--microgame="):
			game_id = arg.get_slice("=", 1)
		elif arg.begins_with("--difficulty="):
			_set_difficulty(arg.get_slice("=", 1).to_int())
		elif arg.begins_with("--speed="):
			var wanted := arg.get_slice("=", 1).to_float()
			var best := speed_index
			for i: int in SPEEDS.size():
				if absf(SPEEDS[i] - wanted) < absf(SPEEDS[best] - wanted):
					best = i
			_set_speed(best)
	if game_id == "":
		return
	var index := MicrogameCatalog.find_index(game_id)
	if index < 0:
		push_error("Unknown microgame id '%s'" % game_id)
		return
	launch.call_deferred(index, difficulty, speed_index)


func _build_menu() -> void:
	var background := ColorRect.new()
	background.color = Color("#0d1324")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	_menu = CenterContainer.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_menu)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1040.0, 0.0)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#172746"), Color("#e0b341")))
	_menu.add_child(panel)

	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	var title := Label.new()
	title.text = "MICROGAME TEST LAUNCHER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 35)
	UI.shadow(title, 35)
	title.add_theme_color_override("font_color", Color("#f5f7ff"))
	layout.add_child(title)

	var hint := Label.new()
	hint.text = "Debug tool · UP/DOWN microgame · LEFT/RIGHT difficulty · ENTER/SPACE launch"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14)
	UI.shadow(hint, 14)
	hint.add_theme_color_override("font_color", Color("#879ac1"))
	layout.add_child(hint)
	layout.add_child(HSeparator.new())

	var game_group := ButtonGroup.new()
	var game_grid := GridContainer.new()
	game_grid.columns = 2
	game_grid.add_theme_constant_override("h_separation", 12)
	game_grid.add_theme_constant_override("v_separation", 6)
	layout.add_child(game_grid)
	for index: int in MicrogameCatalog.ENTRIES.size():
		var entry: Dictionary = MicrogameCatalog.ENTRIES[index]
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = game_group
		button.text = "%d   %s   (%s)" % [index + 1, entry["title"], entry["day"]]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0.0, 40.0)
		button.add_theme_font_size_override("font_size", 14)
		UI.shadow(button, 14)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_select_game.bind(index))
		button.gui_input.connect(_on_game_button_input.bind(index))
		game_grid.add_child(button)
		_game_buttons.append(button)

	var options := HBoxContainer.new()
	options.add_theme_constant_override("separation", 8)
	layout.add_child(options)
	var difficulty_label := Label.new()
	difficulty_label.text = "Difficulty"
	options.add_child(difficulty_label)
	var difficulty_group := ButtonGroup.new()
	for index: int in MicrogameCatalog.DIFFICULTY_NAMES.size():
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = difficulty_group
		button.text = MicrogameCatalog.DIFFICULTY_NAMES[index]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_set_difficulty.bind(index))
		options.add_child(button)
		_difficulty_buttons.append(button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.add_child(spacer)
	var speed_label := Label.new()
	speed_label.text = "Speed"
	options.add_child(speed_label)
	_speed_option = OptionButton.new()
	_speed_option.focus_mode = Control.FOCUS_NONE
	for speed: float in SPEEDS:
		_speed_option.add_item("%sx" % str(speed))
	_speed_option.item_selected.connect(_set_speed)
	options.add_child(_speed_option)
	var prompt_toggle := CheckBox.new()
	prompt_toggle.text = "Prompt"
	prompt_toggle.button_pressed = show_prompt
	prompt_toggle.focus_mode = Control.FOCUS_NONE
	prompt_toggle.toggled.connect(func(on: bool) -> void: show_prompt = on)
	options.add_child(prompt_toggle)

	_launch_button = Button.new()
	_launch_button.text = "LAUNCH"
	_launch_button.custom_minimum_size = Vector2(0.0, 44.0)
	_launch_button.add_theme_font_size_override("font_size", 28)
	UI.shadow(_launch_button, 28)
	_launch_button.focus_mode = Control.FOCUS_NONE
	_launch_button.pressed.connect(func() -> void: launch())
	layout.add_child(_launch_button)

	_result_label = Label.new()
	_result_label.text = "Pick a microgame and press Launch."
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_label.add_theme_color_override("font_color", Color("#b8c7e6"))
	layout.add_child(_result_label)

	var footer := Label.new()
	footer.text = "Test speed combines with timer assist. Results return here after the game's feedback finishes."
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_theme_font_size_override("font_size", 14)
	UI.shadow(footer, 14)
	footer.add_theme_color_override("font_color", Color("#5f7099"))
	layout.add_child(footer)

	_select_game(selected_index)
	_set_difficulty(difficulty)
	_set_speed(speed_index)


func _on_game_button_input(event: InputEvent, index: int) -> void:
	# Double-click a microgame to launch it immediately.
	if event is InputEventMouseButton and event.double_click and event.button_index == MOUSE_BUTTON_LEFT:
		launch(index)


func _build_debug_bar() -> void:
	_debug_bar = PanelContainer.new()
	_debug_bar.position = Vector2(16.0, 664.0)
	_debug_bar.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_debug_bar.visible = false
	add_child(_debug_bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_debug_bar.add_child(row)
	var stop_button := Button.new()
	stop_button.text = "STOP"
	stop_button.focus_mode = Control.FOCUS_NONE
	UI.flat_button(stop_button, 14)
	stop_button.pressed.connect(stop)
	row.add_child(stop_button)
	_debug_label = Label.new()
	_debug_label.add_theme_font_size_override("font_size", 14)
	UI.shadow(_debug_label, 14)
	_debug_label.add_theme_color_override("font_color", Color("#ffe08a"))
	row.add_child(_debug_label)


func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style
