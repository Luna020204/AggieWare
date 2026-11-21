extends "res://tools/test_collection.gd"
## Fast week/flow checks using the same fail-safe assertion runner.
## godot --headless --path . --script res://tools/smoke_flow.gd

func _run() -> void:
	await _run_suite(false)
