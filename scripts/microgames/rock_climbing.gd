extends "res://scripts/core/microgame_base.gd"
const UI = preload("res://scripts/ui/microgame_ui.gd")
const WALL = preload("res://assets/art/microgames/rock_climbing/wall.png")
const CLIMBER = preload("res://assets/art/microgames/rock_climbing/climber.png")
const HOLD = preload("res://assets/art/microgames/rock_climbing/hold.png")
const COUNTS = [3, 4, 5]
const SWINGS = [0.65, 0.9, 1.15]
const RADII = [38.0, 30.0, 24.0]
var holds: Array[Vector2] = []
var reached := 0
var angle := 0.0
var clock := 0.0
var cooldown := 0.0
var art: Control
var meter: Label
var timer: Label

func get_round_seconds() -> float: return 9.0 - difficulty

func _build_ui() -> void:
	art = UI.pixel_canvas(self, _draw_wall)
	var header := UI.build_header(self, "ARC ROCK CLIMBING", "ROTATE LEFT / RIGHT. ACTION: GRAB.", show_internal_timer)
	timer = header.timer
	meter = UI.label(self, "", Vector2(30, 65), 14, UI.TEXT, Vector2(500, 25))

func _reset_game() -> void:
	instruction_text = "ROTATE %s / %s. %s: GRAB." % [InputActions.action_label(InputActions.ACTION_LEFT), InputActions.action_label(InputActions.ACTION_RIGHT), InputActions.action_label(InputActions.ACTION_MASH)]
	holds.clear()
	holds.append(Vector2(640, 590))
	for i in COUNTS[difficulty]:
		holds.append(holds[-1] + Vector2(50 if i % 2 == 0 else -50, -75))
	reached = 0
	angle = 0.0
	clock = 0.0
	cooldown = 0.0
	_refresh()

func hand_position() -> Vector2:
	return holds[reached] + Vector2(sin(angle), -cos(angle)) * 90.0

func _update_game(delta: float) -> void:
	clock += delta
	cooldown = maxf(0, cooldown - delta)
	var steer := InputActions.get_strength(InputActions.ACTION_RIGHT) - InputActions.get_strength(InputActions.ACTION_LEFT)
	angle = clampf(angle + (steer * 2.6 + cos(clock * 3.0) * SWINGS[difficulty]) * delta, -1.2, 1.2)
	if InputActions.is_just_pressed(InputActions.ACTION_MASH): try_latch()
	_refresh()

func try_latch() -> void:
	if not can_interact() or cooldown > 0 or reached >= holds.size()-1: return
	cooldown = 0.18
	if hand_position().distance_to(holds[reached+1]) <= RADII[difficulty]:
		reached += 1
		angle = 0.0
		if reached == holds.size()-1: _finish_round(true, "TOPPED OUT!")
	_refresh()

func _refresh() -> void:
	if meter == null: return
	meter.text = "HOLDS %d / %d" % [reached, COUNTS[difficulty]]
	timer.text = "TIME %.1f" % _seconds_left
	art.queue_redraw()

func _draw_wall() -> void:
	art.draw_texture_rect(WALL, Rect2(0, 0, 1280, 720), false)
	if holds.is_empty(): return
	for i in holds.size():
		var at := holds[i].snapped(Vector2(5,5))
		var radius: float = RADII[difficulty]
		var tint := Color("ffd34e") if i == reached+1 else Color("709eaa")
		art.draw_texture_rect(HOLD, Rect2(at-Vector2.ONE*radius, Vector2.ONE*radius*2), false, tint)
	var anchor := holds[reached].snapped(Vector2(5,5))
	# Render rotation on the low-resolution canvas so every pixel stays on-grid.
	art.draw_set_transform(anchor, angle)
	art.draw_texture_rect(CLIMBER, Rect2(-30, -90, 60, 110), false)
	art.draw_set_transform(Vector2.ZERO)
	var flag := holds[-1] + Vector2(45, -35)
	art.draw_line(flag, flag+Vector2(0,45), Color.WHITE, 5)
	art.draw_rect(Rect2(flag, Vector2(35,20)), Color("ffcb35"))
