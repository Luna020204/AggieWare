extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	create_timer(20.0, true, false, true).timeout.connect(func(): push_error("Practice test timed out"); quit(1))
	var flow = load("res://scripts/core/game_flow.gd").new()
	root.add_child(flow)
	flow.lives = 2
	flow.score = 400
	flow._show_practice()
	var practice = flow._active_scene
	practice.set_process(false)
	check(practice.game_picker.item_count == MicrogameCatalog.ENTRIES.size(), "Practice includes full catalog")
	for i in MicrogameCatalog.ENTRIES.size():
		practice.selected_index = i
		practice.launch()
		check(practice.active != null, "Practice loads every game")
		practice.stop()
	practice.selected_index = MicrogameCatalog.find_index("climbing")
	var actions = root.get_node("InputActions")
	for tier in 3:
		practice.difficulty = tier
		practice.launch()
		var game = practice.active
		game.set_process(false)
		check(game.difficulty == tier, "Selected difficulty is applied")
		var full = game.get_seconds_left()
		game.try_latch()
		check(game.reached == 0 and game.get_seconds_left() == full, "Intro ignores grab")
		game.skip_intro()
		game.angle = -1.2
		game.try_latch()
		check(game.reached == 0, "Misaligned grab does not advance")
		var start_angle = game.angle
		Input.action_press(actions.ACTION_RIGHT)
		game._process(0.1)
		Input.action_release(actions.ACTION_RIGHT)
		check(game.angle > start_angle, "Right input rotates climber")
		root.get_node("GameState").pause_game()
		var before = game.get_seconds_left()
		game._process(1.0)
		check(game.get_seconds_left() == before, "Pause freezes timer")
		root.get_node("GameState").resume_game()
		await process_frame
		for hold in game.COUNTS[tier]:
			game.angle = (game.holds[game.reached+1]-game.holds[game.reached]).angle()+PI/2
			game.cooldown = 0.0
			var event := InputEventKey.new()
			event.physical_keycode = KEY_SPACE
			event.pressed = true
			Input.parse_input_event(event)
			Input.flush_buffered_events()
			game._process(0.001)
			event = event.duplicate()
			event.pressed = false
			Input.parse_input_event(event)
			Input.flush_buffered_events()
			await process_frame
		check(game.is_round_finished() and practice.result.text.begins_with("SUCCESS"), "All holds win")
		practice.stop()
		practice.launch()
		game = practice.active
		game.set_process(false)
		game.skip_intro()
		game._process(20)
		check(game.is_round_finished() and practice.result.text.begins_with("TRY"), "Timeout loses without week penalties")
		var obsolete = practice.token
		practice.stop()
		practice.launch()
		practice._finished(obsolete)
		check(practice.active != null, "Old callback cannot stop a replay")
		practice.stop()
	check(flow.lives == 2 and flow.score == 400, "Practice preserves week lives and score")
	practice.exited.emit()
	check(flow.state == flow.FlowState.TITLE, "Exit returns to title")
	root.remove_child(flow)
	flow.queue_free()
	await process_frame
	if failures == 0: print("PRACTICE_CLIMBING_OK")
	quit(failures)
