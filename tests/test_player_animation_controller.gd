extends SceneTree

const CHARACTER = preload("res://scenes/core/animated_character.tscn")
const CONTROLLER = preload("res://scripts/core/player_animation_controller.gd")
var failures: int = 0
var finished_count: int = 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	var character = CHARACTER.instantiate()
	root.add_child(character)
	var controller = character.get_node("AnimationController")
	var sprite: AnimatedSprite2D = character.get_node("Sprite")
	check(sprite.animation == &"idle" and sprite.is_playing(), "Starts in idle")
	for state in [&"biking", &"typing", &"idle"]:
		check(controller.set_state(state), "Accepts activity")
		check(sprite.animation == state, "Plays requested clip")
	sprite.set_frame_and_progress(2, 0.5)
	controller.set_state(&"idle")
	check(sprite.frame == 2 and is_equal_approx(sprite.frame_progress, 0.5),
		"Repeated input must preserve animation progress")
	check(not controller.set_state(&"unknown"), "Rejects unknown states")
	controller.set_difficulty(5.0)
	check(is_equal_approx(sprite.speed_scale, 1.6), "Difficulty accelerates playback")
	controller.set_difficulty(1000.0)
	check(sprite.speed_scale == 3.0, "Speed is capped")
	controller.set_difficulty(-2.0)
	check(sprite.speed_scale == 1.0, "Speed has a lower bound")
	controller.set_difficulty(NAN)
	check(sprite.speed_scale == 1.0, "NaN does not poison playback")
	controller.set_difficulty(INF)
	check(sprite.speed_scale == 1.0, "Infinity does not poison playback")
	controller.set_facing_left(true)
	check(sprite.flip_h, "Facing is forwarded")
	controller.outcome_finished.connect(func(_state): finished_count += 1)
	for outcome in [&"success", &"fail"]:
		controller.reset_for_microgame()
		check(controller.set_state(outcome), "Accepts outcome")
		check(not controller.set_state(&"biking"), "Outcome blocks activity")
		check(not controller.set_state(&"fail" if outcome == &"success" else &"success"),
			"First outcome wins")
		await create_timer(0.7).timeout
		check(sprite.frame == 3 and not sprite.is_playing(), "Outcome holds final frame")
	check(finished_count == 2, "Each outcome completes exactly once")
	controller.reset_for_microgame(3.0)
	check(sprite.animation == &"idle" and sprite.frame == 0, "Reset restores idle")
	check(is_equal_approx(sprite.speed_scale, 1.3), "Reset applies next difficulty")
	sprite.sprite_frames.remove_animation(&"typing")
	check(not controller.set_state(&"typing"), "Missing clip leaves state unchanged")
	check(controller.current_state == &"idle", "Missing clip does not corrupt state")
	var second = CHARACTER.instantiate()
	root.add_child(second)
	check(second.get_node("Sprite").sprite_frames.has_animation(&"typing"),
		"Characters do not share mutable frame resources")
	var unbound = CONTROLLER.new()
	check(not unbound.set_state(&"biking"), "Unbound controller fails safely")
	unbound.set_difficulty(2.0)
	unbound.free()
	character.queue_free()
	second.queue_free()
	# Exercise actual demo controls, including per-button signal bindings.
	var demo = load("res://tools/animation_demo.tscn").instantiate()
	root.add_child(demo)
	var demo_controller = demo.get_node("Character/AnimationController")
	var buttons = demo.get_node("UI/Panel/States").get_children()
	check(buttons.size() == CONTROLLER.STATES.size(), "Demo exposes every state")
	for index in range(buttons.size()):
		demo.get_node("UI/Panel/Reset").pressed.emit()
		buttons[index].pressed.emit()
		check(demo_controller.current_state == CONTROLLER.STATES[index],
			"Demo button selects its own state")
	demo.get_node("UI/Panel/Difficulty").value = 5.0
	demo.get_node("UI/Panel/Reset").pressed.emit()
	check(demo_controller.current_state == &"idle"
		and is_equal_approx(demo_controller.playback_speed, 1.6),
		"Demo reset preserves slider difficulty")
	demo.queue_free()
	print("Player animation tests: %d failures" % failures)
	quit(0 if failures == 0 else 1)
