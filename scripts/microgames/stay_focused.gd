extends "res://scripts/core/microgame_base.gd"

## Move a blue shield to intercept distracting thoughts until the exam ends.
const UI := preload("res://scripts/ui/microgame_ui.gd")
const DURATIONS: Array[float] = [10.0, 9.0, 8.0]
const SPAWN_INTERVALS: Array[float] = [1.3, 0.95, 0.7]
const END_INTERVAL_RATIO := 0.65
const SPEEDS: Array[float] = [210.0, 275.0, 335.0]
const MISS_LIMITS: Array[int] = [4, 3, 2]
const THOUGHTS: Array[String] = ["PHONE", "SNACK", "SOCIAL MEDIA", "NAP", "TEXTS"]
const MAX_STEP := 1.0 / 120.0

var _spawn_clock := 0.0
var _game_elapsed := 0.0
var _blocked := 0
var _missed := 0
var _shield: Control
var _art: Control
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
	_timer_label.text = "TIME %.1f" % _seconds_left
	_art.queue_redraw()
	var direction := InputActions.get_strength(InputActions.ACTION_RIGHT) - InputActions.get_strength(InputActions.ACTION_LEFT)
	var remaining := maxf(delta, 0.0)
	# Small simulation steps prevent fast thoughts from tunneling through the
	# shield on a slow frame. The base limits delta to the actual round time.
	while remaining > 0.0 and not _ended:
		var step := minf(remaining, MAX_STEP)
		remaining -= step
		_game_elapsed += step
		_shield.position.x = clampf(_shield.position.x + direction * 650.0 * step, 30.0, 1080.0)
		_spawn_clock += step
		# More distractions arrive as the exam runs out, at every difficulty.
		var progress := clampf(_game_elapsed / _round_seconds, 0.0, 1.0)
		var interval := SPAWN_INTERVALS[difficulty] * lerpf(1.0, END_INTERVAL_RATIO, progress)
		while _spawn_clock >= interval:
			_spawn_clock -= interval
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
					_finish_round(false, "TOO MANY DISTRACTIONS!")
					return


func _build_ui() -> void:
	_rng.randomize()
	UI.add_backdrop(self, "lecture")
	_art = UI.pixel_canvas(self, _draw_world)
	var header := UI.build_header(self, "STAY FOCUSED", "MOVE LEFT / RIGHT TO BLOCK.", show_internal_timer)
	_timer_label = header.timer
	_shield = Control.new()
	_shield.position = Vector2(555, 550)
	_shield.size = Vector2(170, 50)
	_shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shield)
	_status_label = UI.label(self, "", Vector2(30, 65), 14, UI.TEXT, Vector2(600, 20))


func _draw_world() -> void:
	if not is_instance_valid(_shield):
		return
	var book := _shield.position
	_art.draw_rect(Rect2(book + Vector2(-5, 5), Vector2(180, 50)), Color("19406a"))
	_art.draw_rect(Rect2(book, Vector2(80, 45)), Color("79b5c9"))
	_art.draw_rect(Rect2(book + Vector2(90, 0), Vector2(80, 45)), Color("9ad2db"))
	_art.draw_rect(Rect2(book + Vector2(80, 0), Vector2(10, 50)), Color("e6c373"))
	for line in 3:
		_art.draw_rect(Rect2(book + Vector2(10, 10 + line * 10), Vector2(55, 5)), Color("437b9a"))
		_art.draw_rect(Rect2(book + Vector2(100, 10 + line * 10), Vector2(55, 5)), Color("6198aa"))
	for thought: Control in _thoughts:
		var at := thought.position
		match int(thought.get_meta("sprite", 0)):
			0, 4:
				_art.draw_rect(Rect2(at + Vector2(20, 0), Vector2(60, 55)), Color("263047"))
				_art.draw_rect(Rect2(at + Vector2(25, 5), Vector2(50, 35)), Color("77b8c0"))
				_art.draw_rect(Rect2(at + Vector2(40, 45), Vector2(20, 5)), Color("ffbf00"))
			1:
				_art.draw_rect(Rect2(at + Vector2(15, 5), Vector2(70, 45)), Color("d69b51"))
				_art.draw_rect(Rect2(at + Vector2(15, 0), Vector2(70, 10)), Color("f0c37a"))
				_art.draw_rect(Rect2(at + Vector2(25, 20), Vector2(50, 15)), Color("b75d42"))
			2:
				_art.draw_rect(Rect2(at + Vector2(5, 0), Vector2(90, 40)), Color("ad83b3"))
				_art.draw_rect(Rect2(at + Vector2(20, 35), Vector2(20, 15)), Color("ad83b3"))
				for dot in 3:
					_art.draw_rect(Rect2(at + Vector2(25 + dot * 20, 15), Vector2(10, 10)), Color("ead6ce"))
			3:
				_art.draw_rect(Rect2(at + Vector2(15, 0), Vector2(70, 10)), Color("d2d2e4"))
				_art.draw_line(at + Vector2(75, 10), at + Vector2(25, 40), Color("d2d2e4"), 10)
				_art.draw_rect(Rect2(at + Vector2(15, 40), Vector2(70, 10)), Color("d2d2e4"))

func _reset_game() -> void:
	_blocked = 0
	_missed = 0
	_spawn_clock = 0.0
	_game_elapsed = 0.0
	_shield.position = Vector2(555, 550)
	UI.set_status(_status_label, "")
	_update_status()
	_timer_label.text = "TIME %.1f" % _seconds_left
	UI.clear_nodes(_thoughts)
	_art.queue_redraw()


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
	var thought := Control.new()
	thought.position = origin
	thought.size = Vector2(100, 55)
	thought.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thought.set_meta("velocity", velocity)
	thought.set_meta("sprite", _rng.randi_range(0, THOUGHTS.size() - 1))
	add_child(thought)
	_thoughts.append(thought)
	_art.queue_redraw()

func _remove_thought(thought: Control) -> void:
	_thoughts.erase(thought)
	remove_child(thought)
	thought.queue_free()


func _on_timeout() -> void:
	_finish_round(true, "YOU STAYED FOCUSED!")


func _update_intro_progress(elapsed: float, duration: float) -> void:
	_status_label.visible = duration <= 0.0 or elapsed >= duration


func _show_result(_success: bool, _message: String) -> void:
	_status_label.hide()
	_art.queue_redraw()
