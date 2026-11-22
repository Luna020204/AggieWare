extends "res://tools/test_collection.gd"
## Real viewport events exercise GUI dispatch, transformed dragging, and pause.
## godot --headless --path . --script res://tools/test_input_routes.gd

func _run() -> void:
	_test_input_contract()
	create_timer(20.0, true).timeout.connect(func() -> void:
		push_error("Input route tests exceeded their deadline.")
		quit(1))
	await _test_menu_and_hosted_drag()
	await _test_transformed_drag_and_retry()
	await _test_crossing_hud_buttons()
	print("Input route checks: %d; failures: %d" % [checks, failures])
	if failures == 0:
		print("INPUT_ROUTES_OK")
	quit(1 if failures > 0 else 0)

func _test_menu_and_hosted_drag() -> void:
	var flow: Variant = _mount_flow()
	if flow == null:
		return
	await process_frame
	await _tap_key(KEY_ENTER)
	_check(flow.state == flow.FlowState.STAGE_SELECT, "One confirm press opens day selection without starting a round")
	await _tap_key(KEY_ENTER)
	if not _check(flow.state == flow.FlowState.PLAYING and flow.current_stage == 0 and flow.current_round == 0, "Second confirm selects Monday Canvas"):
		await _dispose(flow)
		return
	var canvas: Variant = _prepare_round(flow)
	await process_frame
	var target: Control = canvas._files[0]
	_drag_between(target, canvas._drop_zone)
	_check(canvas._placed_file == target and canvas._dragging_file == null, "Mouse press, motion, and release uploads the correct file")
	_click(_viewport_center(canvas._submit_button))
	_check(canvas._ended and flow.state == flow.FlowState.RESULT and flow.score == 100, "Clicking Submit completes the hosted round exactly once")
	await _wait_result(flow)
	await _dispose(flow)

func _test_transformed_drag_and_retry() -> void:
	var canvas: Variant = _mount_game("canvas", false)
	if canvas == null:
		return
	canvas.difficulty = 1
	canvas._start_round()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	canvas.position = Vector2(70, 20)
	canvas.size = Vector2(1280, 720)
	canvas.scale = Vector2(0.75, 0.75)
	await process_frame
	var card: Control = canvas._files[0]
	card.scale = Vector2(1.2, 0.8)
	card.rotation = 0.12
	canvas._drop_zone.scale = Vector2(0.8, 1.1)
	_drag_between(card, canvas._drop_zone)
	_check(canvas._placed_file == card, "Transformed card drops inside the scaled target")
	_check(_viewport_center(card).distance_to(_viewport_center(canvas._drop_zone)) < 0.1, "Dropped card aligns with the target under parent, card, and target transforms")
	canvas._process(1.3)
	_check(_viewport_center(card).distance_to(_viewport_center(canvas._drop_zone)) < 0.1, "Uploaded card stays aligned when the target moves")
	_click(_viewport_center(canvas._submit_button))
	_check(canvas._ended, "Standalone mouse submit completes the round")
	await _tap_key(KEY_R)
	_check(not canvas._ended and canvas._placed_file == null and is_equal_approx(canvas.get_seconds_left(), canvas.get_round_seconds()), "Physical R restarts an independent game")
	card = canvas._files[0]
	var origin: Vector2 = card.position
	var start: Vector2 = _viewport_center(card)
	_mouse_button(start, true)
	_mouse_motion(start + Vector2(40, 20), true)
	_check(canvas._dragging_file == card and card.position != origin, "Mouse movement begins an active drag")
	await _tap_key(KEY_ESCAPE)
	_check(paused and root.get_node("GameState").is_paused, "Physical Escape opens the pause overlay")
	_mouse_button(start + Vector2(40, 20), false)
	await _tap_key(KEY_ESCAPE)
	_check(not paused, "Physical Escape resumes the existing round")
	var after_resume: Vector2 = card.position
	_mouse_motion(start + Vector2(90, 60), false)
	_check(canvas._dragging_file == null and card.position == after_resume, "Releasing the mouse while paused cannot leave a stuck drag after resume")
	_drag_between(card, canvas._drop_zone)
	_check(canvas._placed_file == card, "A fresh drag works after pause and release")
	await _dispose(canvas)

func _test_crossing_hud_buttons() -> void:
	var game: Variant = _mount_game("crossing", false)
	if game == null:
		return
	await process_frame
	var pause_hints: Array[String] = []
	for candidate: Node in game._play_hud.get_children():
		if (candidate is Button or candidate is Label) and "PAUSE" in candidate.text.to_upper():
			pause_hints.append(candidate.text)
	_check(pause_hints.is_empty(), "Crossing gameplay has no redundant pause hint or button")
	var initial_progress: float = game.get_crossing_progress()
	var actions: Variant = root.get_node("InputActions")
	Input.action_press(actions.ACTION_UP)
	game._process(0.1)
	Input.action_release(actions.ACTION_UP)
	_check(game.get_crossing_progress() > initial_progress, "Crossing progress follows movement toward the goal")
	await _tap_key(KEY_ESCAPE)
	var seconds: float = game.get_seconds_left()
	game._process(0.2)
	_check(paused and is_equal_approx(game.get_seconds_left(), seconds), "Escape opens Crossing settings and freezes the round")
	await process_frame
	var menu: Variant = game.get_node("SettingsPauseMenu")
	_click(_viewport_center(menu._resume_button))
	_check(not paused and game.can_interact(), "Clicking Resume returns to the same Crossing round")
	game.simulation.vehicles[0].position = game.simulation.player
	game.simulation.vehicles[0].previous = game.simulation.player
	game.simulation.vehicles[0].speed = 0.0
	game.hooks.variables["shields"] = 0
	game.simulation.invulnerable = 0.0
	game._process(0.01)
	_check(game._ended and game._retry_button.is_visible_in_tree(), "Standalone Crossing exposes Play Again after a collision")
	_click(_viewport_center(game._retry_button))
	_check(game.can_interact() and game.simulation.state == "playing" and is_equal_approx(game.simulation.elapsed, 0.0) and not game._retry_button.visible, "Clicking Play Again resets Crossing traffic, time, and result actions")
	await _dispose(game)

func _tap_key(code: Key) -> void:
	var press := InputEventKey.new()
	press.keycode = code
	press.physical_keycode = code
	press.pressed = true
	root.push_input(press, true)
	await process_frame
	var release := InputEventKey.new()
	release.keycode = code
	release.physical_keycode = code
	release.pressed = false
	root.push_input(release, true)
	await process_frame

func _mouse_button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	root.push_input(event, true)

func _mouse_motion(point: Vector2, held: bool) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	root.push_input(event, true)

func _click(point: Vector2) -> void:
	_mouse_motion(point, false)
	_mouse_button(point, true)
	_mouse_button(point, false)

func _drag_between(card: Control, zone: Control) -> void:
	var start := _viewport_center(card)
	var finish := _viewport_center(zone)
	_mouse_motion(start, false)
	_mouse_button(start, true)
	_mouse_motion(finish, true)
	_mouse_button(finish, false)

func _viewport_center(control: Control) -> Vector2:
	return control.get_global_transform_with_canvas() * (control.size * 0.5)
