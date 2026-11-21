extends Node2D
## Original placeholder art; replace SpriteFrames without changing the controller API.

const SHEET = preload("res://assets/art/player_placeholder.svg")
const CONTROLLER = preload("res://scripts/core/player_animation_controller.gd")


func _enter_tree() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for row in range(CONTROLLER.STATES.size()):
		var state: StringName = CONTROLLER.STATES[row]
		frames.add_animation(state)
		frames.set_animation_speed(state, 6.0 if state == &"idle" else 10.0)
		frames.set_animation_loop(state, state != &"success" and state != &"fail")
		for column in range(4):
			var texture := AtlasTexture.new()
			texture.atlas = SHEET
			texture.region = Rect2(column * 96, row * 96, 96, 96)
			frames.add_frame(state, texture)
	$Sprite.sprite_frames = frames
