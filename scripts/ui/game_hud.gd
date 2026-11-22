extends Control
## The play HUD is a bare timer. Score, lives, and progress remain flow data.
const UI = preload("res://scripts/ui/microgame_ui.gd")
var _timer_label: Label
var _seconds_left := 0.0
var _game: Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.apply_theme(self)
	_timer_label = UI.label(self, "", Vector2(30, 25), 28, UI.ACCENT, Vector2(500, 35))
	hide()

func _process(_delta: float) -> void:
	_refresh_visibility()

func bind_game(game: Control) -> void:
	_game = game
	_refresh_visibility()

func set_round_status(seconds_left: float, _round_seconds: float, _lives: int, _score: int, _stage_index: int, _stage_count: int, _round_index: int = 0, _round_count: int = 1, _game_title: String = "") -> void:
	_seconds_left = maxf(seconds_left, 0.0)
	_timer_label.text = ("! " if seconds_left <= 3.0 and Accessibility.result_cues_enabled() else "") + "TIME %.1f" % _seconds_left
	_refresh_visibility()

func _refresh_visibility() -> void:
	if is_instance_valid(_game) and _game.is_inside_tree():
		visible = _game.is_playing() and not _game.uses_native_hud()
	else:
		hide()
