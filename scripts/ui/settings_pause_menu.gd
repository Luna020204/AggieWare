class_name SettingsPauseMenu
extends CanvasLayer

## Reusable pause/settings overlay for the core game scene.
##
## Add scenes/ui/settings_pause_menu.tscn to any playable scene. GameState owns
## the real pause state; this node only presents and edits that state.

signal menu_closed
const UI := preload("res://scripts/ui/microgame_ui.gd")

var _backdrop: ColorRect
var _center: CenterContainer
var _music_toggle: CheckButton
var _sfx_toggle: CheckButton
var _pause_hint: Label
var _resume_button: Button
var _previous_focus: WeakRef
# SCRUM-41 accessibility controls.
var _timer_assist_option: OptionButton
var _result_cues_toggle: CheckButton
# SCRUM-57 control options.
var _main_panel: PanelContainer
var _controls_panel: PanelContainer
var _bind_buttons: Dictionary = {}
var _mash_hold_toggle: CheckButton
var _controls_status: Label
var _waiting_action: StringName = &""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_build_ui()
	_build_controls_panel()
	GameState.paused_changed.connect(_on_paused_changed)
	GameState.setting_changed.connect(_on_setting_changed)
	SettingsStore.bindings_changed.connect(_refresh_bindings)
	_on_paused_changed(GameState.is_paused)


func open_menu() -> void:
	GameState.pause_game()


func close_menu() -> void:
	GameState.resume_game()


func toggle_menu() -> void:
	GameState.toggle_pause()


func _build_ui() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.02, 0.03, 0.08, 0.78)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)

	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UI.apply_theme(_center)
	add_child(_center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420.0, 0.0)
	_center.add_child(panel)
	_main_panel = panel

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	var title := Label.new()
	title.text = "Pause / Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	UI.shadow(title, 28)
	layout.add_child(title)

	_pause_hint = Label.new()
	_pause_hint.text = "Press %s to resume" % InputActions.action_label(InputActions.ACTION_PAUSE)
	_pause_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(_pause_hint)

	layout.add_child(HSeparator.new())

	_music_toggle = CheckButton.new()
	_music_toggle.text = "Music"
	_music_toggle.toggled.connect(_on_music_toggled)
	layout.add_child(_music_toggle)

	_sfx_toggle = CheckButton.new()
	_sfx_toggle.text = "Sound effects"
	_sfx_toggle.toggled.connect(_on_sfx_toggled)
	layout.add_child(_sfx_toggle)

	_build_accessibility_section(layout)

	layout.add_child(HSeparator.new())

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	layout.add_child(buttons)

	var controls_button := Button.new()
	controls_button.text = "Controls…"
	controls_button.pressed.connect(_show_controls.bind(true))
	buttons.add_child(controls_button)

	var reset_button := Button.new()
	reset_button.text = "Reset defaults"
	reset_button.pressed.connect(_on_reset_pressed)
	buttons.add_child(reset_button)

	_resume_button = Button.new()
	_resume_button.text = "Resume"
	_resume_button.pressed.connect(close_menu)
	buttons.add_child(_resume_button)


func _on_paused_changed(paused: bool) -> void:
	if paused:
		var focus_owner := get_viewport().gui_get_focus_owner()
		_previous_focus = weakref(focus_owner) if focus_owner != null else null
	_backdrop.visible = paused
	_center.visible = paused
	_show_controls(false)
	if paused:
		_refresh_settings()
		_resume_button.grab_focus()
	else:
		if _previous_focus != null:
			var focus_owner := _previous_focus.get_ref() as Control
			if is_instance_valid(focus_owner) and focus_owner.is_visible_in_tree():
				focus_owner.grab_focus()
		_previous_focus = null
		menu_closed.emit()


func _on_setting_changed(_setting_name: StringName, _value: Variant) -> void:
	_refresh_settings()


func _refresh_settings() -> void:
	if not is_instance_valid(_music_toggle):
		return
	_pause_hint.text = "Press %s to resume" % InputActions.action_label(InputActions.ACTION_PAUSE)
	_music_toggle.set_pressed_no_signal(GameState.get_setting(&"music_enabled", true))
	_sfx_toggle.set_pressed_no_signal(GameState.get_setting(&"sfx_enabled", true))
	_timer_assist_option.select(maxi(Accessibility.TIMER_ASSIST_LEVELS.find(Accessibility.timer_assist()), 0))
	_result_cues_toggle.set_pressed_no_signal(Accessibility.result_cues_enabled())
	_mash_hold_toggle.set_pressed_no_signal(GameState.get_setting(&"mash_hold", false))


func _on_music_toggled(enabled: bool) -> void:
	GameState.set_setting(&"music_enabled", enabled)


func _on_sfx_toggled(enabled: bool) -> void:
	GameState.set_setting(&"sfx_enabled", enabled)


func _on_reset_pressed() -> void:
	GameState.set_setting(&"music_enabled", true)
	GameState.set_setting(&"sfx_enabled", true)
	GameState.set_setting(&"timer_assist", 1.0)
	GameState.set_setting(&"result_cues", true)
	GameState.set_setting(&"mash_hold", false)


## SCRUM-41: accessibility options (timer assist, shape + word result cues).
func _build_accessibility_section(layout: VBoxContainer) -> void:
	layout.add_child(HSeparator.new())
	var heading := Label.new()
	heading.text = "Accessibility"
	layout.add_child(heading)

	var assist_row := HBoxContainer.new()
	layout.add_child(assist_row)
	var assist_label := Label.new()
	assist_label.text = "Timer assist"
	assist_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	assist_row.add_child(assist_label)
	_timer_assist_option = OptionButton.new()
	for level_name: String in Accessibility.TIMER_ASSIST_NAMES:
		_timer_assist_option.add_item(level_name)
	_timer_assist_option.tooltip_text = "Slows every microgame down so each round lasts longer."
	_timer_assist_option.item_selected.connect(_on_timer_assist_selected)
	assist_row.add_child(_timer_assist_option)

	_result_cues_toggle = CheckButton.new()
	_result_cues_toggle.text = "Result symbols and low-time warning"
	_result_cues_toggle.toggled.connect(_on_result_cues_toggled)
	layout.add_child(_result_cues_toggle)


func _on_timer_assist_selected(index: int) -> void:
	GameState.set_setting(&"timer_assist", Accessibility.TIMER_ASSIST_LEVELS[index])


func _on_result_cues_toggled(enabled: bool) -> void:
	GameState.set_setting(&"result_cues", enabled)


## SCRUM-57: key rebinding and alternative input options.
func _build_controls_panel() -> void:
	_controls_panel = PanelContainer.new()
	_controls_panel.custom_minimum_size = Vector2(700.0, 0.0)
	_controls_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#141a2b")
	style.border_color = Color("#73b7ff")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	_controls_panel.add_theme_stylebox_override("panel", style)
	_center.add_child(_controls_panel)

	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	_controls_panel.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	var title := Label.new()
	title.text = "Controls"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	UI.shadow(title, 28)
	layout.add_child(title)
	var hint := Label.new()
	hint.text = "Click a key, then press the new key. Escape cancels."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14)
	UI.shadow(hint, 14)
	layout.add_child(hint)
	layout.add_child(HSeparator.new())

	for action: StringName in SettingsStore.REBINDABLE:
		var row := HBoxContainer.new()
		layout.add_child(row)
		var label := Label.new()
		label.text = SettingsStore.ACTION_LABELS[action]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var bind_button := Button.new()
		bind_button.custom_minimum_size = Vector2(170.0, 0.0)
		bind_button.pressed.connect(_start_rebind.bind(action))
		row.add_child(bind_button)
		_bind_buttons[action] = bind_button

	_mash_hold_toggle = CheckButton.new()
	_mash_hold_toggle.text = "Hold instead of mash"
	_mash_hold_toggle.tooltip_text = "Holding the mash key counts as repeated presses."
	_mash_hold_toggle.toggled.connect(func(on: bool) -> void: GameState.set_setting(&"mash_hold", on))
	layout.add_child(_mash_hold_toggle)

	_controls_status = Label.new()
	_controls_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_controls_status.custom_minimum_size = Vector2(400.0, 0.0)
	layout.add_child(_controls_status)

	layout.add_child(HSeparator.new())
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	layout.add_child(buttons)
	var reset_keys := Button.new()
	reset_keys.text = "Reset keys"
	reset_keys.pressed.connect(func() -> void:
		SettingsStore.reset_bindings()
		_controls_status.text = "Keys reset to defaults."
		_refresh_bindings()
	)
	buttons.add_child(reset_keys)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(_show_controls.bind(false))
	buttons.add_child(back)
	_refresh_bindings()


func _show_controls(open: bool) -> void:
	if _controls_panel == null:
		return
	_waiting_action = &""
	_main_panel.visible = not open
	_controls_panel.visible = open
	if open:
		_controls_status.text = ""
		_refresh_bindings()
		var first_button: Button = _bind_buttons[SettingsStore.REBINDABLE[0]]
		first_button.grab_focus()
	elif GameState.is_paused:
		_resume_button.grab_focus()


func _refresh_bindings() -> void:
	if is_instance_valid(_pause_hint):
		_pause_hint.text = "Press %s to resume" % InputActions.action_label(InputActions.ACTION_PAUSE)
	for action: StringName in _bind_buttons:
		var button: Button = _bind_buttons[action]
		button.text = "Press a key…" if action == _waiting_action else SettingsStore.describe(action)


func _start_rebind(action: StringName) -> void:
	_waiting_action = action
	_controls_status.text = "Press the new key for %s." % SettingsStore.ACTION_LABELS[action]
	_refresh_bindings()


func _input(event: InputEvent) -> void:
	if not GameState.is_paused or _waiting_action == &"" or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	if event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE:
		_controls_status.text = "Cancelled."
	else:
		var clash := SettingsStore.conflicts(_waiting_action, event)
		SettingsStore.rebind(_waiting_action, event)
		_controls_status.text = "%s → %s" % [SettingsStore.ACTION_LABELS[_waiting_action], SettingsStore.describe(_waiting_action)]
		if not clash.is_empty():
			_controls_status.text += "  (also used by %s)" % ", ".join(clash)
	_waiting_action = &""
	_refresh_bindings()
