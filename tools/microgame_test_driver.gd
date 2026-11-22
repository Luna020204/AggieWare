extends RefCounted
## Deterministic test stepping across the shared and preserved native contracts.

static func body(game: Variant) -> Variant:
	return game.native_game if game.has_method("tick_native") else game

static func message_overlay(game: Variant) -> Variant:
	var native: Variant = body(game)
	for property: Dictionary in native.get_property_list():
		if property.name == "_overlay":
			var overlay: Variant = native.get("_overlay")
			if is_instance_valid(overlay) and overlay.has_method("pop") and overlay.has_method("clear_pop"):
				return overlay
	return null

static func freeze(game: Variant) -> void:
	game.set_process(false)
	body(game).set_process(false)
	var overlay: Variant = message_overlay(game)
	if overlay != null:
		overlay.set_process(false)

static func skip_intro(game: Variant) -> void:
	if game.has_method("skip_intro"):
		game.skip_intro()

static func tick(game: Variant, delta: float) -> void:
	if game.has_method("tick_native"):
		game.tick_native(delta)
		if is_instance_valid(game) and game.is_inside_tree():
			game.tick_native(0.0)
	elif not game.get_tree().paused:
		game._process(delta)
		var overlay: Variant = message_overlay(game)
		if overlay != null:
			overlay._process(delta)

static func finish(game: Variant, success: bool, message := "TEST RESULT") -> void:
	body(game)._finish_round(success, message)
