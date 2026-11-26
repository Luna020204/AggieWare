extends "res://tools/test_collection.gd"
## Shared-format checks plus preservation of Luna's native PR16 presentation.
## All nine catalog games are exercised at all three difficulties.

var Catalog: Script
const PIXEL_FONT_PATH := "res://assets/fonts/aggie_pixel.fnt"
const NATIVE_DURATIONS := {"scope": [9.0, 7.0, 5.5], "swipe": [9.0, 8.0, 7.0], "awake": [8.0, 7.0, 6.0], "microscope": [10.0, 9.0, 8.0]}

func _run() -> void:
	# Load after autoloads exist; the catalog's typed base references GameState.
	Catalog = load("res://scripts/core/microgame_catalog.gd")
	create_timer(40.0, true, false, true).timeout.connect(func() -> void:
		push_error("Presentation tests exceeded their deadline.")
		quit(1))
	_check(Catalog.ENTRIES.size() == 10 and Catalog.find_index("crossing") >= 0, "Catalog contains all ten games including Campus Crossing")
	_test_native_preservation()
	for entry: Dictionary in Catalog.ENTRIES:
		for difficulty: int in 3:
			if entry.id in NATIVE_DURATIONS:
				await _test_native_format(entry, difficulty)
			else:
				await _test_format(entry, difficulty)
		await _test_standalone_metadata(entry)
	await _test_intro_click_skip()
	await _test_host_timer_visibility()
	await _test_rejection_and_timeout_format()
	await _test_crossing_notice_fade()
	print("Presentation checks: %d; failures: %d" % [checks, failures])
	if failures == 0:
		print("PRESENTATION_TESTS_OK")
	quit(1 if failures else 0)

## Luna's native games: latest reviewed revision of the preserved files and
## the games that open with a walk-in intro. Update both when a native game
## is redesigned (PR #17 added the Microscope lab walk-in, PR #18 the
## Variable Not in Scope laptop scene and AggieMono font).
const NATIVE_REVISION := "5610ac7"
const NATIVE_FILE_COUNT := 97
const WALK_IN_IDS: Array[String] = ["swipe", "awake", "microscope", "scope"]

func _test_native_preservation() -> void:
	var path := "res://tools/fixtures/pr16_native_sha256.json"
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not _check(manifest is Dictionary and manifest.get("revision") == NATIVE_REVISION, "Native preservation manifest identifies the reviewed native revision"):
		return
	_check(manifest.files.size() == NATIVE_FILE_COUNT, "Native preservation covers all four games, scenes, helpers, art, and generators")
	for source: String in manifest.files:
		_check(FileAccess.get_sha256("res://" + source) == manifest.files[source], "Native bytes preserved: " + source)

func _test_native_format(entry: Dictionary, difficulty: int) -> void:
	var session: Variant = Catalog.instantiate(entry, difficulty)
	if not _check(session != null and session.has_method("tick_native"), "Instantiate native %s difficulty %d" % [entry.id, difficulty]):
		return
	root.add_child(session)
	DRIVER.freeze(session)
	var game: Variant = session.native_game
	var label := "%s native difficulty %d" % [entry.id, difficulty]
	var walk_in: bool = entry.id in WALK_IN_IDS
	var full: float = NATIVE_DURATIONS[entry.id][difficulty]
	_check(is_equal_approx(session.get_round_seconds(), full), label + " preserves its original difficulty duration")
	_check(session.uses_native_hud() and game.show_internal_timer and game._timer_label.is_visible_in_tree(), label + " retains its own timer")
	_check(_count_script(session, "res://scripts/ui/instruction_prompt.gd") == 0 and _count_script(session, "res://scripts/ui/result_cue.gd") == 0, label + " has no extra shared intro or result banner")
	_check(is_equal_approx(session.get_intro_seconds(), 3.2 if walk_in else 0.0), label + " preserves its original introduction duration")
	if walk_in:
		var overlay: Variant = game._overlay
		var intro: Variant = game._walk_in
		_check(_count_script(session, "res://scripts/ui/microgame_overlay.gd") == 1 and _count_script(session, "res://scripts/ui/walk_in_intro.gd") == 1, label + " uses exactly one native walk-in and text overlay")
		_check(not session.can_interact() and intro.scene.visible and intro.walker.visible, label + " starts outside with a visible student")
		_check_label(overlay.intro.get_child(0), 70, Color("ffbf00"), label + " native title")
		_check_label(overlay.intro.get_child(1), 28, Color.WHITE, label + " native instruction")
		var first_position: Vector2 = intro.walker.position
		_tick_game(session, 0.7)
		_check(intro.walker.position != first_position and is_equal_approx(session.get_seconds_left(), full), label + " walks along the authored path without spending play time")
		_tick_game(session, 1.6)
		_check(not intro.walker.visible and intro.door.visible and overlay.intro.modulate.a < 1.0, label + " opens the door and fades its title after entering")
		_tick_game(session, 0.55)
		_check(intro._fade.color.a > 0.99 and is_equal_approx(session.get_seconds_left(), full), label + " passes through black before revealing play")
		DRIVER.skip_intro(session)
		_check(not intro.scene.visible and not overlay.intro.visible and is_zero_approx(intro._fade.color.a), label + " skips every remaining part of the native introduction")
		_check(game.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, label + " retains nearest pixel filtering")
		_check_pixel_art(game, label)
	else:
		_check(session.can_interact() and session.is_playing(), label + " begins directly without an invented introduction")
		_check(DRIVER.message_overlay(session) == null, label + " does not mistake ordinary game artwork for a result overlay")
	_check(session.can_interact(), label + " releases play through the host protocol")
	if entry.id == "awake":
		_check_awake_art(game, label)
	var results: Array[bool] = []
	var finished: Array[bool] = []
	session.round_completed.connect(func(success: bool) -> void: results.append(success))
	session.result_finished.connect(func() -> void: finished.append(true))
	_win_game(entry.scene.get_file().get_basename(), session)
	_check(results == [true] and session.is_round_finished() and not session.can_interact(), label + " forwards its native mechanic win exactly once")
	_check(game._status_label.is_visible_in_tree() and not game._status_label.text.is_empty(), label + " shows its own authored result message")
	_finish_game(session, false, "DUPLICATE")
	var stopped_time: float = session.get_seconds_left()
	_tick_game(session, 1.0)
	_check(results == [true] and finished.is_empty(), label + " keeps the native result readable before returning")
	if walk_in:
		_tick_game(session, 0.2)
		_check(game._status_label.modulate.a > 0.0 and game._status_label.modulate.a < 1.0 and finished.is_empty(), label + " waits for its actual native popup fade")
	_tick_game(session, 0.45)
	_tick_game(session, 0.1)
	_check(finished == [true] and is_equal_approx(session.get_seconds_left(), stopped_time), label + " releases its host once with the native clock stopped")
	if walk_in:
		_check(is_zero_approx(game._status_label.modulate.a), label + " completes the native fade before host release")
	await _dispose(session)

func _check_awake_art(game: Variant, context: String) -> void:
	_check(game.HALL_TEXTURE.resource_path.ends_with("stay_awake/lecture_hall.png") and game.BUILDING_TEXTURE.resource_path.ends_with("stay_awake/building_exterior.png"), context + " preserves the ECS 179 hall and building artwork")
	_check(game._screen.texture in game.SCREEN_TEXTURES and game.PROFESSOR_TEXTURE.resource_path.ends_with("stay_awake/professor.png"), context + " preserves the projector game and professor")
	game._spawn_clock = -100.0
	var before: Texture2D = game._screen.texture
	game._process(0.35)
	_check(game._screen.texture != before, context + " animates the projected game at the native frame interval")
	var z: Button = game.spawn_z(game.STUDENT_CENTER + Vector2(150, 0))
	game._process(0.01)
	_check(game._student.texture == game.DROWSY_TEXTURE, context + " reacts to a nearby Z with the drowsy student sprite")
	game.pop_z(z)
	game._process(0.01)
	_check(game._student.texture == game.AWAKE_TEXTURE, context + " returns to the awake sprite after the threat is removed")

func _test_format(entry: Dictionary, difficulty: int) -> void:
	var game: Variant = Catalog.instantiate(entry, difficulty)
	if not _check(game != null, "Instantiate %s difficulty %d" % [entry.id, difficulty]):
		return
	game.managed_by_flow = true
	game.show_internal_timer = true
	game.game_title = entry.title
	game.instruction_text = entry.instruction
	root.add_child(game)
	game.set_process(false)
	var label := "%s difficulty %d" % [entry.id, difficulty]
	_check(is_equal_approx(game.get_round_seconds(), 9.0 - difficulty), label + " uses the standard 9/8/7-second play time")
	_check(is_equal_approx(game.get_intro_seconds(), 3.2) and is_equal_approx(game.result_seconds, 1.4), label + " uses one 3.2-second intro and one 1.4-second result")
	_check(game.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, label + " uses nearest pixel filtering")
	_check(game.instruction_text.length() > 0 and game.instruction_text.length() < 35, label + " has a short English instruction")
	var intro: Variant = game._intro_view
	_check(intro.visible and not game.can_interact(), label + " blocks gameplay during its introduction")
	if entry.id == "crossing":
		_check(not game._inventory_label.is_visible_in_tree(), label + " hides its meters during the introduction")
		_check(game.level_node.preview.runtime_fullscreen and game.level_node.preview.position == Vector2.ZERO and game.level_node.preview.size == Vector2(1280, 720), label + " renders the campus across the complete game viewport")
	_check_label(intro.title_label, 70, Color("ffbf00"), label + " title")
	_check_label(intro.instruction_label, 28, Color.WHITE, label + " instruction")
	_check(_count_script(game, "res://scripts/ui/instruction_prompt.gd") == 1, label + " mounts exactly one introduction")
	var full_time: float = game.get_seconds_left()
	game._process(0.1)
	_check(is_equal_approx(game.get_seconds_left(), full_time), label + " freezes its timer during the introduction")
	var initial_alpha := _effective_alpha(intro.title_label)
	game._process(2.8)
	_check(game._prompt_left > 0.0 and _effective_alpha(intro.title_label) < initial_alpha, label + " fades its introduction before play")
	game.skip_intro()
	_check(game.can_interact() and not intro.visible and is_equal_approx(game.get_seconds_left(), full_time), label + " starts play immediately after skipping the single introduction")
	if entry.id == "crossing":
		_check(game._inventory_label.is_visible_in_tree(), label + " shows its meters during play")
	_check_no_repeated_instructions(game, label)
	_check_visible_type(game, label)
	_check_pixel_art(game, label)
	var timers: Array[Node] = game.find_children("InternalTimer", "Label", true, false)
	_check(timers.size() == 1 and timers[0].is_visible_in_tree(), label + " shows one unboxed timer during play")
	if timers.size() == 1:
		_check_label(timers[0], 28, Color("ffd166"), label + " timer")
		_check(timers[0].global_position.x <= 40.0 and timers[0].global_position.y <= 40.0, label + " places TIME in the top-left corner")
	var results: Array[bool] = []
	var finished: Array[bool] = []
	game.round_completed.connect(func(success: bool) -> void: results.append(success))
	game.result_finished.connect(func() -> void: finished.append(true))
	var kind: String = entry.scene.get_file().get_basename()
	_win_game(kind, game)
	_check(results == [true] and not game.can_interact(), label + " wins through its mechanic and locks further gameplay")
	if entry.id == "crossing":
		_check(not game._inventory_label.is_visible_in_tree(), label + " hides its meters during the result")
	var cue: Variant = game._result_view
	_check(cue.visible and finished.is_empty(), label + " holds the result before releasing its host")
	_check_label(cue.message_label, 42, Color("73e6a8"), label + " result")
	_check(cue.message_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER and cue.message_label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER, label + " centers its result message")
	_check(cue.get_word() == "CLEAR", label + " identifies success with a word as well as color")
	var result_time: float = game.get_seconds_left()
	game._finish_round(false, "Duplicate result")
	game._process(0.1)
	var result_alpha := _effective_alpha(cue.message_label)
	game._process(1.15)
	_check(results == [true] and finished.is_empty() and game._result_left > 0.0, label + " emits one result and waits through its readable interval")
	_check(_effective_alpha(cue.message_label) < result_alpha and is_equal_approx(game.get_seconds_left(), result_time), label + " fades the result without advancing gameplay")
	game._process(0.2)
	game._process(0.2)
	_check(finished == [true] and not cue.visible, label + " releases the host exactly once after the fade")
	await _dispose(game)

func _test_rejection_and_timeout_format() -> void:
	var game: Variant = _mount_game("canvas")
	if game == null:
		return
	var outcomes: Array[bool] = []
	game.round_completed.connect(func(success: bool) -> void: outcomes.append(success))
	_drop_canvas(game, game._files[1])
	_check(game.can_interact() and outcomes.is_empty() and game._feedback_view.visible, "Wrong actions show a rejection and permit retry without ending the round")
	_check_label(game._feedback_view.message_label, 28, Color("ffb38a"), "Rejected action")
	_check(game._feedback_view.shade.color.is_equal_approx(Color(0, 0, 0, 0.55)), "Rejection dims the scene by 55 percent")
	game._process(1.45)
	_check(not game._feedback_view.visible and game.can_interact(), "Rejected action fades on its own while play continues")
	_drop_canvas(game, game._files[1])
	_check(game._feedback_view.visible and is_equal_approx(game._feedback_left, 1.4) and outcomes.is_empty(), "Repeating the same rejected action renews feedback after its fade")
	game._process(1.45)
	var ui: Script = load("res://scripts/ui/microgame_ui.gd")
	ui.set_status(game._status_label, "SAME REJECTION", "warning")
	game._process(1.45)
	_check(not game._feedback_view.visible, "Shared status feedback completes its first fade")
	ui.set_status(game._status_label, "SAME REJECTION", "warning")
	_check(game._feedback_view.visible and is_equal_approx(game._feedback_left, 1.4), "Shared status bridge treats repeated equal text as a new action")
	game._seconds_left = 0.01
	game._process(0.02)
	_check(outcomes == [false] and game._result_view.get_word() == "MISS", "Deadline reports failure using a word and symbol as well as color")
	_check_label(game._result_view.message_label, 42, Color("ff9e9e"), "Time-out")
	_check(game._result_view.shade.color.is_equal_approx(Color(0, 0, 0, 0.55)), "Result dims the scene by 55 percent")
	await _dispose(game)

func _test_host_timer_visibility() -> void:
	var flow: Variant = _mount_flow()
	if flow != null:
		flow._start_stage(0)
		var game: Variant = flow._active_scene
		game.set_process(false)
		flow._hud._process(0.0)
		_check(not flow._hud.is_visible_in_tree(), "Week flow hides TIME during the introduction")
		game.skip_intro()
		flow._hud._process(0.0)
		_check(flow._hud.is_visible_in_tree() and flow._hud._timer_label.text.contains("TIME"), "Week flow shows its bound game's timer during play")
		game._finish_round(true, "TEST CLEAR")
		flow._hud._process(0.0)
		_check(not flow._hud.is_visible_in_tree(), "Week flow hides TIME during the result")
		await _dispose(flow)
	var launcher: Variant = load("res://scenes/debug/microgame_launcher.tscn").instantiate()
	root.add_child(launcher)
	launcher.set_process(false)
	for index: int in Catalog.ENTRIES.size():
		launcher.launch(index, 0, 2)
		var game: Variant = launcher._active
		DRIVER.freeze(game)
		launcher._hud._process(0.0)
		var name: String = Catalog.ENTRIES[index].id
		_check(not launcher._hud.is_visible_in_tree(), name + " launcher initially hides its shared TIME when native UI or an introduction owns the screen")
		game.skip_intro()
		_tick_game(game, 0.05)
		launcher._hud._process(0.0)
		if game.uses_native_hud():
			_check(not launcher._hud.is_visible_in_tree() and _game_body(game)._timer_label.is_visible_in_tree(), name + " launcher keeps the native timer and hides the shared timer during play")
		else:
			_check(launcher._hud.is_visible_in_tree() and launcher._hud._timer_label.text.contains("TIME"), name + " launcher shows its bound game's timer during play")
		_finish_game(game, true, "TEST CLEAR")
		launcher._hud._process(0.0)
		_check(not launcher._hud.is_visible_in_tree(), name + " launcher hides TIME during the result")
		_tick_game(game, 1.5)
		await process_frame
	await _dispose(launcher)

func _test_crossing_notice_fade() -> void:
	var game: Variant = _mount_game("crossing")
	if game == null:
		return
	game.simulation.notice = "Collected: token"
	game._process(0.01)
	_check(game._feedback_view.visible, "Crossing shows a new pickup notice")
	game._process(0.75)
	game._process(0.75)
	_check(not game._feedback_view.visible and game.can_interact(), "An unchanged Crossing notice cannot restart feedback every frame")
	await _dispose(game)

func _test_standalone_metadata(entry: Dictionary) -> void:
	var kind: String = entry.scene.get_file().get_basename()
	var game: Variant = _mount_game(kind, false, 3.2)
	if game == null:
		return
	if entry.id in NATIVE_DURATIONS:
		_check(game.get_script().resource_path == "res://scripts/microgames/%s.gd" % kind and game._timer_label.is_visible_in_tree(), "%s standalone F6 retains its unwrapped implementation and timer" % entry.id)
		_check(_count_script(game, "res://scripts/ui/instruction_prompt.gd") == 0 and _count_script(game, "res://scripts/ui/result_cue.gd") == 0, "%s standalone F6 has no shared presentation added" % entry.id)
		await _dispose(game)
		return
	_check(not game.game_title.is_empty() and not game.instruction_text.is_empty() and game.instruction_text.length() < 35, "%s supplies its title and short instruction during standalone F6 play" % entry.id)
	_check(game._intro_view.title_label.text == game.game_title and game._intro_view.instruction_label.text == game.instruction_text, "%s presents the same standalone metadata through the shared intro" % entry.id)
	await _dispose(game)

func _test_intro_click_skip() -> void:
	var game: Variant = _mount_game("canvas", true, 3.2)
	if game == null:
		return
	await process_frame
	var full_time: float = game.get_seconds_left()
	var click := InputEventMouseButton.new()
	click.position = Vector2(640, 360)
	click.global_position = click.position
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(click, true)
	click = click.duplicate()
	click.pressed = false
	click.button_mask = 0
	root.push_input(click, true)
	_check(game.can_interact() and game._prompt_left == 0.0 and is_equal_approx(game.get_seconds_left(), full_time), "A real mouse click skips the whole introduction without spending round time")
	await _dispose(game)

func _check_label(node: Label, size: int, color: Color, context: String) -> void:
	_check(node.get_theme_font("font").resource_path == PIXEL_FONT_PATH and node.get_theme_font_size("font_size") == size, context + " uses AggiePixel at the prescribed size")
	_check(node.get_theme_color("font_color").is_equal_approx(color), context + " uses the prescribed color")
	_check(node.get_theme_color("font_shadow_color").is_equal_approx(Color("14121a")) and node.get_theme_constant("shadow_offset_x") == size / 7 and node.get_theme_constant("shadow_offset_y") == size / 7, context + " uses a one-font-pixel dark shadow")

func _effective_alpha(node: CanvasItem) -> float:
	var alpha := node.self_modulate.a
	var current: Node = node
	while current != null:
		if current is CanvasItem:
			alpha *= current.modulate.a
		current = current.get_parent()
	return alpha

func _check_no_repeated_instructions(game: Node, context: String) -> void:
	var visible_duplicates: Array[String] = []
	for node: Node in game.find_children("*", "Label", true, false):
		var text_label := node as Label
		if text_label.is_visible_in_tree() and text_label.text in [game.game_title, game.instruction_text]:
			visible_duplicates.append(text_label.text)
	_check(visible_duplicates.is_empty(), context + " removes titles and instructions from active play")

func _check_visible_type(game: Node, context: String) -> void:
	var invalid: Array[String] = []
	for node: Node in game.find_children("*", "Control", true, false):
		if not node.is_visible_in_tree() or not (node is Label or node is Button):
			continue
		var font: Font = node.get_theme_font("font")
		var size: int = node.get_theme_font_size("font_size")
		if font.resource_path != PIXEL_FONT_PATH or size % 7 != 0:
			invalid.append(String(node.get_path()))
	_check(invalid.is_empty(), context + " keeps visible interface type in AggiePixel at whole-pixel sizes: " + str(invalid))

func _check_pixel_art(game: Node, context: String) -> void:
	var invalid: Array[String] = []
	var displayed := 0
	for node: Node in game.find_children("*", "TextureRect", true, false):
		var art := node as TextureRect
		if not art.is_visible_in_tree() or art.texture == null or art.get_viewport() != root:
			continue
		displayed += 1
		var pixel_scale: Vector2 = art.size * art.get_global_transform_with_canvas().get_scale() / art.texture.get_size()
		if not pixel_scale.is_equal_approx(Vector2(5, 5)):
			invalid.append("%s: %s" % [art.get_path(), pixel_scale])
	_check(displayed > 0 and invalid.is_empty(), context + " displays scene pixels at exactly 5x: " + str(invalid))
