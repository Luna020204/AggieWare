extends SceneTree

## Smoke tests for Luna's microgames added after SCRUM-23.
## Run with: godot --headless --path . --script res://tools/smoke_new_microgames.gd
## Prints NEW_MICROGAMES_SMOKE_OK when every section passes.

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _swipe_card()
	await _stay_awake()
	if not _failed:
		print("NEW_MICROGAMES_SMOKE_OK")
	quit(1 if _failed else 0)


# --- SCRUM-72 Swipe Card -----------------------------------------------------

func _swipe_card() -> void:
	var scene := "res://scenes/microgames/swipe_card.tscn"
	var durations: Array[float] = []
	var widths: Array[float] = []
	for difficulty: int in 3:
		var game := await _spawn(scene, difficulty)
		durations.append(game.get_round_seconds())
		var window: Vector2 = game.get_speed_window()
		widths.append(window.y - window.x)
		game.queue_free()
	_assert(durations[0] > durations[1] and durations[1] > durations[2], "swipe: time does not shrink %s" % [durations])
	_assert(widths[0] > widths[1] and widths[1] > widths[2], "swipe: speed window does not narrow %s" % [widths])

	# Too slow, too fast and misaligned swipes are rejected; the round goes on.
	var game := await _spawn(scene, 1)
	var results := _watch(game)
	var window: Vector2 = game.get_speed_window()
	_swipe(game, (window.x * 0.5), 0.0)
	_assert(results.is_empty() and game._status_label.text.contains("slow"), "swipe: slow swipe not rejected: %s" % game._status_label.text)
	_assert(game._card.position == game.CARD_HOME, "swipe: card not reset after a bad swipe")
	_swipe(game, window.y * 1.5, 0.0)
	_assert(results.is_empty() and game._status_label.text.contains("fast"), "swipe: fast swipe not rejected")
	_swipe(game, (window.x + window.y) * 0.5, 120.0)
	_assert(results.is_empty() and game._status_label.text.contains("slot"), "swipe: misaligned swipe not rejected")
	# A swipe inside the window wins exactly once.
	_swipe(game, (window.x + window.y) * 0.5, 0.0)
	_assert(results == [true], "swipe: good swipe did not win: %s" % [results])
	_swipe(game, (window.x + window.y) * 0.5, 0.0)
	_assert(results.size() == 1, "swipe: second result after the round ended")
	game.queue_free()

	# A real mouse press on the card starts a drag; releasing early resets it.
	game = await _spawn(scene, 0)
	var grab: Vector2 = game._card.get_global_rect().get_center()
	await _mouse(grab, true)
	_assert(game._dragging, "swipe: real click on the card did not start a drag")
	await _move(grab + Vector2(60.0, 0.0))
	_assert(game._card.position.x > game.CARD_HOME.x, "swipe: card did not follow the mouse")
	await _mouse(grab + Vector2(60.0, 0.0), false)
	_assert(not game._dragging and game._card.position == game.CARD_HOME, "swipe: early release did not reset the card")
	game.queue_free()

	# HARD moves the scanner; timeout fails.
	game = await _spawn(scene, 2)
	results = _watch(game)
	var start_y: float = game._scanner.position.y
	for i: int in 20:
		await process_frame
	_assert(game._scanner.position.y != start_y, "swipe: HARD scanner does not move")
	game._seconds_left = 0.01
	for i: int in 5:
		await process_frame
	_assert(results == [false], "swipe: timeout did not fail once: %s" % [results])
	game.queue_free()


## Drags the card through the scanner at `speed` px/s, offset vertically by `y_offset`.
func _swipe(game: Control, speed: float, y_offset: float) -> void:
	var slot_y: float = game._scanner.position.y + game._scanner.size.y * 0.5
	var start := Vector2(game.CARD_HOME.x + game.CARD_SIZE.x * 0.5, slot_y + y_offset)
	game.begin_drag(game._card.position + game.CARD_SIZE * 0.5)
	game._card.position = start - game.CARD_SIZE * 0.5
	game._drag_offset = game.CARD_SIZE * 0.5
	var left: float = game._scanner.position.x
	var right: float = left + game._scanner.size.x
	var usec := 1_000_000
	var x := start.x
	while x <= right + 40.0 and game._dragging:
		game.drag_to(Vector2(x, start.y), usec)
		var step := 20.0
		x += step
		if x >= left:
			usec += int(step / speed * 1_000_000.0)
	game.release()


# --- SCRUM-76 Stay Awake -------------------------------------------------------

func _stay_awake() -> void:
	var scene := "res://scenes/microgames/stay_awake.tscn"
	var intervals: Array[float] = []
	var speeds: Array[float] = []
	var sizes: Array[float] = []
	for difficulty: int in 3:
		var game := await _spawn(scene, difficulty)
		intervals.append(game.SPAWN_INTERVALS[difficulty])
		speeds.append(game.SPEEDS[difficulty])
		var z: Button = game.spawn_z(Vector2(100.0, 200.0))
		sizes.append(z.size.x)
		_assert(z.focus_mode == Control.FOCUS_NONE, "awake: Z can take keyboard focus")
		game.queue_free()
	_assert(intervals[0] > intervals[1] and intervals[1] > intervals[2], "awake: Z's do not get more frequent")
	_assert(speeds[0] < speeds[1] and speeds[1] < speeds[2], "awake: Z's do not get faster")
	_assert(sizes[0] > sizes[1] and sizes[1] > sizes[2], "awake: Z's do not get smaller %s" % [sizes])

	# Real clicks pop Z's; surviving to the bell wins once.
	var game := await _spawn(scene, 1)
	var results := _watch(game)
	game._spawn_clock = -100.0  # no random spawns during this check
	var z1: Button = game.spawn_z(Vector2(200.0, 250.0))
	var z2: Button = game.spawn_z(Vector2(1000.0, 250.0))
	await _click(z1.get_global_rect().get_center())
	await _click(z2.get_global_rect().get_center())
	_assert(game._popped == 2 and game._zs.is_empty(), "awake: real clicks did not pop both Z's (%d)" % game._popped)
	game._seconds_left = 0.01
	for i: int in 5:
		await process_frame
	_assert(results == [true], "awake: surviving did not win: %s" % [results])
	game.queue_free()

	# A Z that reaches the student fails the round exactly once.
	game = await _spawn(scene, 0)
	results = _watch(game)
	game._spawn_clock = -100.0
	var near: Button = game.spawn_z(game.STUDENT_CENTER - Vector2(30.0, 30.0))
	for i: int in 5:
		await process_frame
	_assert(results == [false], "awake: Z reaching the student did not fail: %s" % [results])
	game.pop_z(near)
	_assert(game._popped == 0, "awake: popped a Z after the round ended")
	game.queue_free()

	# Untouched, Z's spawn by themselves and the round fails before the bell.
	game = await _spawn(scene, 2)
	results = _watch(game)
	var frames := 0
	while results.is_empty() and frames < 2000:
		await process_frame
		frames += 1
	_assert(results == [false], "awake: idle round did not end in a fail: %s" % [results])
	game.queue_free()


# --- helpers -------------------------------------------------------------------

func _spawn(scene: String, difficulty: int) -> Control:
	var game: Control = load(scene).instantiate()
	var pause := game.get_node_or_null("SettingsPauseMenu")
	if pause != null:
		game.remove_child(pause)
		pause.free()
	game.set("difficulty", difficulty)
	root.add_child(game)
	await process_frame
	return game


func _watch(game: Control) -> Array:
	var results: Array = []
	game.round_completed.connect(func(success: bool) -> void: results.append(success))
	return results


func _move(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion, true)
	await process_frame


func _mouse(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	event.global_position = at
	root.push_input(event, true)
	await process_frame


func _click(at: Vector2) -> void:
	await _move(at)
	await _mouse(at, true)
	await _mouse(at, false)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)
