extends SceneTree

## Smoke tests for Luna's microgames added after SCRUM-23.
## Run with: godot --headless --path . --script res://tools/smoke_new_microgames.gd
## Prints NEW_MICROGAMES_SMOKE_OK when every section passes.

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(25.0, true, false, true).timeout.connect(func() -> void: quit(1))
	await _swipe_card()
	await _stay_awake()
	await _microscope()
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
	# The wallet holds 2 / 3 / 4 cards, always including exactly one Aggie Card.
	for difficulty: int in 3:
		var wallet := await _spawn(scene, difficulty)
		var ids: Array = wallet._cards.map(func(c: TextureRect) -> String: return wallet.card_id(c))
		_assert(ids.size() == difficulty + 2 and ids.count("aggie") == 1, "swipe: wallet cards wrong at %d: %s" % [difficulty, ids])
		_assert(wallet.card_id(wallet._card) == "aggie", "swipe: _card is not the Aggie Card")
		wallet.queue_free()

	# Too slow, too fast and misaligned swipes are rejected; the round goes on.
	var game := await _spawn(scene, 1)
	game.skip_intro()
	var results := _watch(game)
	var window: Vector2 = game.get_speed_window()
	_swipe(game, (window.x * 0.5), 0.0)
	_assert(results.is_empty() and game._status_label.text.contains("slow"), "swipe: slow swipe not rejected: %s" % game._status_label.text)
	_assert(game._card.position == game.card_home(game._card), "swipe: card not put back in the wallet after a bad swipe")
	_swipe(game, window.y * 1.5, 0.0)
	_assert(results.is_empty() and game._status_label.text.contains("fast"), "swipe: fast swipe not rejected")
	_swipe(game, (window.x + window.y) * 0.5, 120.0)
	_assert(results.is_empty() and game._status_label.text.contains("slot"), "swipe: misaligned swipe not rejected")
	# A good swipe with the wrong card is declined, and that card goes back.
	var decoy: TextureRect = game._cards.filter(func(c: TextureRect) -> bool: return c != game._card)[0]
	_swipe(game, (window.x + window.y) * 0.5, 0.0, decoy)
	_assert(results.is_empty() and game._status_label.text.contains("declined"), "swipe: wrong card not declined: %s" % game._status_label.text)
	_assert(decoy.position == game.card_home(decoy) and decoy.z_index == 0, "swipe: wrong card not put back in the wallet")
	# A swipe inside the window wins exactly once.
	_swipe(game, (window.x + window.y) * 0.5, 0.0)
	_assert(results == [true], "swipe: good swipe did not win: %s" % [results])
	_swipe(game, (window.x + window.y) * 0.5, 0.0)
	_assert(results.size() == 1, "swipe: second result after the round ended")
	game.queue_free()

	# A real mouse press on the visible top of a card pulls it out; releasing
	# early puts it back. The pocket hides the rest of the card and blocks clicks.
	game = await _spawn(scene, 2, true)
	# During the intro the shop scene covers the counter; a click skips the
	# intro instead of pulling a card.
	_assert(game._exterior.visible and game._walker.visible, "swipe: intro does not show the shop and the student")
	var intro_grab: Vector2 = game._card.get_global_rect().position + Vector2(game.CARD_SIZE.x * 0.5, 12.0)
	await _mouse(intro_grab, true)
	_assert(not game._dragging, "swipe: a card was pulled during the intro")
	_assert(game._intro_left == 0.0 and not game._exterior.visible, "swipe: a click did not skip the intro")
	await _mouse(intro_grab, false)
	var home: Vector2 = game.card_home(game._card)
	var grab: Vector2 = game._card.get_global_rect().position + Vector2(game.CARD_SIZE.x * 0.5, 12.0)
	await _mouse(grab, true)
	_assert(game._dragging and game._held == game._card, "swipe: real click on the card's top did not pull it out")
	await _move(grab + Vector2(60.0, 0.0))
	_assert(game._card.position.x > home.x and game._card.z_index > 0, "swipe: card did not follow the mouse above the wallet")
	await _mouse(grab + Vector2(60.0, 0.0), false)
	_assert(not game._dragging and game._card.position == home, "swipe: early release did not put the card back")
	var pocket_point: Vector2 = game.WALLET_POS + Vector2(150.0, 120.0)
	await _mouse(pocket_point, true)
	_assert(not game._dragging, "swipe: a click on the wallet pocket pulled out a card")
	await _mouse(pocket_point, false)
	game.queue_free()

	# The timer waits for the intro; HARD moves the scanner; timeout fails.
	game = await _spawn(scene, 2, true)
	results = _watch(game)
	var full: float = game._seconds_left
	game._process(0.1)
	_assert(game._seconds_left == full and game._exterior.visible, "swipe: timer ran during the intro")
	game.skip_intro()
	var start_y: float = game._scanner.position.y
	game._process(0.25)
	_assert(game._scanner.position.y != start_y, "swipe: HARD scanner does not move")
	game._seconds_left = 0.01
	game._process(0.02)
	_assert(results == [false], "swipe: timeout did not fail once: %s" % [results])
	game.queue_free()


## Drags a card (the Aggie Card by default) through the scanner at `speed` px/s,
## offset vertically by `y_offset`.
func _swipe(game: Control, speed: float, y_offset: float, card: TextureRect = null) -> void:
	if card == null:
		card = game._card
	var slot_y: float = game._scanner.position.y + game._scanner.size.y * 0.5
	var start := Vector2(game.card_home(card).x + game.CARD_SIZE.x * 0.5, slot_y + y_offset)
	game.begin_drag(card.position + game.CARD_SIZE * 0.5, card)
	card.position = start - game.CARD_SIZE * 0.5
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

	# Preserve the lecture-hall walk-in and click-to-skip behavior.
	var game := await _spawn(scene, 1, true)
	var full: float = game._seconds_left
	game._process(0.1)
	_assert(game._seconds_left == full and game._overlay.intro.visible, "awake: timer ran during the intro")
	_assert(game._walk_in.scene.visible and game._walk_in.walker.visible, "awake: intro does not show the building and the student")
	await _click(Vector2(640.0, 200.0))
	_assert(game._intro_left == 0.0 and not game._overlay.intro.visible, "awake: a click did not skip the intro")
	game.queue_free()

	# Real clicks pop Z's; surviving to the bell wins once.
	game = await _spawn(scene, 1)
	var results := _watch(game)
	game._spawn_clock = -100.0  # no random spawns during this check
	var z1: Button = game.spawn_z(Vector2(200.0, 250.0))
	var z2: Button = game.spawn_z(Vector2(1000.0, 250.0))
	await _click(z1.get_global_rect().get_center())
	await _click(z2.get_global_rect().get_center())
	_assert(game._popped == 2 and game._zs.is_empty(), "awake: real clicks did not pop both Z's (%d)" % game._popped)
	game._seconds_left = 0.01
	game._process(0.02)
	_assert(results == [true], "awake: surviving did not win: %s" % [results])
	game.queue_free()

	# A Z that reaches the student fails the round exactly once.
	game = await _spawn(scene, 0)
	results = _watch(game)
	game._spawn_clock = -100.0
	var near: Button = game.spawn_z(game.STUDENT_CENTER - Vector2(30.0, 30.0))
	game._process(0.02)
	_assert(results == [false], "awake: Z reaching the student did not fail: %s" % [results])
	game.pop_z(near)
	_assert(game._popped == 0, "awake: popped a Z after the round ended")
	game.queue_free()

	# Untouched, Z's spawn by themselves and the round fails before the bell.
	game = await _spawn(scene, 2)
	results = _watch(game)
	var frames := 0
	while results.is_empty() and frames < 1000:
		game._process(0.02)
		frames += 1
	_assert(results == [false], "awake: idle round did not end in a fail: %s" % [results])
	game.queue_free()


# --- SCRUM-84 Microscope -------------------------------------------------------

func _microscope() -> void:
	var scene := "res://scenes/microgames/microscope.tscn"
	var areas: Array[float] = []
	var decoys: Array[int] = []
	var radii: Array[float] = []
	for difficulty: int in 3:
		var game := await _spawn(scene, difficulty)
		var slide: Vector2 = game._slide_size
		areas.append(slide.x * slide.y)
		radii.append(game.VIEW_RADII[difficulty])
		var targets := 0
		var gold := 0
		for bug: Dictionary in game._bugs:
			if bug["kind"] == "aggie":
				targets += 1
			elif bug["kind"] == "gold":
				gold += 1
		decoys.append(game._bugs.size() - targets)
		_assert(targets == 1, "microscope: %d targets on the slide" % targets)
		_assert(game._target_pos.distance_to(game.camera) > game.VIEW_RADII[difficulty], "microscope: target starts in view")
		if difficulty == 0:
			_assert(gold == 0, "microscope: gold look-alikes on EASY")
		game.queue_free()
	_assert(areas[0] < areas[1] and areas[1] < areas[2], "microscope: slide does not grow")
	_assert(decoys[0] < decoys[1] and decoys[1] < decoys[2], "microscope: look-alikes do not increase %s" % [decoys])
	_assert(radii[0] > radii[1] and radii[1] > radii[2], "microscope: view does not shrink")

	# The intro holds the timer and shows the lab building; a click skips it.
	var game := await _spawn(scene, 1)
	var full: float = game._seconds_left
	for i: int in 5:
		await process_frame
	_assert(game._seconds_left == full and game._overlay.intro.visible, "microscope: timer ran during the intro")
	_assert(game._walk_in.scene.visible and game._walk_in.walker.visible, "microscope: intro does not show the building and the student")
	await _click(Vector2(640.0, 200.0))
	_assert(game._intro_left == 0.0 and not game._overlay.intro.visible, "microscope: a click did not skip the intro")
	game.queue_free()

	# Real arrow-key input pans the view.
	game = await _spawn(scene, 1)
	game.skip_intro()
	var results := _watch(game)
	var start: Vector2 = game.camera
	var actions: Node = root.get_node("InputActions")
	Input.action_press(actions.ACTION_RIGHT)
	Input.action_press(actions.ACTION_DOWN)
	game._process(0.1)
	Input.action_release(actions.ACTION_RIGHT)
	Input.action_release(actions.ACTION_DOWN)
	_assert(game.camera.x > start.x and game.camera.y > start.y, "microscope: arrow keys did not pan (%s -> %s)" % [start, game.camera])
	# ACTION away from the target does nothing; panning onto it and holding wins once.
	game.confirm()
	_assert(results.is_empty(), "microscope: confirm off-target ended the round")
	var guard := 0
	while game.camera.distance_to(game._target_pos) > 5.0 and guard < 400:
		game.move_camera((game._target_pos - game.camera).normalized(), minf(0.016, game.camera.distance_to(game._target_pos) / game.PAN_SPEED))
		guard += 1
	_assert(game.is_target_in_crosshair(), "microscope: could not reach the target")
	var frames := 0
	while results.is_empty() and frames < 200:
		game._process(0.02)
		frames += 1
	_assert(results == [true], "microscope: holding the target did not win: %s" % [results])
	game.confirm()
	_assert(results.size() == 1, "microscope: second result after the round ended")
	game.queue_free()

	# ACTION on the target wins immediately; timeout fails.
	game = await _spawn(scene, 2)
	game.skip_intro()
	results = _watch(game)
	game.camera = game._target_pos
	game.confirm()
	_assert(results == [true], "microscope: ACTION on target did not win")
	game.queue_free()
	game = await _spawn(scene, 0)
	game.skip_intro()
	results = _watch(game)
	game._seconds_left = 0.01
	game._process(0.02)
	_assert(results == [false], "microscope: timeout did not fail: %s" % [results])
	game.queue_free()


# --- helpers -------------------------------------------------------------------

func _spawn(scene: String, difficulty: int, with_intro := false) -> Control:
	var game: Control = load(scene).instantiate()
	var pause := game.get_node_or_null("SettingsPauseMenu")
	if pause != null:
		game.remove_child(pause)
		pause.free()
	game.set("difficulty", difficulty)
	root.add_child(game)
	game.set_process(false)
	if not with_intro and game.has_method("skip_intro"):
		game.skip_intro()
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
