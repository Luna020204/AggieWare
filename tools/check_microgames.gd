extends SceneTree

## SCRUM-58: runs every microgame in MicrogameCatalog once per difficulty and
## reports whether its hooks fire. Also smoke-tests the launcher scene.
##
## Run with:
##   godot --headless --path . --script res://tools/check_microgames.gd
##
## Per microgame and difficulty it checks:
##   contract  root Control, round_completed + time_changed signals,
##             difficulty property, get_round_seconds() > 0
##   tick      time_changed fires while the round runs
##   timeout   with no input, round_completed fires exactly once, by about
##             get_round_seconds() (game time). Stay Focused reports a result
##             from its own rules (missed thoughts), so WIN or FAIL both pass.
##   win/fail  calling the microgame's _finish_round(true/false, ...) emits
##             round_completed with the same value. This checks the wiring of
##             the hook, not that the puzzle is solvable (tools/smoke_flow.gd
##             plays the real interactions).
##
## Prints MICROGAME_CHECK_OK and exits 0 when everything passes.

const TIME_SCALE := 8.0
const TIMEOUT_GRACE := 1.5

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("microgame              diff    contract tick timeout          win  fail")
	for entry: Dictionary in MicrogameCatalog.ENTRIES:
		for difficulty: int in 3:
			await _check_one(entry, difficulty)
	await _check_launcher()
	await _check_flow_prompt()
	Engine.time_scale = 1.0
	if _failures == 0:
		print("MICROGAME_CHECK_OK")
		quit(0)
	else:
		print("MICROGAME_CHECK_FAILED (%d problem(s))" % _failures)
		quit(1)


func _check_one(entry: Dictionary, difficulty: int) -> void:
	var notes: Array[String] = []
	var microgame := MicrogameCatalog.instantiate(entry, difficulty)
	if microgame == null:
		_report(entry, difficulty, "LOAD", "-", "-", "-", "-", ["could not load " + entry["scene"]])
		return
	var problems := MicrogameCatalog.contract_problems(microgame)
	if not problems.is_empty():
		microgame.free()
		_report(entry, difficulty, "FAIL", "-", "-", "-", "-", problems)
		return
	var round_seconds: float = microgame.call("get_round_seconds")
	if round_seconds <= 0.0:
		notes.append("get_round_seconds() <= 0")

	# Timeout run: no input, scaled game time.
	var log := {"results": [], "ticks": 0}
	microgame.round_completed.connect(func(success: bool) -> void: log["results"].append(success))
	microgame.time_changed.connect(func(_l: float, _r: float) -> void: log["ticks"] += 1)
	root.add_child(microgame)
	Engine.time_scale = TIME_SCALE
	var deadline_ms := Time.get_ticks_msec() + int((round_seconds + TIMEOUT_GRACE) / TIME_SCALE * 1000.0) + 500
	while log["results"].is_empty() and Time.get_ticks_msec() < deadline_ms:
		await process_frame
	# Keep running a moment to catch a second (duplicate) emission.
	for i: int in 10:
		await process_frame
	Engine.time_scale = 1.0
	microgame.queue_free()
	await process_frame

	var tick := "ok" if log["ticks"] > 0 else "NONE"
	if log["ticks"] == 0:
		notes.append("time_changed never fired")
	var results: Array = log["results"]
	var timeout := ""
	if results.is_empty():
		timeout = "NONE"
		notes.append("round_completed did not fire within %.1f s" % (round_seconds + TIMEOUT_GRACE))
	elif results.size() > 1:
		timeout = "x%d" % results.size()
		notes.append("round_completed fired %d times" % results.size())
	else:
		timeout = "ok (%s)" % ("WIN" if results[0] else "FAIL")

	var win := await _forced(entry, difficulty, true)
	var fail := await _forced(entry, difficulty, false)
	if win != "ok":
		notes.append("forced win: " + win)
	if fail != "ok":
		notes.append("forced fail: " + fail)
	_report(entry, difficulty, "ok", tick, timeout, win, fail, notes)


func _forced(entry: Dictionary, difficulty: int, success: bool) -> String:
	var microgame := MicrogameCatalog.instantiate(entry, difficulty)
	if not microgame.has_method("_finish_round"):
		microgame.free()
		return "n/a"
	var results: Array = []
	microgame.round_completed.connect(func(value: bool) -> void: results.append(value))
	root.add_child(microgame)
	await process_frame
	microgame.call("_finish_round", success, "check_microgames")
	await process_frame
	microgame.queue_free()
	await process_frame
	if results.size() != 1:
		return "fired %d times" % results.size()
	if results[0] != success:
		return "emitted %s" % results[0]
	return "ok"


func _check_launcher() -> void:
	var launcher: Variant = load("res://scenes/debug/microgame_launcher.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	var problems: Array[String] = []
	for index: int in MicrogameCatalog.ENTRIES.size():
		launcher.launch(index, 2, 4)
		await process_frame
		if not is_instance_valid(launcher._active) or not launcher._running:
			problems.append("did not start %s" % MicrogameCatalog.ENTRIES[index]["id"])
			continue
		if launcher._active.get("difficulty") != 2:
			problems.append("difficulty not applied to %s" % MicrogameCatalog.ENTRIES[index]["id"])
		if not is_equal_approx(Engine.time_scale, 1.5):
			problems.append("speed not applied (%.2f)" % Engine.time_scale)
		if launcher._menu.visible:
			problems.append("menu still visible while playing")
		var entry: Dictionary = MicrogameCatalog.ENTRIES[index]
		if not entry.has("verb") or not entry.has("icon"):
			problems.append("%s has no instruction prompt (verb/icon)" % entry["id"])
		elif not is_instance_valid(launcher._prompt) or launcher._prompt.verb != entry["verb"]:
			problems.append("prompt not shown for %s" % entry["id"])
		elif launcher._active.process_mode != Node.PROCESS_MODE_DISABLED:
			problems.append("%s runs behind its prompt" % entry["id"])
		else:
			launcher._prompt.finish()
			await process_frame
			if launcher._active.process_mode == Node.PROCESS_MODE_DISABLED:
				problems.append("%s did not start after its prompt" % entry["id"])
		launcher._active.call("_finish_round", true, "check")
		await create_timer(launcher.RESULT_DELAY + 0.3, true, false, true).timeout
		if launcher._running or not launcher._menu.visible:
			problems.append("did not return to menu after %s" % MicrogameCatalog.ENTRIES[index]["id"])
		if not String(launcher.last_result).contains("WIN"):
			problems.append("result line missing WIN: %s" % launcher.last_result)
		if not is_equal_approx(Engine.time_scale, 1.0):
			problems.append("time_scale not reset")
	launcher.queue_free()
	await process_frame
	if problems.is_empty():
		print("launcher: ok (launched %d microgames at HARD 1.5x and returned)" % MicrogameCatalog.ENTRIES.size())
	else:
		_failures += problems.size()
		print("launcher: FAIL  " + "; ".join(problems))


## SCRUM-39: the real week flow shows the prompt and holds the microgame.
func _check_flow_prompt() -> void:
	var flow: Variant = load("res://scenes/core/game_flow.tscn").instantiate()
	root.add_child(flow)
	await process_frame
	var problems: Array[String] = []
	for stage: int in 4:
		flow._start_stage(stage)
		await process_frame
		var game: Control = flow._active_scene
		var entry := MicrogameCatalog.find_by_scene(game.scene_file_path)
		if not is_instance_valid(flow._prompt):
			problems.append("day %d: no prompt" % (stage + 1))
			continue
		if flow._prompt.verb != entry.get("verb", ""):
			problems.append("day %d: wrong verb %s" % [stage + 1, flow._prompt.verb])
		if game.process_mode != Node.PROCESS_MODE_DISABLED:
			problems.append("day %d: microgame runs behind the prompt" % (stage + 1))
		flow._prompt.finish()
		await process_frame
		if game.process_mode == Node.PROCESS_MODE_DISABLED:
			problems.append("day %d: microgame did not start after the prompt" % (stage + 1))
	flow.queue_free()
	await process_frame
	if problems.is_empty():
		print("flow prompts: ok (4 days show verb + icon, then start)")
	else:
		_failures += problems.size()
		print("flow prompts: FAIL  " + "; ".join(problems))


func _report(entry: Dictionary, difficulty: int, contract: String, tick: String, timeout: String, win: String, fail: String, notes: Array[String]) -> void:
	print("%-22s %-7s %-8s %-4s %-16s %-4s %-4s" % [entry["id"], MicrogameCatalog.DIFFICULTY_NAMES[difficulty], contract, tick, timeout, win, fail])
	for note: String in notes:
		print("    ! " + note)
	_failures += notes.size()
	if contract != "ok":
		_failures += 1
