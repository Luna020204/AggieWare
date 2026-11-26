extends "res://scripts/core/microgame_base.gd"

const UI := preload("res://scripts/ui/microgame_ui.gd")
const BACKGROUND := preload("res://assets/art/microgames/shield_break/festival_bg.png")
const VESSEL := preload("res://assets/art/microgames/shield_break/vessel.png")
const SHIELD := preload("res://assets/art/microgames/shield_break/shield.png")
const GUN := preload("res://assets/art/microgames/shield_break/gun.png")
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
	_art.draw_texture_rect(VESSEL, Rect2(at + Vector2(-40, -25), Vector2(80, 55)), false)

const REQUIRED_HITS := [6, 9, 12]
var gun_x := 300.0
var target_x := 850.0
var hits := 0
var _beam_left := 0.0
var _beam_x := 0.0
var _beam_hit := false

func _build_ui() -> void:
	_art = UI.pixel_canvas(self, _draw_world)
	_timer_label = UI.build_header(self, "SHIELD BREAK", "AIM AT SHIELD. MASH ACTION.", show_internal_timer).timer
	_status_label = UI.label(self, "", Vector2(30, 65), 14, UI.TEXT)

func _reset_game() -> void:
	_elapsed = 0.0
	gun_x = 300.0
	target_x = 850.0
	hits = 0
	_beam_left = 0.0
	_update_labels()
	_art.queue_redraw()

func _update_game(delta: float) -> void:
	_elapsed += delta
	gun_x = clampf(gun_x + (InputActions.get_strength(InputActions.ACTION_RIGHT) - InputActions.get_strength(InputActions.ACTION_LEFT)) * 650.0 * delta, 80.0, 1200.0)
	_beam_left = maxf(0.0, _beam_left - delta)
	if InputActions.is_just_pressed(InputActions.ACTION_MASH):
		fire()
	_update_labels()
	_art.queue_redraw()

func fire() -> void:
	if not can_interact():
		return
	_beam_left = 0.09
	_beam_x = gun_x
	_beam_hit = absf(gun_x - target_x) <= 100.0
	if _beam_hit:
		hits += 1
		if hits >= REQUIRED_HITS[difficulty]:
			_finish_round(true, "SHIELD DOWN!")
	_update_labels()
	_art.queue_redraw()

func _update_labels() -> void:
	_timer_label.text = "TIME %.1f" % _seconds_left
	_status_label.text = "AIM %s / %s   FIRE %s   SHIELD %d" % [InputActions.action_label(InputActions.ACTION_LEFT), InputActions.action_label(InputActions.ACTION_RIGHT), InputActions.action_label(InputActions.ACTION_MASH), maxi(0, REQUIRED_HITS[difficulty] - hits)]

func _draw_world() -> void:
	_draw_backdrop()
	_draw_vessel(Vector2(target_x, 265))
	var remaining: float = 1.0 - float(hits) / REQUIRED_HITS[difficulty]
	if remaining > 0.0:
		_art.draw_texture_rect(SHIELD, Rect2(target_x - 105, 205, 210, 120), false, UI.SUCCESS if _beam_hit and _beam_left > 0.0 else Color("58b9e5"))
	_art.draw_rect(Rect2(target_x - 100, 170, 200, 15), Color("394c68"))
	_art.draw_rect(Rect2(target_x - 100, 170, 200 * remaining, 15), UI.SUCCESS)
	var aligned := absf(gun_x - target_x) <= 100.0
	for y in range(340, 570, 30):
		_art.draw_rect(Rect2(gun_x - 2, y, 5, 10), Color("46715c") if aligned else Color("3b4d6b"))
	if _beam_left > 0.0:
		_art.draw_rect(Rect2(_beam_x - 5, 320 if _beam_hit else 120, 10, 260 if _beam_hit else 460), UI.GOLD)
	_art.draw_texture_rect(GUN, Rect2(gun_x - 45, 550, 90, 85), false)
	_art.draw_rect(Rect2(gun_x - 10, 550, 20, 40), UI.SUCCESS if aligned else UI.GOLD)
