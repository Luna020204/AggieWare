extends "res://tools/test_collection.gd"
## SCRUM-75 mechanics and actual shared-input routes at all difficulties.
func _run() -> void:
	create_timer(20.0, true).timeout.connect(func(): quit(1))
	var actions: Variant = root.get_node("InputActions")
	var state: Variant = root.get_node("GameState")
	for difficulty in 3:
		var camera_game: Variant = _mount_game("position_lock", true, 0.3, difficulty)
		var before: Vector2 = camera_game.camera
		Input.action_press(actions.ACTION_RIGHT)
		camera_game._process(0.1)
		_check(camera_game.camera == before and camera_game.get_seconds_left() == camera_game.get_round_seconds(), "Camera intro blocks movement and clock")
		camera_game.skip_intro()
		camera_game._process(0.1)
		Input.action_release(actions.ACTION_RIGHT)
		_check(camera_game.camera.x > before.x, "Shared right action moves frame")
		camera_game.camera = camera_game.vessel
		camera_game._process(0.1)
		_check(camera_game.lock_progress > 0.0, "Containment builds lock")
		camera_game.camera = Vector2(100, 190)
		camera_game._process(0.01)
		_check(camera_game.lock_progress == 0.0, "Losing target resets continuous lock")
		var elapsed: float = camera_game._elapsed
		state.pause_game()
		camera_game._process(1.0)
		_check(camera_game._elapsed == elapsed, "Pause freezes target")
		state.resume_game()
		# Chase with real mapped actions; never teleport the frame to win.
		var results: Array[bool] = []
		camera_game.round_completed.connect(func(success): results.append(success))
		for frame in 900:
			if camera_game._ended:
				break
			var offset: Vector2 = camera_game.vessel - camera_game.camera
			for pair in [[actions.ACTION_RIGHT, offset.x > 8], [actions.ACTION_LEFT, offset.x < -8], [actions.ACTION_DOWN, offset.y > 8], [actions.ACTION_UP, offset.y < -8]]:
				if pair[1]: Input.action_press(pair[0])
				else: Input.action_release(pair[0])
			camera_game._process(0.01)
		for action in [actions.ACTION_RIGHT, actions.ACTION_LEFT, actions.ACTION_UP, actions.ACTION_DOWN]:
			Input.action_release(action)
		_check(results == [true], "Reachable moving-target win at difficulty %d" % difficulty)
		await _dispose(camera_game)
		var gun: Variant = _mount_game("shield_break", true, 0.3, difficulty)
		gun.gun_x = gun.target_x
		gun.fire()
		_check(gun.hits == 0, "Intro blocks shooting")
		gun.skip_intro()
		gun.gun_x = 80.0
		gun.fire()
		_check(gun.hits == 0, "Off-target shots do not damage shield")
		Input.action_press(actions.ACTION_RIGHT)
		gun._process(1.0)
		Input.action_release(actions.ACTION_RIGHT)
		_check(gun.gun_x > 80.0, "Shared movement steers gun")
		gun.gun_x = gun.target_x
		state.pause_game()
		gun.fire()
		_check(gun.hits == 0, "Paused shooting is ignored")
		state.resume_game()
		# Remapped physical key travels through InputMap and the gameplay update.
		var original: Array[InputEvent] = InputMap.action_get_events(actions.ACTION_MASH)
		var key := InputEventKey.new()
		key.physical_keycode = KEY_J
		key.keycode = KEY_J
		var binding: Array[InputEvent] = [key]
		actions.replace_action_events(actions.ACTION_MASH, binding)
		for shot in gun.REQUIRED_HITS[difficulty]:
			key.pressed = true
			Input.parse_input_event(key)
			Input.flush_buffered_events()
			gun._process(0.02)
			key = key.duplicate()
			key.pressed = false
			Input.parse_input_event(key)
			Input.flush_buffered_events()
			await process_frame
		_check(gun._ended and gun.hits == gun.REQUIRED_HITS[difficulty], "Remapped mash breaks shield at difficulty %d" % difficulty)
		gun.fire()
		_check(gun.hits == gun.REQUIRED_HITS[difficulty], "Result blocks extra hits")
		actions.replace_action_events(actions.ACTION_MASH, original)
		gun.prompt_seconds = 0.0
		gun._start_round()
		_check(gun.hits == 0 and gun.gun_x == 300.0, "Retry resets gun and shield")
		gun.gun_x = gun.target_x
		state.set_setting(&"mash_hold", true)
		Input.action_press(actions.ACTION_MASH)
		await process_frame
		for tick in gun.REQUIRED_HITS[difficulty]:
			actions._process(0.13)
			gun._process(0.13)
		Input.action_release(actions.ACTION_MASH)
		state.set_setting(&"mash_hold", false)
		_check(gun._ended and gun.hits == gun.REQUIRED_HITS[difficulty], "Accessible hold-to-mash wins")
		await _dispose(gun)
	print("FESTIVAL_CHECKS %d; failures %d" % [checks, failures])
	if failures == 0:
		print("FESTIVAL_TESTS_OK")
	quit(1 if failures else 0)
