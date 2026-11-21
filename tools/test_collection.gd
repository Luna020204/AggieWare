extends SceneTree
## Collection integration checks. No test framework dependency.
## godot --headless --path . --script res://tools/test_collection.gd

const GAME_PATHS := {
	"canvas": "res://scenes/microgames/canvas.tscn",
	"schedule_builder": "res://scenes/microgames/schedule_builder.tscn",
	"stay_focused": "res://scenes/microgames/stay_focused.tscn",
	"gates": "res://scenes/microgames/gates.tscn",
	"crossing": "res://scenes/microgames/crossing.tscn",
}
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
	InputMap.action_erase_events(action)
	for event: InputEvent in original:
		InputMap.action_add_event(action, event)
	_check(InputMap.has_action(actions.ACTION_LEFT) and InputMap.has_action(actions.ACTION_PAUSE), "Shared movement and pause actions exist")

func _mount_game(kind: String, managed := true, intro_seconds := 0.0) -> Variant:
	var packed: PackedScene = load(GAME_PATHS[kind])
	if not _check(packed != null, "Load " + kind):
		return null
	var game: Variant = packed.instantiate()
	game.managed_by_flow = managed
	game.show_internal_timer = not managed
	game.prompt_seconds = intro_seconds
	root.add_child(game)
	game.set_process(false)
	return game

func _mount_flow() -> Variant:
	var packed: PackedScene = load("res://scenes/core/game_flow.tscn")
	if not _check(packed != null, "Load collection flow"):
		return null
	var flow: Variant = packed.instantiate()
	flow.result_delay = 0.001
	# Complete bike transitions manually; only the result boundary waits.
	flow.bike_duration = 999.0
	root.add_child(flow)
	flow.set_process(false)
	return flow

func _prepare_round(flow: Variant) -> Variant:
	var game: Variant = flow._active_scene
	if not _check(is_instance_valid(game) and game.has_method("can_interact"), "Flow mounted a microgame"):
		return null
	game.set_process(false)
	game.prompt_seconds = 0.0
	game._start_round()
	return game

func _dispose(node: Node) -> void:
	root.get_node("GameState").resume_game()
	if is_instance_valid(node):
		node.queue_free()
	await process_frame

func _wait_result() -> void:
	await create_timer(0.015, true).timeout

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
		timed._seconds_left = 0.005
		timed._process(0.01)
		var expected: bool = kind == "stay_focused"
		_check(timed._ended and results == [expected], kind + " resolves its deadline correctly")
		timed._finish_round(not expected, "Duplicate deadline")
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
		schedule._seconds_left = schedule.WINDOWS[schedule.difficulty]
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
			await _wait_result()
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
	flow._on_round_completed(true, old_token)
	_check(flow.state == flow.FlowState.PLAYING and flow.current_stage == 1 and flow.score == 0 and flow.lives == 3, "Replaced game cannot report a late result")
	_check(flow._hud._timer_label.text == current_timer_text, "Replaced game cannot overwrite the new HUD timer")
	_check(old_game.get_parent() == null, "Replaced content detaches immediately")
	flow._start_stage(0)
	_win_canvas(_prepare_round(flow))
	flow._start_stage(1)
	await _wait_result()
	_check(flow.state == flow.FlowState.PLAYING and flow.current_stage == 1, "Old result timer cannot replace a new scene")
	flow.score = 0
	flow.lives = 3
	flow._start_stage(0)
	for loss: int in 3:
		var game: Variant = _prepare_round(flow)
		game._finish_round(false, "Test failure")
		game.round_completed.emit(false)
		_check(flow.lives == 2 - loss and flow.score == 0, "Failure removes exactly one life")
		await _wait_result()
		if loss < 2:
			_finish_bike(flow)
	_check(flow.state == flow.FlowState.GAME_OVER, "Three failures end the week")
	flow._retry_stage()
	_check(flow.state == flow.FlowState.PLAYING and flow.lives == 3 and flow.score == 0 and flow.current_round == 0, "Retry resets lives, score, and day progress")
	var state_node: Variant = root.get_node("GameState")
	_prepare_round(flow)._finish_round(false, "Pause during result")
	state_node.pause_game()
	await _wait_result()
	_check(flow.state == flow.FlowState.RESULT and flow.lives == 2, "Pause holds the result timer without consuming another life")
	state_node.resume_game()
	await _wait_result()
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

func _win_game(kind: String, game: Variant) -> void:
	match kind:
		"canvas": _win_canvas(game)
		"schedule_builder":
			game._seconds_left = game.WINDOWS[game.difficulty]
			for index: int in game._buttons.size():
				game._register(index)
		"stay_focused":
			for thought: Control in game._thoughts.duplicate():
				game._remove_thought(thought)
			game._seconds_left = 0.005
			game._process(0.01)
		"gates": _win_gates(game)
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
