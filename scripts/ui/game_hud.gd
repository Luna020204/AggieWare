extends Control

## Shared, read-only status display for an active microgame (SCRUM-40).

var _timer_label: Label
var _lives_label: Label
var _score_label: Label
var _progress_label: Label
var _timer_bar: ProgressBar


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()


func set_round_status(seconds_left: float, round_seconds: float, lives: int, score: int, stage_index: int, stage_count: int) -> void:
	_timer_label.text = "TIME  %.1f" % maxf(seconds_left, 0.0)
	# SCRUM-41: low-time warning that does not rely on the red colour alone.
	if seconds_left <= 3.0 and Accessibility.result_cues_enabled():
		_timer_label.text = "⚠ " + _timer_label.text
	_lives_label.text = "LIVES  %d" % maxi(lives, 0)
	_score_label.text = "SCORE  %d" % score
	_progress_label.text = "DAY  %d / %d" % [stage_index + 1, stage_count]
	_timer_bar.value = 100.0 * clampf(seconds_left / maxf(round_seconds, 0.01), 0.0, 1.0)
	_timer_label.add_theme_color_override("font_color", Color("#ff9e9e") if seconds_left <= 3.0 else Color("#f5f7ff"))


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(640.0, 24.0)
	panel.size = Vector2(592.0, 108.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#172746")
	style.border_color = Color("#73b7ff")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(layout)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 18)
	layout.add_child(row)
	_timer_label = _add_label(row)
	_lives_label = _add_label(row)
	_score_label = _add_label(row)
	_progress_label = _add_label(row)
	_timer_bar = ProgressBar.new()
	_timer_bar.show_percentage = false
	_timer_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timer_bar.custom_minimum_size.y = 20.0
	var bar_background := StyleBoxFlat.new()
	bar_background.bg_color = Color("#0d1324")
	bar_background.set_corner_radius_all(6)
	_timer_bar.add_theme_stylebox_override("background", bar_background)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color("#55d69b")
	bar_fill.set_corner_radius_all(6)
	_timer_bar.add_theme_stylebox_override("fill", bar_fill)
	layout.add_child(_timer_bar)


func _add_label(row: HBoxContainer) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color("#f5f7ff"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	return label
