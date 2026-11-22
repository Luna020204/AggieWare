extends SceneTree
## Checks every catalog game at every difficulty through the shared lifecycle.
## godot --headless --path . --script res://tools/check_microgames.gd

const STEP := 0.05
const DRIVER = preload("res://tools/microgame_test_driver.gd")
const NATIVE_DURATIONS := {"scope": [9.0, 7.0, 5.5], "swipe": [9.0, 8.0, 7.0], "awake": [8.0, 7.0, 6.0], "microscope": [10.0, 9.0, 8.0]}
var _failures := 0
var _catalog: Script


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_catalog = load("res://scripts/core/microgame_catalog.gd")
	root.get_node("GameState").set_setting(&"timer_assist", 1.0)
	print("microgame              diff    contract tick timeout          win  fail")
	if _catalog.ENTRIES.size() != 9:
		_failures += 1
		push_error("Catalog must contain all nine integrated microgames.")
	for entry: Dictionary in _catalog.ENTRIES:
		for difficulty: int in 3:
			await _check_one(entry, difficulty)
	await _check_launcher()
	await _check_flow_prompt()
	Accessibility.end_microgame()
	Engine.time_scale = 1.0
	print("MICROGAME_CHECK_OK" if _failures == 0 else "MICROGAME_CHECK_FAILED (%d problems)" % _failures)
	quit(0 if _failures == 0 else 1)


func _check_one(entry: Dictionary, difficulty: int) -> void:
	var notes: Array[String] = []
	var microgame: Variant = _catalog.instantiate(entry, difficulty)
	if microgame == null:
		_report(entry, difficulty, "LOAD", "-", "-", "-", "-", ["could not load " + entry["scene"]])
		return
	var problems: Array[String] = _catalog.contract_problems(microgame)
	if not problems.is_empty():
		microgame.free()
		_report(entry, difficulty, "FAIL", "-", "-", "-", "-", problems)
		return
	var round_seconds: float = microgame.get_round_seconds()
	if round_seconds <= 0.0:
		notes.append("get_round_seconds() must be positive")
	if NATIVE_DURATIONS.has(entry["id"]) and not is_equal_approx(round_seconds, NATIVE_DURATIONS[entry["id"]][difficulty]):
		notes.append("native authored duration changed")
	var log := {"results": [], "ticks": 0}
	microgame.round_completed.connect(func(success: bool) -> void: log["results"].append(success))
	microgame.time_changed.connect(func(_left: float, _total: float) -> void: log["ticks"] += 1)
	microgame.prompt_seconds = 0.0
	root.add_child(microgame)
	DRIVER.freeze(microgame)
	# Deterministic active-time updates exercise timeout rules without a wall-clock
	# deadline or host clock overrides that can interfere with accessibility.
	for frame: int in int(ceil(round_seconds / STEP)) + 2:
		if microgame.is_round_finished():
			break
		DRIVER.tick(microgame, STEP)
	for frame: int in 10:
		DRIVER.tick(microgame, STEP)
	var tick := "ok" if log["ticks"] > 1 else "NONE"
	if tick != "ok":
		notes.append("time_changed did not advance")
	var results: Array = log["results"]
	var timeout := "NONE"
	if results.size() == 1:
		timeout = "ok (%s)" % ("WIN" if results[0] else "FAIL")
	else:
		notes.append("expected one result, received %d" % results.size())
	root.remove_child(microgame)
	microgame.queue_free()
	await process_frame
	var win := await _forced(entry, difficulty, true)
	var fail := await _forced(entry, difficulty, false)
	if win != "ok":
		notes.append("forced win: " + win)
	if fail != "ok":
		notes.append("forced fail: " + fail)
	_report(entry, difficulty, "ok", tick, timeout, win, fail, notes)


func _forced(entry: Dictionary, difficulty: int, success: bool) -> String:
	var microgame: Variant = _catalog.instantiate(entry, difficulty)
	microgame.prompt_seconds = 0.0
	var results: Array[bool] = []
	microgame.round_completed.connect(func(value: bool) -> void: results.append(value))
	root.add_child(microgame)
	DRIVER.freeze(microgame)
	DRIVER.finish(microgame, success, "CHECK RESULT")
	DRIVER.finish(microgame, not success, "DUPLICATE RESULT")
	root.remove_child(microgame)
	microgame.queue_free()
	await process_frame
	if results.size() != 1:
		return "fired %d times" % results.size()
	return "ok" if results[0] == success else "emitted wrong outcome"


func _check_launcher() -> void:
	var launcher: Variant = load("res://scenes/debug/microgame_launcher.tscn").instantiate()
	root.add_child(launcher)
	var problems: Array[String] = []
	for index: int in _catalog.ENTRIES.size():
		launcher.launch(index, 2, 4)
		var game: Variant = launcher._active
		var entry: Dictionary = _catalog.ENTRIES[index]
		if game == null or not launcher._running:
			problems.append("did not start %s" % entry["id"])
			continue
		DRIVER.freeze(game)
		if game.difficulty != 2 or launcher._menu.visible:
			problems.append("difficulty/menu configuration failed for " + entry["id"])
		if game.get_intro_seconds() > 0.0:
			if not is_equal_approx(Engine.time_scale, 1.0) or game.is_playing():
				problems.append("introduction did not precede assisted play for " + entry["id"])
		elif not game.is_playing() or not is_equal_approx(Engine.time_scale, 1.5):
			problems.append("native game without introduction did not start immediately: " + entry["id"])
		if game.game_title != str(entry["title"]).to_upper() or game.instruction_text != entry["instruction"]:
			problems.append("introduction metadata missing for " + entry["id"])
		game.skip_intro()
		if not game.can_interact() or not is_equal_approx(Engine.time_scale, 1.5):
			problems.append("game did not start at selected speed for " + entry["id"])
		DRIVER.finish(game, true, "CHECK RESULT")
		DRIVER.tick(game, launcher.RESULT_DELAY + 0.01)
		if launcher._running or not launcher._menu.visible or not String(launcher.last_result).contains("WIN"):
			problems.append("did not return with result for " + entry["id"])
		if not is_equal_approx(Engine.time_scale, 1.0):
			problems.append("clock was not restored for " + entry["id"])
		await process_frame
	launcher.queue_free()
	await process_frame
	_report_group("launcher", problems)


func _check_flow_prompt() -> void:
	var flow: Variant = load("res://scenes/core/game_flow.tscn").instantiate()
	root.add_child(flow)
	var problems: Array[String] = []
	var rounds := 0
	for stage: int in flow.week_plan.stages.size():
		for round_index: int in flow.week_plan.stages[stage].games.size():
			rounds += 1
			flow._start_round(stage, round_index)
			var game: Variant = flow._active_scene
			DRIVER.freeze(game)
			var initial_time: float = game.get_seconds_left()
			DRIVER.tick(game, 0.1)
			if game.is_playing() or not is_equal_approx(initial_time, game.get_seconds_left()):
				problems.append("day %d round %d: clock runs during introduction" % [stage + 1, round_index + 1])
			game.skip_intro()
			if not game.can_interact():
				problems.append("day %d round %d: intro did not release play" % [stage + 1, round_index + 1])
	if rounds != 6:
		problems.append("the default week no longer has its six rounds")
	flow.queue_free()
	await process_frame
	_report_group("week introductions", problems)


func _report_group(label: String, problems: Array[String]) -> void:
	_failures += problems.size()
	print(label + ": ok" if problems.is_empty() else label + ": FAIL " + "; ".join(problems))


func _report(entry: Dictionary, difficulty: int, contract: String, tick: String, timeout: String, win: String, fail: String, notes: Array[String]) -> void:
	print("%-22s %-7s %-8s %-4s %-16s %-4s %-4s" % [entry["id"], _catalog.DIFFICULTY_NAMES[difficulty], contract, tick, timeout, win, fail])
	for note: String in notes:
		print("    ! " + note)
	_failures += notes.size()
	if contract != "ok":
		_failures += 1
