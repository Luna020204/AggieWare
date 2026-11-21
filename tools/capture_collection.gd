extends SceneTree
## Captures the rendered collection layout for visual regression review.
## Run with a graphics renderer, not --headless.

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute("res://artifacts/collection-preview")
	var flow = load("res://scenes/core/game_flow.tscn").instantiate()
	root.add_child(flow)
	await _capture("01-title")
	flow._show_stage_select()
	await _capture("02-day-select")
	var rounds := [[0, 0, "03-canvas"], [0, 1, "04-crossing"], [1, 0, "05-schedule"], [2, 0, "06-focus"], [3, 0, "07-gates"]]
	for round_info in rounds:
		flow._start_round(round_info[0], round_info[1])
		var game = flow._active_scene
		game.set_process(false)
		game._process(1.0)
		game._process(0.9)
		if round_info[2] == "06-focus":
			game._process(0.7)
		await _capture(round_info[2])
		if round_info[2] == "04-crossing":
			root.get_node("GameState").pause_game()
			await _capture("08-pause")
			root.get_node("GameState").resume_game()
	flow.queue_free()
	await process_frame
	var authored = load("res://scenes/crossing/campus_intro.tscn").instantiate()
	root.add_child(authored)
	var controller = authored.get_node("StandaloneGameLayer/GameController")
	controller.set_process(false)
	controller._process(1.0)
	controller._process(0.9)
	await _capture("09-authored-level-f6")
	authored.queue_free()
	await process_frame
	print("CAPTURE RESULT: %d failures" % failures)
	quit(1 if failures else 0)

func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://artifacts/collection-preview/%s.png" % name
	var result := root.get_texture().get_image().save_png(path)
	if result != OK:
		failures += 1
		push_error("Could not save capture: " + path)
	else:
		print("CAPTURED: " + path)
