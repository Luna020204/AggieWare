extends "res://scripts/core/microgame_base.gd"

## Move a blue shield to intercept distracting thoughts until the exam ends.
const UI := preload("res://scripts/ui/microgame_ui.gd")
const DURATIONS: Array[float] = [8.0, 7.0, 6.0]
const SPAWN_INTERVALS: Array[float] = [1.3, 0.95, 0.7]
const SPEEDS: Array[float] = [210.0, 275.0, 335.0]
const MISS_LIMITS: Array[int] = [4, 3, 2]
const THOUGHTS: Array[String] = ["PHONE", "SNACK", "SOCIAL MEDIA", "NAP", "TEXTS"]
const MAX_STEP := 1.0 / 120.0

var _spawn_clock := 0.0
var _blocked := 0
var _missed := 0
var _shield: PanelContainer
var _status_label: Label
var _timer_label: Label
var _thoughts: Array[Control] = []
var _rng := RandomNumberGenerator.new()


func get_round_seconds() -> float:
	return DURATIONS[clampi(difficulty, 0, 2)]


func _input(event: InputEvent) -> void:
	if can_interact() and event is InputEventMouseMotion:
		var local_mouse: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		_shield.position.x = clampf(local_mouse.x - _shield.size.x * 0.5, 30.0, 1080.0)


func _update_game(delta: float) -> void:
	_timer_label.text = "EXAM  %.1f s" % _seconds_left
	var direction := InputActions.get_strength(InputActions.ACTION_RIGHT) - InputActions.get_strength(InputActions.ACTION_LEFT)
	var remaining := maxf(delta, 0.0)
	# Small simulation steps prevent fast thoughts from tunneling through the
	# shield on a slow frame. The base limits delta to the actual round time.
	while remaining > 0.0 and not _ended:
		var step := minf(remaining, MAX_STEP)
		remaining -= step
		_shield.position.x = clampf(_shield.position.x + direction * 650.0 * step, 30.0, 1080.0)
		_spawn_clock += step
		while _spawn_clock >= SPAWN_INTERVALS[difficulty]:
			_spawn_clock -= SPAWN_INTERVALS[difficulty]
			_spawn_thought()
		for thought: Control in _thoughts.duplicate():
			var velocity: Vector2 = thought.get_meta("velocity")
			thought.position += velocity * step
			if Rect2(thought.position, thought.size).intersects(Rect2(_shield.position, _shield.size)):
				_blocked += 1
				_update_status()
				_remove_thought(thought)
			elif thought.position.y > 570.0:
				_missed += 1
				_remove_thought(thought)
				_update_status()
				if _missed >= MISS_LIMITS[difficulty]:
					_finish_round(false, "Too many distractions — refocus and try again!")
					return


func _build_ui() -> void:
	_rng.randomize()
	var header := UI.build_header(self, "STAY FOCUSED", "Move the blue shield with the mouse or Left / Right to block distractions.", show_internal_timer)
	_timer_label = header.timer
	var floor := ColorRect.new()
	floor.color = Color("#2d4b74")
	floor.position = Vector2(40, 610)
	floor.size = Vector2(1200, 4)
	floor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(floor)
	_shield = UI.panel(self, Rect2(555, 550, 170, 50), Color("#2776d0"), Color("#a5d4ff"), 12)
	var shield_label := UI.label(_shield, "FOCUS SHIELD", Vector2.ZERO, 16, UI.TEXT, Vector2.ZERO)
	shield_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shield_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label = UI.label(self, "", Vector2(48, 640), 20, UI.MUTED)


func _reset_game() -> void:
	_blocked = 0
	_missed = 0
	_spawn_clock = 0.0
	_shield.position = Vector2(555, 550)
	UI.set_status(_status_label, "")
	_update_status()
	_timer_label.text = "EXAM  %.1f s" % _seconds_left
	UI.clear_nodes(_thoughts)


func _update_status() -> void:
	_status_label.text = "BLOCKED  %d   MISSED  %d / %d" % [_blocked, _missed, MISS_LIMITS[difficulty]]


func _spawn_thought() -> void:
	var origin := Vector2(_rng.randf_range(50.0, 1070.0), 245.0)
	var velocity := Vector2(0.0, SPEEDS[difficulty])
	if difficulty >= 2:
		match _rng.randi_range(0, 2):
			1:
				origin = Vector2(-130.0, 335.0)
				velocity = Vector2(SPEEDS[difficulty] * 0.8, SPEEDS[difficulty] * 0.7)
			2:
				origin = Vector2(1250.0, 335.0)
				velocity = Vector2(-SPEEDS[difficulty] * 0.8, SPEEDS[difficulty] * 0.7)
	var thought := UI.panel(self, Rect2(origin, Vector2(160, 46)), Color("#a64359"), Color("#a64359"), 8)
	thought.set_meta("velocity", velocity)
	var label := UI.label(thought, THOUGHTS[_rng.randi_range(0, THOUGHTS.size() - 1)], Vector2.ZERO, 16, UI.TEXT, Vector2.ZERO)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_thoughts.append(thought)


func _remove_thought(thought: Control) -> void:
	_thoughts.erase(thought)
	remove_child(thought)
	thought.queue_free()


func _on_timeout() -> void:
	_finish_round(true, "Exam complete — you stayed focused!")


func _show_result(success: bool, message: String) -> void:
	UI.set_status(_status_label, message, "success" if success else "error")
