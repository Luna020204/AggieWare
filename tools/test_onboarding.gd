extends SceneTree
## Monday teaching checks against the real week flow and GUI input.
const DRIVER = preload("res://tools/microgame_test_driver.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func center(control: Control) -> Vector2:
	return control.get_global_transform_with_canvas() * (control.size * 0.5)

func click_at(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func _run() -> void:
	create_timer(20).timeout.connect(func(): quit(1))
	var flow = load("res://scenes/core/game_flow.tscn").instantiate()
	root.add_child(flow)
	flow._start_stage(0)
	var game = flow._active_scene
	DRIVER.freeze(game)
	var seconds: float = game.get_seconds_left()
	game._process(60)
	check(game._waiting_for_ready and not game.can_interact(), "Monday waits without accepting gameplay")
	check(game.get_seconds_left() == seconds, "Reading does not consume time")
	await click_at(Vector2(200, 200))
	check(game._waiting_for_ready, "Background click does not skip ready")
	var state_node = root.get_node("GameState")
	state_node.pause_game()
	game._ready_button.pressed.emit()
	check(game._waiting_for_ready, "Ready is ignored during pause")
	state_node.resume_game()
	await process_frame
	await click_at(center(game._ready_button))
	check(game.can_interact() and not game._waiting_for_ready, "Ready button starts play")
	check(game._placed_file == null and not game.is_round_finished(), "Ready click is not a gameplay action")
	check(game._tutorial_hint.text.begins_with("1."), "First lesson teaches drag")
	game._process(0.5)
	check(is_equal_approx(game.get_seconds_left(), seconds - 0.5), "Timer runs after readiness")
	# Use the existing drag input path, not a direct success setter.
	var card = game._files[0]
	var start: Vector2 = center(card)
	var finish: Vector2 = center(game._drop_zone)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	down.position = start
	root.push_input(down, true)
	await process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = finish
	motion.relative = finish - start
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion, true)
	await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = finish
	root.push_input(up, true)
	await process_frame
	check(game._placed_file != null and game._tutorial_hint.text.begins_with("2."), "Real drag advances to submit lesson")
	await click_at(center(game._submit_button))
	check(flow.score == 100 and flow.lives == 3, "Submission succeeds without life loss")
	game._process(2)
	flow._active_scene._finish_transition()
	game = flow._active_scene
	DRIVER.freeze(game)
	check(game.tutorial_enabled and game._waiting_for_ready, "Crossing also waits for readiness")
	await process_frame
	for pressed in [true, false]:
		var confirm := InputEventKey.new()
		confirm.physical_keycode = KEY_ENTER
		confirm.keycode = KEY_ENTER
		confirm.pressed = pressed
		root.push_input(confirm, true)
		await process_frame
	check(game.is_playing(), "Keyboard can activate the ready button")
	game._process(100)
	check(flow.lives == 2, "Timeout costs one life")
	game.round_completed.emit(false)
	check(flow.lives == 2, "Duplicate failure does not cost another life")
	game._process(2)
	check(flow.state == flow.FlowState.TUTORIAL_RESULT, "First failure explains lives before retry")
	check(flow._subtitle_label.text == "2 lives remaining", "Lesson shows actual remaining lives")
	flow._continue_after_life_lesson()
	flow._continue_after_life_lesson()
	check(flow.state == flow.FlowState.TRANSITION and flow.lives == 2, "Repeated Continue cannot double advance")
	flow._active_scene._finish_transition()
	game = flow._active_scene
	DRIVER.freeze(game)
	game.skip_intro()
	game._finish_round(false, "Collision")
	game._process(2)
	check(flow.state == flow.FlowState.TRANSITION and flow.lives == 1, "Later failure uses ordinary retry")
	# New week resets the explanation, but later days retain timed introductions.
	flow._show_title()
	flow._show_stage_select()
	check(not flow._explained_life_loss, "New week resets life lesson")
	flow._start_stage(1)
	game = flow._active_scene
	DRIVER.freeze(game)
	game._process(4)
	check(not game.tutorial_enabled and game.is_playing(), "Tuesday starts automatically as before")
	var actions = root.get_node("InputActions")
	var saved: Array[InputEvent] = actions.get_action_events(actions.ACTION_UP)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_I
	var remapped: Array[InputEvent] = [key]
	actions.replace_action_events(actions.ACTION_UP, remapped)
	flow._start_round(0, 1)
	game = flow._active_scene
	check(game._intro_view.instruction_label.text.begins_with("MOVE: I /"), "Lesson respects remapped controls")
	actions.replace_action_events(actions.ACTION_UP, saved)
	flow.queue_free()
	await process_frame
	print("Onboarding checks: %d; failures: %d" % [checks, failures])
	if failures == 0: print("ONBOARDING_TESTS_OK")
	quit(1 if failures else 0)
