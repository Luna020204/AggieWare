class_name MicrogameBase
extends Control
## One lifecycle for the week, launcher, and independent F6 play.
const PresentationUI = preload("res://scripts/ui/microgame_ui.gd")
const IntroPresentation = preload("res://scripts/ui/instruction_prompt.gd")
const ResultPresentation = preload("res://scripts/ui/result_cue.gd")
signal round_completed(success: bool)
signal time_changed(seconds_left: float, round_seconds: float)
signal result_finished

@export_range(0, 2, 1) var difficulty := 0
@export var managed_by_flow := false
@export var show_internal_timer := true
@export var prompt := "PLAY"
@export var game_title := ""
@export var instruction_text := ""
@export_range(0.0, 5.0, 0.05) var prompt_seconds := 3.2
@export_range(0.0, 5.0, 0.05) var result_seconds := 1.4
@export_range(0.1, 4.0, 0.1) var playback_speed := 1.0
@export_range(0.0, 120.0, 0.1) var duration_override := 0.0

var _seconds_left := 0.0
var _round_seconds := 0.0
var _ended := false
var _prompt_left := 0.0
var _intro_duration := 0.0
var _result_left := 0.0
var _feedback_left := 0.0
var _feedback_duration := 1.4
var _result_emitted := false
var _playing_started := false
var _prompt_layer: CanvasLayer
var _intro_view: InstructionPrompt
var _result_view: ResultCue
var _feedback_view: ResultCue
var _internal_timers: Array[Control] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	difficulty = clampi(difficulty, 0, 2)
	PresentationUI.apply_theme(self)
	_build_ui()
	_build_presentations()
	GameState.paused_changed.connect(_on_pause_changed)
	if not managed_by_flow:
		add_child(load("res://scenes/ui/settings_pause_menu.tscn").instantiate())
	_start_round()

func _process(delta: float) -> void:
	if not is_inside_tree() or get_tree().paused:
		return
	# Intro and result run at presentation speed; assistance affects play only.
	if _ended:
		if not _result_emitted:
			_result_left = maxf(0.0, _result_left - delta)
			_result_view.set_remaining(_result_left, result_seconds)
			if _result_left <= 0.0:
				_result_emitted = true
				result_finished.emit()
		return
	if _prompt_left > 0.0:
		_prompt_left = maxf(0.0, _prompt_left - delta)
		var elapsed := _intro_duration - _prompt_left
		_update_intro_progress(elapsed, _intro_duration)
		_intro_view.set_progress(elapsed, _intro_duration)
		if _prompt_left <= 0.0: _begin_play()
		return
	if _feedback_left > 0.0:
		_feedback_left = maxf(0.0, _feedback_left - delta / maxf(Engine.time_scale, 0.001))
		_feedback_view.set_remaining(_feedback_left, _feedback_duration)
	var active_delta := minf(maxf(delta, 0.0), _seconds_left)
	_seconds_left = maxf(0.0, _seconds_left - active_delta)
	time_changed.emit(_seconds_left, _round_seconds)
	_update_game(active_delta)
	_update_internal_timer()
	if not _ended and _seconds_left <= 0.0: _on_timeout()

func _unhandled_key_input(event: InputEvent) -> void:
	if managed_by_flow or get_tree().paused or (event is InputEventKey and event.echo): return
	if event.is_action_pressed(InputActions.ACTION_RETRY):
		_start_round()
		get_viewport().set_input_as_handled()

func _start_round() -> void:
	Accessibility.end_microgame(self)
	difficulty = clampi(difficulty, 0, 2)
	_round_seconds = maxf(duration_override if duration_override > 0.0 else get_round_seconds(), 0.01)
	_seconds_left = _round_seconds
	_ended = false
	_playing_started = false
	_result_emitted = false
	_result_left = 0.0
	_feedback_left = 0.0
	_intro_duration = maxf(get_intro_seconds(), 0.0)
	_prompt_left = _intro_duration
	_result_view.hide()
	_feedback_view.hide()
	_intro_view.show()
	_intro_view.modulate.a = 1.0
	_set_timer_visibility(false)
	_reset_game()
	_update_intro_progress(0.0, _intro_duration)
	_intro_view.title_label.text = game_title if not game_title.is_empty() else prompt
	_intro_view.instruction_label.text = instruction_text
	_intro_view.visible = not _ended and _prompt_left > 0.0
	time_changed.emit(_seconds_left, _round_seconds)
	_update_internal_timer()
	if not _ended and _prompt_left <= 0.0: _begin_play()

func _begin_play() -> void:
	if _playing_started or _ended: return
	_playing_started = true
	_prompt_left = 0.0
	_intro_view.hide()
	_update_intro_progress(_intro_duration, _intro_duration)
	_set_timer_visibility(true)
	Accessibility.begin_microgame(playback_speed, self)

func skip_intro() -> void:
	if not _ended and not get_tree().paused and _prompt_left > 0.0: _begin_play()

func _finish_round(success: bool, message: String) -> void:
	if _ended: return
	_ended = true
	_prompt_left = 0.0
	_result_left = maxf(result_seconds, 0.0)
	_feedback_left = 0.0
	_intro_view.hide()
	_feedback_view.hide()
	_set_timer_visibility(false)
	_update_intro_progress(_intro_duration, _intro_duration)
	Accessibility.end_microgame(self)
	_show_result(success, message)
	var symbol := "✓ " if success else "✗ "
	var result_message := message if message.begins_with("✓") or message.begins_with("✗") else symbol + message
	_result_view.present(result_message, PresentationUI.SUCCESS if success else PresentationUI.ERROR, 42, true, success)
	round_completed.emit(success)
	# Zero-duration results still finish on a later process step, after completion.

func show_feedback(message: String, color: Color = PresentationUI.REJECT, duration: float = 1.4) -> void:
	if not can_interact(): return
	_feedback_duration = maxf(duration, 0.01)
	_feedback_left = _feedback_duration
	var marked := message
	if not message.begins_with("✓") and not message.begins_with("✗") and not message.begins_with("▲") and not message.begins_with("▼"):
		marked = ("✓ " if color == PresentationUI.SUCCESS else "✗ ") + message
	_feedback_view.present(marked, color, 28, false)

func can_interact() -> bool:
	return is_inside_tree() and not get_tree().paused and not _ended and _playing_started and _prompt_left <= 0.0 and _seconds_left > 0.0

func get_seconds_left() -> float: return _seconds_left
func get_round_duration() -> float: return _round_seconds
func is_round_finished() -> bool: return _ended
func is_playing() -> bool: return _playing_started and not _ended
func uses_native_hud() -> bool: return false
func get_round_seconds() -> float: return [9.0, 8.0, 7.0][difficulty]
func get_intro_seconds() -> float: return prompt_seconds
func get_intro_rect() -> Rect2: return Rect2(40, 230, 1200, 230)
func has_establishing_scene() -> bool: return false
func _build_ui() -> void: pass
func _reset_game() -> void: pass
func _update_game(_delta: float) -> void: pass
func _update_intro_progress(_elapsed: float, _duration: float) -> void: pass
func _on_pause_changed(_paused: bool) -> void: pass
func _show_result(_success: bool, _message: String) -> void: pass
func _on_timeout() -> void: _finish_round(false, "Time's up!")

func _exit_tree() -> void:
	Accessibility.end_microgame(self)

func _build_presentations() -> void:
	_prompt_layer = CanvasLayer.new()
	_prompt_layer.name = "RoundPresentation"
	_prompt_layer.layer = 50
	add_child(_prompt_layer)
	_intro_view = IntroPresentation.new()
	_intro_view.title_text = game_title
	_intro_view.instruction = instruction_text
	_intro_view.text_rect = get_intro_rect()
	_intro_view.dimmed = not has_establishing_scene()
	_prompt_layer.add_child(_intro_view)
	_intro_view.finished.connect(skip_intro)
	_intro_view.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and not get_tree().paused:
			skip_intro()
			get_viewport().set_input_as_handled())
	_feedback_view = ResultPresentation.new()
	_feedback_view.name = "ActionFeedback"
	_prompt_layer.add_child(_feedback_view)
	_result_view = ResultPresentation.new()
	_result_view.name = "RoundResult"
	_prompt_layer.add_child(_result_view)
	for child in find_children("InternalTimer", "Control", true, false):
		_internal_timers.append(child)
	if _internal_timers.is_empty():
		var timer := PresentationUI.label(self, "", Vector2(30, 25), 28, PresentationUI.ACCENT, Vector2(500, 35))
		timer.name = "InternalTimer"
		_internal_timers.append(timer)

func _set_timer_visibility(playing: bool) -> void:
	for timer in _internal_timers: timer.visible = playing and show_internal_timer

func _update_internal_timer() -> void:
	for timer in _internal_timers:
		if timer is Label:
			timer.text = ("! " if _seconds_left <= 3.0 and Accessibility.result_cues_enabled() else "") + "TIME %.1f" % _seconds_left
