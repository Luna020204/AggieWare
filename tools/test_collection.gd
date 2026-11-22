extends SceneTree
## Collection integration checks. No test framework dependency.
## godot --headless --path . --script res://tools/test_collection.gd

const GAME_PATHS := {
	"canvas": "res://scenes/microgames/canvas.tscn",
	"schedule_builder": "res://scenes/microgames/schedule_builder.tscn",
	"stay_focused": "res://scenes/microgames/stay_focused.tscn",
	"gates": "res://scenes/microgames/gates.tscn",
	"crossing": "res://scenes/microgames/crossing.tscn",
	"variable_scope": "res://scenes/microgames/variable_scope.tscn",
	"swipe_card": "res://scenes/microgames/swipe_card.tscn",
	"stay_awake": "res://scenes/microgames/stay_awake.tscn",
	"microscope": "res://scenes/microgames/microscope.tscn",
}
const NATIVE_KINDS := ["variable_scope", "swipe_card", "stay_awake", "microscope"]
const DRIVER := preload("res://tools/microgame_test_driver.gd")
const PAUSE_SCRIPT := "res://scripts/ui/settings_pause_menu.gd"
const HUD_SCRIPT := "res://scripts/ui/game_hud.gd"
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await _run_suite(true)

func _run_suite(thorough: bool) -> void:
	# A script error must fail CI rather than leave an idle SceneTree running.
	create_timer(25.0, true).timeout.connect(func() -> void:
		push_error("Collection tests exceeded their deadline.")
		quit(1))
	if thorough:
		_test_input_contract()
		await _test_round_lifecycle()
		await _test_individual_mechanics()
		await _test_custom_scene_instruction()
		await _test_native_host_lifecycle()
	await _test_week_flow()
	await _test_failure_and_stale_callbacks()
	if thorough:
		await _test_crossing_pause_and_collision()
	print("Collection checks: %d; failures: %d" % [checks, failures])
	if failures == 0:
		print("COLLECTION_TESTS_OK" if thorough else "FLOW_SMOKE_OK")
	# Do not overwrite a failing assertion's exit status with a later quit(0).
	quit(1 if failures > 0 else 0)

func _check(condition: bool, message: String) -> bool:
	checks += 1
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
	return condition

func _test_input_contract() -> void:
	var actions: Variant = root.get_node("InputActions")
	var action: StringName = actions.ACTION_RIGHT
	var original := InputMap.action_get_events(action)
	InputMap.action_erase_events(action)
	var custom := InputEventKey.new()
	custom.physical_keycode = KEY_J
	InputMap.action_add_event(action, custom)
	actions._ensure_default_actions()
	var updated := InputMap.action_get_events(action)
	_check(updated.size() == 1 and updated[0] is InputEventKey and updated[0].physical_keycode == KEY_J, "Input bootstrap preserves customized bindings")
	_check(actions.action_label(action) == "J", "Custom physical key labels show J without engine-only suffixes")
	_check(actions.action_label(actions.ACTION_RETRY) == "R", "Default retry key label is the readable letter R")
	InputMap.action_erase_events(action)
	for event: InputEvent in original:
		InputMap.action_add_event(action, event)
	_check(InputMap.has_action(actions.ACTION_LEFT) and InputMap.has_action(actions.ACTION_PAUSE), "Shared movement and pause actions exist")

func _mount_game(kind: String, managed := true, intro_seconds := 0.0, difficulty := 0) -> Variant:
	var packed: PackedScene = load(GAME_PATHS[kind])
	if not _check(packed != null, "Load " + kind):
		return null
	var game: Variant
	if kind in NATIVE_KINDS and managed:
		var catalog: Script = load("res://scripts/core/microgame_catalog.gd")
		game = catalog.instantiate(catalog.find_by_scene(GAME_PATHS[kind]), difficulty)
	else:
		game = packed.instantiate()
		if not kind in NATIVE_KINDS:
			game.managed_by_flow = managed
			game.show_internal_timer = not managed
			game.prompt_seconds = intro_seconds
	game.difficulty = difficulty
	root.add_child(game)
	DRIVER.freeze(game)
	if intro_seconds <= 0.0:
		DRIVER.skip_intro(game)
	return game

func _game_body(game: Variant) -> Variant:
	return DRIVER.body(game)

func _tick_game(game: Variant, delta: float) -> void:
	DRIVER.tick(game, delta)

func _finish_game(game: Variant, success: bool, message := "TEST RESULT") -> void:
	DRIVER.finish(game, success, message)

func _mount_flow() -> Variant:
	var packed: PackedScene = load("res://scenes/core/game_flow.tscn")
	if not _check(packed != null, "Load collection flow"):
		return null
	var flow: Variant = packed.instantiate()
	flow.result_delay = 0.001
	# Advance result presentation and bike transitions deterministically.
	flow.bike_duration = 999.0
	root.add_child(flow)
	flow.set_process(false)
	return flow

func _prepare_round(flow: Variant) -> Variant:
	var game: Variant = flow._active_scene
	if not _check(is_instance_valid(game) and game.has_method("can_interact"), "Flow mounted a microgame"):
		return null
	DRIVER.freeze(game)
	DRIVER.skip_intro(game)
	return game

func _dispose(node: Node) -> void:
	root.get_node("GameState").resume_game()
	if is_instance_valid(node):
		node.queue_free()
	await process_frame

func _wait_result(flow: Variant) -> void:
	if flow.state == flow.FlowState.RESULT and is_instance_valid(flow._active_scene):
		_tick_game(flow._active_scene, 1.5)
	await process_frame

func _finish_bike(flow: Variant) -> void:
	if not _check(flow.state == flow.FlowState.TRANSITION, "Bike transition is present"):
		return
	var bike: Variant = flow._active_scene
	bike.set_process(false)
	_check(bike.lives == flow.lives and bike.score == flow.score, "Bike receives score and lives")
	bike._finish_transition()
	_check(flow.state == flow.FlowState.PLAYING, "Bike starts the next round")

func _test_round_lifecycle() -> void:
	var game: Variant = _mount_game("canvas", false, 0.25)
	if game == null:
		return
	await process_frame
	_check(not game.can_interact(), "Intro prompt blocks game input")
	var initial_time: float = game.get_seconds_left()
	game._on_submit_pressed()
	game._process(0.1)
	_check(not game._ended and is_equal_approx(game.get_seconds_left(), initial_time), "Intro consumes no round time")
	game._process(0.2)
	_check(game.can_interact(), "Round becomes interactive after the prompt")
	_check(_count_script(game, PAUSE_SCRIPT) == 1, "Standalone game has one pause overlay")
	var outcomes: Array[bool] = []
	game.round_completed.connect(func(success: bool) -> void: outcomes.append(success))
	game._finish_round(false, "Test loss")
	game._finish_round(true, "Duplicate completion")
	game._process(0.2)
	_check(outcomes == [false], "Base emits one result even after duplicate completion")
	_check(is_equal_approx(game.get_seconds_left(), initial_time), "Finished round stops its countdown")
	game.prompt_seconds = 0.0
	game._start_round()
	_check(game.can_interact() and is_equal_approx(game.get_seconds_left(), initial_time) and game._files.size() == 2, "Standalone retry resets state, timer, and cards")
	await _dispose(game)
	for kind: String in GAME_PATHS:
		var timed: Variant = _mount_game(kind)
		if timed == null:
			continue
		var results: Array[bool] = []
		timed.round_completed.connect(func(success: bool) -> void: results.append(success))
		_game_body(timed)._seconds_left = 0.005
		_tick_game(timed, 0.01)
		var expected: bool = kind in ["stay_focused", "stay_awake"]
		_check(timed.is_round_finished() and results == [expected], kind + " resolves its deadline correctly")
		_finish_game(timed, not expected, "Duplicate deadline")
		_check(results.size() == 1, kind + " emits one deadline result")
		await _dispose(timed)

func _test_individual_mechanics() -> void:
	var canvas: Variant = _mount_game("canvas")
	if canvas != null:
		_drop_canvas(canvas, canvas._files[1])
		_check(canvas._placed_file == null and not canvas._ended, "Canvas rejects the decoy upload")
		_win_canvas(canvas)
		_check(canvas._ended, "Canvas upload and submit wins")
		canvas._on_submit_pressed()
		_check(canvas._ended, "Hosted Canvas cannot restart from its result button")
		await _dispose(canvas)
	var schedule: Variant = _mount_game("schedule_builder")
	if schedule != null:
		schedule._register(0)
		_check(schedule._registered == 0, "Schedule rejects registration before opening")
		schedule._seconds_left = schedule._round_seconds - schedule.OPEN_DELAY
		schedule._register(0)
		schedule._register(0)
		_check(schedule._registered == 1, "Schedule cannot register a class twice")
		for index: int in schedule._buttons.size():
			schedule._register(index)
		_check(schedule._ended and schedule._registered == schedule._buttons.size(), "Registering every class wins")
		await _dispose(schedule)
	var focus: Variant = _mount_game("stay_focused")
	if focus != null:
		focus._spawn_thought()
		focus._thoughts[0].position = focus._shield.position
		focus._process(0.01)
		_check(focus._blocked == 1, "Focus shield intercepts a thought")
		focus._spawn_thought()
		focus._thoughts[0].position = Vector2(0, 610)
		focus._process(0.01)
		_check(focus._missed == 1 and not focus._ended, "One missed thought does not end the round")
		for attempt: int in focus.MISS_LIMITS[focus.difficulty]:
			if focus._ended:
				break
			focus._spawn_thought()
			focus._thoughts[0].position = Vector2(0, 610)
			focus._process(0.01)
		_check(focus._ended and focus._missed == focus.MISS_LIMITS[focus.difficulty], "Focus loses at its distraction limit")
		await _dispose(focus)
	var gates: Variant = _mount_game("gates")
	if gates != null:
		for card: Button in gates._cards:
			if card.get_meta("kind") == "GATE" and card.get_meta("value") != gates._gate_name:
				_drop_gate(gates, card)
				break
		_check(not gates._placed.has("GATE") and not gates._ended, "Logic Gates rejects an incorrect gate")
		_win_gates(gates)
		_check(gates._ended, "Matching gate and inputs completes the circuit")
		await _dispose(gates)

func _test_week_flow() -> void:
	var flow: Variant = _mount_flow()
	if flow == null:
		return
	var cleared: Array[int] = []
	flow.stage_cleared.connect(func(day: int) -> void: cleared.append(day))
	flow._show_stage_select()
	flow._start_stage(0)
	if not _check(flow.week_plan.stages.size() == 5 and flow.week_plan.stages[0].games.size() == 2, "Default week includes two Monday games and five days"):
		await _dispose(flow)
		return
	var completed := 0
	var saw_crossing := false
	for day: int in flow.week_plan.stages.size():
		var stage: Variant = flow.week_plan.stages[day]
		for round_index: int in stage.games.size():
			_check(flow.state == flow.FlowState.PLAYING and flow.current_stage == day and flow.current_round == round_index, "Correct day and round are active")
			var game: Variant = _prepare_round(flow)
			if game == null:
				await _dispose(flow)
				return
			_check(game.managed_by_flow and not game.show_internal_timer, "Host owns microgame navigation and timer")
			_check(is_instance_valid(flow._hud) and _count_script(flow, HUD_SCRIPT) == 1, "Exactly one shared HUD is mounted")
			_check(_count_script(flow, PAUSE_SCRIPT) == 1, "Exactly one shared pause overlay is mounted")
			var kind: String = stage.games[round_index].scene_path.get_file().get_basename()
			saw_crossing = saw_crossing or kind == "crossing"
			_win_game(kind, game)
			_check(game._ended, kind + " wins through its game mechanic")
			completed += 1
			_check(flow.state == flow.FlowState.RESULT, "Completion immediately enters result state")
			game.round_completed.emit(true)
			_check(flow.score == completed * 100 and flow.lives == 3, "Success updates score exactly once")
			await _wait_result(flow)
			if round_index + 1 < stage.games.size():
				_check(cleared.size() == day, "Day remains open until all of its games finish")
				_finish_bike(flow)
			else:
				_check(flow.state == flow.FlowState.STAGE_CLEAR, "Finishing every game clears the day")
				flow._advance_after_clear()
				if day + 1 < flow.week_plan.stages.size():
					_finish_bike(flow)
	_check(saw_crossing and completed == 6, "Complete week plays all six rounds including Crossing")
	_check(cleared == [0, 1, 2, 3, 4] and flow.state == flow.FlowState.TITLE, "Friday returns to title with each day cleared once")
	await _dispose(flow)

func _test_custom_scene_instruction() -> void:
	# A newly authored scene is valid without a debug-catalog entry.
	var source: PackedScene = load(GAME_PATHS["canvas"])
	var custom: Variant = source.instantiate()
	var instruction := "PLACE THE ASSIGNMENT FILE."
	custom.instruction_text = instruction
	var packed := PackedScene.new()
	var pack_result := packed.pack(custom)
	custom.free()
	if not _check(pack_result == OK, "Pack a custom microgame fixture"):
		return
	var scene_path := "user://validation_custom_canvas_%d.tscn" % OS.get_process_id()
	if not _check(ResourceSaver.save(packed, scene_path) == OK, "Save a custom microgame outside the catalog"):
		return
	var flow: Variant = _mount_flow()
	if flow != null:
		flow.week_plan = flow.week_plan.duplicate(true)
		flow.week_plan.stages[0].games[0].scene_path = scene_path
		flow._start_stage(0)
		var game: Variant = flow._active_scene
		_check(game.instruction_text == instruction and game._intro_view.instruction_label.text == instruction, "WeekPlan preserves scene-authored instructions when the scene is absent from the debug catalog")
		await _dispose(flow)
	_check(DirAccess.remove_absolute(ProjectSettings.globalize_path(scene_path)) == OK, "Remove the temporary custom microgame fixture")

func _test_native_host_lifecycle() -> void:
	var catalog: Script = load("res://scripts/core/microgame_catalog.gd")
	var flow: Variant = _mount_flow()
	if flow == null:
		return
	flow.week_plan = flow.week_plan.duplicate(true)
	# Native games are supported in an authored WeekPlan, not only the launcher.
	for kind: String in NATIVE_KINDS:
		flow.week_plan.stages[1].games[0].scene_path = GAME_PATHS[kind]
		flow._start_stage(1)
		var session: Variant = flow._active_scene
		DRIVER.freeze(session)
		var native: Variant = _game_body(session)
		_check(session.uses_native_hud() and native.get_script().resource_path == "res://scripts/microgames/%s.gd" % kind, kind + " is hosted through its unchanged native implementation")
		_check(_count_script(flow, PAUSE_SCRIPT) == 1 and _count_script(flow, HUD_SCRIPT) == 1, kind + " has exactly one host pause overlay and one hidden host HUD")
		flow._hud._process(0.0)
		_check(not flow._hud.visible and native.show_internal_timer, kind + " retains its native timer without a duplicate host timer")
		var full: float = session.get_round_seconds()
		var has_intro := kind in ["swipe_card", "stay_awake", "microscope"]
		_check(is_equal_approx(session.get_intro_seconds(), 3.2 if has_intro else 0.0) and session.is_playing() != has_intro, kind + " retains its authored intro policy")
		DRIVER.skip_intro(session)
		_tick_game(session, 0.1)
		_check(session.can_interact() and is_equal_approx(session.get_seconds_left(), full - 0.1), kind + " advances only its native countdown")
		var before_pause: float = session.get_seconds_left()
		root.get_node("GameState").pause_game()
		_tick_game(session, 0.5)
		_check(is_equal_approx(session.get_seconds_left(), before_pause) and not session.can_interact(), kind + " freezes during the shared pause")
		root.get_node("GameState").resume_game()
		if kind == "variable_scope":
			await _check_scope_font(native, "Week flow")
		var results: Array[bool] = []
		session.round_completed.connect(func(success: bool) -> void: results.append(success))
		var expected_score: int = flow.score + 100
		_win_game(kind, session)
		_check(results == [true] and flow.state == flow.FlowState.RESULT and flow.score == expected_score, kind + " forwards one mechanic win into the collection")
		native.round_completed.emit(true)
		_check(results == [true] and flow.score == expected_score, kind + " ignores duplicate native completion")
		var accepted_card_position: Vector2 = native._card.position if kind == "swipe_card" else Vector2.ZERO
		root.get_node("GameState").pause_game()
		_tick_game(session, 2.0)
		_check(flow.state == flow.FlowState.RESULT, kind + " holds native results while paused")
		if kind == "swipe_card":
			_check(native._card.position == accepted_card_position, "Pausing a successful Swipe result preserves the accepted card position")
		root.get_node("GameState").resume_game()
		_tick_game(session, 1.0)
		_check(flow.state == flow.FlowState.RESULT, kind + " does not truncate its native readable result interval")
		_tick_game(session, 0.5)
		_check(flow.state == flow.FlowState.STAGE_CLEAR, kind + " advances once after the native result completes")
	await _dispose(flow)
	# Relaunching reconstructs native game state; native scripts do not promise
	# that changing difficulty in place rebuilds their authored scene objects.
	var launcher: Variant = load("res://scenes/debug/microgame_launcher.tscn").instantiate()
	root.add_child(launcher)
	for difficulty: int in [0, 2, 0, 1]:
		launcher.launch(catalog.find_index("swipe"), difficulty, 2)
		var session: Variant = launcher._active
		DRIVER.freeze(session)
		DRIVER.skip_intro(session)
		var native: Variant = _game_body(session)
		var ids: Array = native._cards.map(func(card: TextureRect) -> String: return native.card_id(card))
		_check(ids.size() == difficulty + 2 and ids.count("aggie") == 1, "Swipe relaunch rebuilds the correct wallet at difficulty %d" % difficulty)
		native.begin_drag(native._card.position + native.CARD_SIZE * 0.5)
		_check(native._dragging, "Swipe enters an active drag before relaunch")
	launcher.launch(catalog.find_index("scope"), 2, 2)
	DRIVER.freeze(launcher._active)
	await _check_scope_font(_game_body(launcher._active), "Launcher")
	var session: Variant = launcher._active
	var obsolete: Variant = session.native_game
	var old_token: int = launcher._run_token
	session.restart_round()
	DRIVER.freeze(session)
	obsolete.round_completed.emit(true)
	obsolete.time_changed.emit(-9.0, 99.0)
	launcher._on_result_finished(old_token - 1)
	_check(launcher._running and not session.is_round_finished() and is_equal_approx(session.get_seconds_left(), session.get_round_seconds()), "Native restart ignores old game results, clock updates, and host callbacks")
	_check(obsolete.get_parent() == null and session.native_game != obsolete, "Native restart detaches the old implementation immediately")
	await _dispose(launcher)

func _check_scope_font(hosted: Variant, context: String) -> void:
	var standalone: Variant = load(GAME_PATHS["variable_scope"]).instantiate()
	root.add_child(standalone)
	standalone.set_process(false)
	var actual: Font = hosted._choice_buttons[0].get_theme_font("font")
	var expected: Font = standalone._choice_buttons[0].get_theme_font("font")
	_check(actual is SystemFont and expected is SystemFont and actual.font_names == expected.font_names and actual.resource_path != "res://assets/fonts/aggie_pixel.fnt", context + " preserves Scope's case-sensitive standalone choice font")
	_check(hosted._code_label.get_theme_font("normal_font") is SystemFont, context + " preserves the monospace code font")
	for field: String in ["_status_label", "_timer_label"]:
		var label: Label = hosted.get(field)
		var raw: Label = standalone.get(field)
		_check(label.get_theme_font("font") == raw.get_theme_font("font") and label.get_theme_color("font_shadow_color") == raw.get_theme_color("font_shadow_color") and label.get_theme_constant("shadow_offset_x") == raw.get_theme_constant("shadow_offset_x") and label.get_theme_constant("shadow_offset_y") == raw.get_theme_constant("shadow_offset_y"), context + " isolates native %s typography from the host theme" % field)
	await _dispose(standalone)

func _test_failure_and_stale_callbacks() -> void:
	var flow: Variant = _mount_flow()
	if flow == null:
		return
	flow._start_stage(0)
	var old_game: Variant = _prepare_round(flow)
	var old_token: int = flow._run_token
	flow._start_stage(1)
	var current_timer_text: String = flow._hud._timer_label.text
	old_game.round_completed.emit(true)
	old_game.time_changed.emit(-900.0, 900.0)
	old_game.result_finished.emit()
	flow._on_round_completed(true, old_token)
	_check(flow.state == flow.FlowState.PLAYING and flow.current_stage == 1 and flow.score == 0 and flow.lives == 3, "Replaced game cannot report a late result")
	_check(flow._hud._timer_label.text == current_timer_text, "Replaced game cannot overwrite the new HUD timer")
	_check(old_game.get_parent() == null, "Replaced content detaches immediately")
	flow._start_stage(0)
	_win_canvas(_prepare_round(flow))
	flow._start_stage(1)
	await _wait_result(flow)
	_check(flow.state == flow.FlowState.PLAYING and flow.current_stage == 1, "Old result timer cannot replace a new scene")
	flow.score = 0
	flow.lives = 3
	flow._start_stage(0)
	for loss: int in 3:
		var game: Variant = _prepare_round(flow)
		game._finish_round(false, "Test failure")
		game.round_completed.emit(false)
		_check(flow.lives == 2 - loss and flow.score == 0, "Failure removes exactly one life")
		await _wait_result(flow)
		if loss < 2:
			_finish_bike(flow)
	_check(flow.state == flow.FlowState.GAME_OVER, "Three failures end the week")
	flow._retry_stage()
	_check(flow.state == flow.FlowState.PLAYING and flow.lives == 3 and flow.score == 0 and flow.current_round == 0, "Retry resets lives, score, and day progress")
	var state_node: Variant = root.get_node("GameState")
	_prepare_round(flow)._finish_round(false, "Pause during result")
	state_node.pause_game()
	await _wait_result(flow)
	_check(flow.state == flow.FlowState.RESULT and flow.lives == 2, "Pause holds the result timer without consuming another life")
	state_node.resume_game()
	await _wait_result(flow)
	if _check(flow.state == flow.FlowState.TRANSITION, "Resuming a result continues into its transition"):
		var bike: Variant = flow._active_scene
		bike.set_process(false)
		bike._process(0.1)
		var bike_elapsed: float = bike._elapsed
		var bike_position: Vector2 = bike._bike.position
		state_node.pause_game()
		bike._process(0.2)
		await process_frame
		_check(is_equal_approx(bike._elapsed, bike_elapsed) and bike._bike.position == bike_position, "Pause freezes bike transition time and movement")
		state_node.resume_game()
		bike._process(0.1)
		_check(bike._elapsed > bike_elapsed, "Resume continues the bike transition")
		flow._start_stage(1)
		bike.transition_finished.emit("")
		_check(flow.state == flow.FlowState.PLAYING and flow.current_stage == 1, "Replaced bike cannot advance the new round")
	await _dispose(flow)

func _test_crossing_pause_and_collision() -> void:
	var game: Variant = _mount_game("crossing", false)
	if game == null:
		return
	await process_frame
	var state_node: Variant = root.get_node("GameState")
	var actions: Variant = root.get_node("InputActions")
	var initial_x: float = game.simulation.player.x
	Input.action_press(actions.ACTION_RIGHT)
	game._process(0.1)
	Input.action_release(actions.ACTION_RIGHT)
	_check(game.simulation.player.x > initial_x, "Crossing supports horizontal movement through shared actions")
	var before_long_frame: float = game.get_seconds_left()
	var simulation_before: float = game.simulation.elapsed
	game._process(0.75)
	_check(is_equal_approx(before_long_frame - game.get_seconds_left(), 0.75) and is_equal_approx(game.simulation.elapsed - simulation_before, 0.75), "Crossing traffic and shared countdown consume the same long frame")
	if not _check(not game.simulation.vehicles.is_empty(), "Crossing spawns authored traffic"):
		await _dispose(game)
		return
	var seconds: float = game.get_seconds_left()
	var elapsed: float = game.simulation.elapsed
	var position: Vector2 = game.simulation.player
	var car_position: Vector2 = game.simulation.vehicles[0].position
	state_node.pause_game()
	Input.action_press(actions.ACTION_RIGHT)
	game._process(0.1)
	await process_frame
	Input.action_release(actions.ACTION_RIGHT)
	_check(paused and state_node.is_paused, "Pause state and scene tree agree")
	_check(is_equal_approx(game.get_seconds_left(), seconds) and is_equal_approx(game.simulation.elapsed, elapsed), "Pause freezes both shared timer and simulation clock")
	_check(game.simulation.player == position and game.simulation.vehicles[0].position == car_position, "Pause freezes player and traffic")
	state_node.resume_game()
	game._process(0.1)
	_check(game.get_seconds_left() < seconds and game.simulation.elapsed > elapsed, "Resume advances the existing round")
	var outcomes: Array[bool] = []
	game.round_completed.connect(func(success: bool) -> void: outcomes.append(success))
	game.hooks.variables["shields"] = 0
	game.simulation.invulnerable = 0.0
	game.simulation.vehicles[0].position = game.simulation.player
	game.simulation.vehicles[0].previous = game.simulation.player
	game.simulation.vehicles[0].speed = 0.0
	game._process(0.01)
	game._process(0.2)
	_check(game.simulation.state == "crashed" and game._ended and outcomes == [false], "Traffic collision reports exactly one loss to the host contract")
	await _dispose(game)

func _win_game(kind: String, session: Variant) -> void:
	var game: Variant = _game_body(session)
	match kind:
		"canvas": _win_canvas(game)
		"schedule_builder":
			game._seconds_left = game._round_seconds - game.OPEN_DELAY
			for index: int in game._buttons.size():
				game._register(index)
		"stay_focused":
			for thought: Control in game._thoughts.duplicate():
				game._remove_thought(thought)
			game._seconds_left = 0.005
			game._process(0.01)
		"gates": _win_gates(game)
		"variable_scope":
			for choice: Button in game._choice_buttons:
				if choice.get_meta("correct", false):
					game._choose(choice)
					break
		"stay_awake":
			for z: Button in game._zs.duplicate():
				game.pop_z(z)
			game._seconds_left = 0.005
			game._process(0.01)
		"microscope":
			game.camera = game._target_pos
			game.confirm()
		"swipe_card": _win_swipe(game)
		"crossing":
			game.simulation.vehicles.clear()
			game.simulation.schedules.clear()
			var data: Script = load("res://scripts/crossing/level_data.gd")
			game.simulation.player = data.cell_center(game.simulation.level.goal) + Vector2(0, 20)
			var actions: Variant = root.get_node("InputActions")
			Input.action_press(actions.ACTION_UP)
			game._process(0.1)
			Input.action_release(actions.ACTION_UP)
		_: _check(false, "Unknown game mechanic: " + kind)

func _win_swipe(game: Variant) -> void:
	var window: Vector2 = game.get_speed_window()
	var speed := (window.x + window.y) * 0.5
	var card: TextureRect = game._card
	var y: float = game._scanner.position.y + game._scanner.size.y * 0.5
	var start := Vector2(game.card_home(card).x + game.CARD_SIZE.x * 0.5, y)
	game.begin_drag(card.position + game.CARD_SIZE * 0.5, card)
	card.position = start - game.CARD_SIZE * 0.5
	game._drag_offset = game.CARD_SIZE * 0.5
	var left: float = game._scanner.position.x
	var right: float = left + game._scanner.size.x
	var usec := 1000000
	var x: float = start.x
	for step_index: int in 200:
		if not game._dragging or x > right + 40.0:
			break
		game.drag_to(Vector2(x, y), usec)
		x += 20.0
		if x >= left:
			usec += int(20.0 / speed * 1000000.0)
	game.release()

func _left_press() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = Vector2(5, 5)
	return event

func _drop_canvas(game: Variant, card: Control) -> void:
	game._on_file_gui_input(_left_press(), card)
	card.global_position = game._drop_zone.global_position + (game._drop_zone.size - card.size) * 0.5
	game._finish_drag()

func _win_canvas(game: Variant) -> void:
	for card: Control in game._files:
		if card.get_meta("is_target", false):
			_drop_canvas(game, card)
			break
	game._on_submit_pressed()

func _drop_gate(game: Variant, card: Button) -> void:
	game._on_card_input(_left_press(), card)
	var zone: Control = game._zones[card.get_meta("kind")]
	card.global_position = zone.global_position + (zone.size - card.size) * 0.5
	game._finish_drag()

func _win_gates(game: Variant) -> void:
	for card: Button in game._cards:
		if card.get_meta("kind") != "GATE" or card.get_meta("value") == game._gate_name:
			_drop_gate(game, card)

func _count_script(node: Node, path: String) -> int:
	var count := 0
	var script: Script = node.get_script()
	if script != null and script.resource_path == path:
		count += 1
	for child: Node in node.get_children():
		count += _count_script(child, path)
	return count
