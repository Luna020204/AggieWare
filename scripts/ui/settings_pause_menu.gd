class_name SettingsPauseMenu
extends CanvasLayer

## Reusable pause/settings overlay for the core game scene.
##
## Add scenes/ui/settings_pause_menu.tscn to any playable scene. GameState owns
## the real pause state; this node only presents and edits that state.

signal menu_closed

var _backdrop: ColorRect
var _center: CenterContainer
var _music_toggle: CheckButton
var _sfx_toggle: CheckButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_build_ui()
	GameState.paused_changed.connect(_on_paused_changed)
	GameState.setting_changed.connect(_on_setting_changed)
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
	add_child(_center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420.0, 0.0)
	_center.add_child(panel)

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
	layout.add_child(title)

	var hint := Label.new()
	hint.text = "Press Escape to resume"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(hint)

	layout.add_child(HSeparator.new())

	_music_toggle = CheckButton.new()
	_music_toggle.text = "Music"
	_music_toggle.toggled.connect(_on_music_toggled)
	layout.add_child(_music_toggle)

	_sfx_toggle = CheckButton.new()
	_sfx_toggle.text = "Sound effects"
	_sfx_toggle.toggled.connect(_on_sfx_toggled)
	layout.add_child(_sfx_toggle)

	layout.add_child(HSeparator.new())

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	layout.add_child(buttons)

	var reset_button := Button.new()
	reset_button.text = "Reset defaults"
	reset_button.pressed.connect(_on_reset_pressed)
	buttons.add_child(reset_button)

	var resume_button := Button.new()
	resume_button.text = "Resume"
	resume_button.pressed.connect(close_menu)
	buttons.add_child(resume_button)


func _on_paused_changed(paused: bool) -> void:
	_backdrop.visible = paused
	_center.visible = paused
	if paused:
		_refresh_settings()
	else:
		menu_closed.emit()


func _on_setting_changed(_setting_name: StringName, _value: Variant) -> void:
	_refresh_settings()


func _refresh_settings() -> void:
	if not is_instance_valid(_music_toggle):
		return
	_music_toggle.button_pressed = GameState.get_setting(&"music_enabled", true)
	_sfx_toggle.button_pressed = GameState.get_setting(&"sfx_enabled", true)


func _on_music_toggled(enabled: bool) -> void:
	GameState.set_setting(&"music_enabled", enabled)


func _on_sfx_toggled(enabled: bool) -> void:
	GameState.set_setting(&"sfx_enabled", enabled)


func _on_reset_pressed() -> void:
	GameState.set_setting(&"music_enabled", true)
	GameState.set_setting(&"sfx_enabled", true)
