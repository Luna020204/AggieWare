@tool
extends Node2D
class_name CrossingRoadLane
## Position.y selects the road row. Lanes span the full 840-pixel map width.

@export_enum("Right:1", "Left:-1") var direction: int = 1
## Baseline speed in px/s. With no override, bicycles use 1x and scooters use 1.5x.
@export_range(30, 600, 5) var default_speed := 145.0
@export_range(0.5, 120, 0.1) var cycle_seconds := 5.0
@export var events: Array[CrossingVehicleEvent] = []

func _ready() -> void:
	set_process(Engine.is_editor_hint())

func _process(_delta: float) -> void:
	position = Vector2(0, snappedf(position.y, 40))

func to_data() -> Dictionary:
	var schedule: Array = []
	for i in events.size():
		if events[i] != null: schedule.append(events[i].to_data(i))
	return {"id": str(name), "row": roundi(position.y / 40), "direction": direction,
		"speed": default_speed, "cycle": cycle_seconds, "events": schedule}

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	for event in events:
		if event == null:
			warnings.append("Remove empty events or create CrossingVehicleEvent resources.")
		elif event.spawn_time >= cycle_seconds:
			warnings.append("Every spawn time must be less than Cycle Seconds.")
	return warnings
