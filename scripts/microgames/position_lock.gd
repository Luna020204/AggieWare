extends "res://scripts/core/microgame_base.gd"

const UI := preload("res://scripts/ui/microgame_ui.gd")
const BACKGROUND := preload("res://assets/art/microgames/position_lock/festival_bg.png")
const VESSEL := preload("res://assets/art/microgames/position_lock/vessel.png")
const CAMERA_FRAME := preload("res://assets/art/microgames/position_lock/camera_frame.png")
const DURATIONS := [9.0, 8.0, 7.0]
var _art: Control
var _timer_label: Label
var _status_label: Label
var _elapsed := 0.0

func get_round_seconds() -> float:
	return DURATIONS[clampi(difficulty, 0, 2)]

func _update_intro_progress(elapsed: float, duration: float) -> void:
	_status_label.visible = elapsed >= duration

func _show_result(_success: bool, _message: String) -> void:
	_status_label.hide()
	_art.queue_redraw()

func _draw_backdrop() -> void:
	_art.draw_texture_rect(BACKGROUND, Rect2(0, 0, 1280, 720), false)

func _draw_vessel(at: Vector2) -> void:
	_art.draw_texture_rect(VESSEL, Rect2(at.snapped(Vector2(5, 5)) + Vector2(-40, -25), Vector2(80, 55)), false)

const LOCK_SECONDS := 0.65
const TARGET_SPEEDS := [0.65, 0.9, 1.15]
var camera := Vector2(270, 460)
var vessel := Vector2(790, 500)
var lock_progress := 0.0

func _build_ui() -> void:
	_art = UI.pixel_canvas(self, _draw_world)
	_timer_label = UI.build_header(self, "POSITION LOCK", "MOVE FRAME. HOLD VESSEL INSIDE.", show_internal_timer).timer
	_status_label = UI.label(self, "", Vector2(30, 65), 14, UI.TEXT)

func _reset_game() -> void:
	_elapsed = PI / (2.0 * TARGET_SPEEDS[difficulty])
	camera = Vector2(270, 460)
	vessel = Vector2(790, 500)
	lock_progress = 0.0
	_update_labels()
	_art.queue_redraw()

func _update_game(delta: float) -> void:
	# Substeps require continuous containment, even across a long frame.
	var remaining := delta
	while remaining > 0.0 and not _ended:
		var step := minf(remaining, 1.0 / 120.0)
		remaining -= step
		_elapsed += step
		camera += InputActions.movement_vector() * 680.0 * step
		camera = camera.clamp(Vector2(100, 190), Vector2(1180, 560))
		vessel = Vector2(790 + 170 * cos(_elapsed * TARGET_SPEEDS[difficulty]), 400 + 100 * sin(_elapsed * TARGET_SPEEDS[difficulty]))
		if absf(camera.x - vessel.x) <= 60.0 and absf(camera.y - vessel.y) <= 45.0:
			lock_progress += step
		else:
			lock_progress = 0.0
		if lock_progress >= LOCK_SECONDS:
			_finish_round(true, "VESSEL LOCKED!")
	_update_labels()
	_art.queue_redraw()

func _update_labels() -> void:
	_timer_label.text = "TIME %.1f" % _seconds_left
	_status_label.text = "LOCK %d%%" % mini(100, int(lock_progress / LOCK_SECONDS * 100))

func _draw_world() -> void:
	_draw_backdrop()
	_draw_vessel(vessel)
	var drawn_camera := camera.snapped(Vector2(5, 5))
	var color := UI.SUCCESS if lock_progress > 0.0 else UI.GOLD
	_art.draw_texture_rect(CAMERA_FRAME, Rect2(drawn_camera - Vector2(105, 80), Vector2(215, 165)), false, color)
	_art.draw_rect(Rect2(drawn_camera + Vector2(-100, 95), Vector2(200, 10)), Color("394c68"))
	_art.draw_rect(Rect2(drawn_camera + Vector2(-100, 95), Vector2(200 * minf(lock_progress / LOCK_SECONDS, 1.0), 10)), UI.SUCCESS)
