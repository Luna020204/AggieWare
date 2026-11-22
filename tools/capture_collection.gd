extends "res://tools/test_collection.gd"
## Render shared and native presentation without changing authored game behavior.
## Run with a graphics renderer, not --headless.

var Catalog: Script

func _run() -> void:
	Catalog = load("res://scripts/core/microgame_catalog.gd")
	create_timer(40.0, true, false, true).timeout.connect(func() -> void: quit(1))
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute("res://artifacts/collection-preview")
	var ignore := FileAccess.open("res://artifacts/.gdignore", FileAccess.WRITE)
	if ignore != null:
		ignore.close()
	var flow: Variant = _mount_flow()
	await _capture("00-title")
	flow._show_stage_select()
	await _capture("00-day-select")
	await _dispose(flow)
	var launcher: Node = load("res://scenes/debug/microgame_launcher.tscn").instantiate()
	root.add_child(launcher)
	await _capture("00-launcher")
	await _dispose(launcher)
	for entry: Dictionary in Catalog.ENTRIES:
		var kind: String = entry.scene.get_file().get_basename()
		var game: Variant = _mount_game(kind, false, 3.2, 1)
		if game == null:
			continue
		if not kind in NATIVE_KINDS:
			game.game_title = entry.title
			game.instruction_text = entry.instruction
			game.result_seconds = 1.4
			game._start_round()
		_tick_game(game, 0.35)
		await _capture("%s-%s" % [entry.id, "initial" if kind in ["variable_scope", "microscope"] else "intro"])
		DRIVER.skip_intro(game)
		var play_frames := 80 if entry.id in ["focus", "awake", "crossing"] else 15
		if entry.id == "crossing": play_frames = 150
		for frame: int in play_frames:
			_tick_game(game, 0.02)
		await _capture("%s-play" % entry.id)
		if entry.id == "crossing":
			root.get_node("GameState").pause_game()
			await _capture("crossing-pause")
			for child: Node in game.get_children():
				if child.get_script() != null and child.get_script().resource_path == PAUSE_SCRIPT:
					child._show_controls(true)
					await _capture("crossing-controls")
					child._show_controls(false)
			root.get_node("GameState").resume_game()
		_win_game(kind, game)
		_check(game._ended, "%s reaches its result for capture" % entry.id)
		_tick_game(game, 0.2)
		await _capture("%s-result" % entry.id)
		if entry.id == "crossing":
			game._start_round()
			game.skip_intro()
			game._finish_round(false, "Traffic collision!")
			await _capture("crossing-failure")
		await _dispose(game)
	# Hosted captures prove that the collection adds no duplicate native result.
	launcher = load("res://scenes/debug/microgame_launcher.tscn").instantiate()
	root.add_child(launcher)
	for id: String in ["swipe", "awake", "scope"]:
		launcher.launch(Catalog.find_index(id), 1, 2)
		var session: Variant = launcher._active
		DRIVER.freeze(session)
		DRIVER.skip_intro(session)
		_tick_game(session, 0.02)
		if id == "scope":
			await _capture("scope-hosted-play")
		else:
			var entry: Dictionary = Catalog.ENTRIES[Catalog.find_index(id)]
			_win_game(entry.scene.get_file().get_basename(), session)
			_tick_game(session, 0.2)
			await _capture("%s-hosted-result" % id)
	await _dispose(launcher)
	print("CAPTURE RESULT: %d failures" % failures)
	quit(1 if failures else 0)

func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://artifacts/collection-preview/%s.png" % label
	var result := root.get_texture().get_image().save_png(path)
	if result != OK:
		failures += 1
		push_error("Could not save capture: " + path)
	else:
		print("CAPTURED: " + path)
