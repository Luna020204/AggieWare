extends SceneTree

## SCRUM-23 smoke test for the Variable Not in Scope microgame.
## Run with: godot --headless --path . --script res://tools/smoke_variable_scope.gd

const SCENE := "res://scenes/microgames/variable_scope.tscn"

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Difficulty scaling: less time, more choices, look-alikes on HARD.
	var durations: Array[float] = []
	for difficulty: int in 3:
		var hard_lookalike_seen := 0
		for trial: int in 40:
			var game := await _spawn(difficulty)
			if trial == 0:
				durations.append(game.get_round_seconds())
			var lines: Array[String] = []
			var correct := 0
			for button: Button in game._choice_buttons:
				lines.append(button.text)
				if button.get_meta("correct"):
					correct += 1
					_assert(button.text == "int %s = %d;" % [game._missing, game._value], "correct line is wrong: " + button.text)
				_assert(button.focus_mode == Control.FOCUS_NONE, "choice can take keyboard focus")
			_assert(lines.size() == game.CHOICE_COUNTS[difficulty], "difficulty %d has %d choices" % [difficulty, lines.size()])
			_assert(correct == 1, "difficulty %d has %d correct choices: %s" % [difficulty, correct, lines])
			var unique := {}
			for line: String in lines:
				unique[line] = true
			_assert(unique.size() == lines.size(), "duplicate choices: %s" % [lines])
			_assert(game._error_label.text.contains("'%s' was not declared in this scope" % game._missing), "error text wrong")
			if difficulty == 2:
				for line: String in lines:
					if line.begins_with("int ") and line.to_lower() == game._correct_line.to_lower() and line != game._correct_line:
						hard_lookalike_seen += 1
			game.queue_free()
		if difficulty == 2:
			_assert(hard_lookalike_seen == 40, "HARD missing the case look-alike in %d/40 rounds" % (40 - hard_lookalike_seen))
	_assert(durations[0] > durations[1] and durations[1] > durations[2], "time does not shrink with difficulty: %s" % [durations])
	_assert(durations[0] <= 10.0 and durations[2] >= 5.0, "durations outside 5-10 s: %s" % [durations])

	# Correct click wins, via a real mouse event through the viewport.
	var game := await _spawn(1)
	var results: Array = []
	game.round_completed.connect(func(s: bool) -> void: results.append(s))
	var correct_button: Button
	for button: Button in game._choice_buttons:
		if button.get_meta("correct"):
			correct_button = button
	# Keyboard confirm must not pick anything.
	var key := InputEventAction.new()
	key.action = "ui_accept"
	key.pressed = true
	root.push_input(key)
	await process_frame
	_assert(results.is_empty(), "keyboard ui_accept picked a choice")
	await _click(correct_button.get_global_rect().get_center())
	_assert(results == [true], "clicking the correct line did not win: %s" % [results])
	_assert(game._code_label.text.contains(game._correct_line), "fixed code not shown")
	await _click(correct_button.get_global_rect().get_center())
	_assert(results.size() == 1, "round_completed fired again after the round ended")
	game.queue_free()

	# Wrong click fails.
	game = await _spawn(2)
	results = []
	game.round_completed.connect(func(s: bool) -> void: results.append(s))
	for button: Button in game._choice_buttons:
		if not button.get_meta("correct"):
			await _click(button.get_global_rect().get_center())
			break
	_assert(results == [false], "clicking a decoy did not fail: %s" % [results])
	game.queue_free()

	# HARD shuffles choice positions over time.
	game = await _spawn(2)
	var before: Array[Vector2] = []
	for button: Button in game._choice_buttons:
		before.append(button.position)
	var moved := false
	for attempt: int in 6:
		game._shuffle_choices()
		await create_timer(0.25).timeout
		for index: int in game._choice_buttons.size():
			if game._choice_buttons[index].position != before[index]:
				moved = true
		if moved:
			break
	_assert(moved, "HARD choices never moved when shuffled")
	game.queue_free()

	# Timeout fails exactly once.
	game = await _spawn(0)
	results = []
	game.round_completed.connect(func(s: bool) -> void: results.append(s))
	game._seconds_left = 0.05
	for i: int in 10:
		await process_frame
	_assert(results == [false], "timeout did not fail exactly once: %s" % [results])
	game.queue_free()

	if not _failed:
		print("VARIABLE_SCOPE_SMOKE_OK")
	quit(1 if _failed else 0)


func _spawn(difficulty: int) -> Control:
	var game: Control = load(SCENE).instantiate()
	game.set("difficulty", difficulty)
	root.add_child(game)
	await process_frame
	return game


func _click(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	root.push_input(motion, true)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		root.push_input(event, true)
		await process_frame


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)
