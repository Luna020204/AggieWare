class_name PlayerAnimationController
extends Node
## Presentation-only component for SCRUM-29's character. Does not own input or physics.

signal state_changed(state: StringName)
signal outcome_finished(state: StringName)

const STATES: Array[StringName] = [&"idle", &"biking", &"typing", &"success", &"fail"]
const MAX_SPEED: float = 3.0

@export var sprite: AnimatedSprite2D
var current_state: StringName = &"idle"
var playback_speed: float = 1.0
var _outcome_locked: bool = false


func _ready() -> void:
	if not is_instance_valid(sprite):
		push_warning("PlayerAnimationController needs an AnimatedSprite2D.")
		return
	sprite.animation_finished.connect(_on_animation_finished)
	_play(true)


## Returns false for unknown states, missing clips, or gameplay updates after an outcome.
## Repeated activity updates do not restart the clip.
func set_state(state: StringName) -> bool:
	if state not in STATES or not _has_clip(state):
		return false
	if _outcome_locked:
		return state == current_state
	if state == current_state:
		return true
	current_state = state
	_outcome_locked = state == &"success" or state == &"fail"
	_play(true)
	state_changed.emit(current_state)
	return true


## Difficulty is a 1-based level; presentation speed never changes Engine.time_scale.
func set_difficulty(level: float) -> void:
	if not is_finite(level):
		return
	playback_speed = clampf(1.0 + 0.15 * (maxf(level, 1.0) - 1.0), 1.0, MAX_SPEED)
	if is_instance_valid(sprite):
		sprite.speed_scale = playback_speed


## Call at the start of each microgame, including when reusing the same character.
func reset_for_microgame(difficulty: float = 1.0) -> void:
	_outcome_locked = false
	current_state = &"idle"
	set_difficulty(difficulty)
	_play(true)
	state_changed.emit(current_state)


func set_facing_left(facing_left: bool) -> void:
	if is_instance_valid(sprite):
		sprite.flip_h = facing_left


func _has_clip(state: StringName) -> bool:
	return (is_instance_valid(sprite) and sprite.sprite_frames != null
		and sprite.sprite_frames.has_animation(state)
		and sprite.sprite_frames.get_frame_count(state) > 0)


func _play(restart: bool) -> void:
	if not _has_clip(current_state):
		return
	sprite.speed_scale = playback_speed
	if restart:
		sprite.stop()
	sprite.play(current_state)


func _on_animation_finished() -> void:
	if _outcome_locked and sprite.animation == current_state:
		outcome_finished.emit(current_state)
