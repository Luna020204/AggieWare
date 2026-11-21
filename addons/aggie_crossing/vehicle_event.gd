@tool
extends Resource
class_name CrossingVehicleEvent
## One vehicle entering a lane at spawn_time, repeated once per lane cycle.

@export_enum("bicycle", "scooter", "custom") var vehicle_type := "bicycle":
	set(value): vehicle_type = value; emit_changed()
@export var custom_type := "":
	set(value): custom_type = value; emit_changed()
@export_range(0, 120, 0.1) var spawn_time := 0.0:
	set(value): spawn_time = value; emit_changed()
## Zero uses the lane default: bicycles at 1x, scooters at 1.5x.
## A nonzero override is the exact speed in px/s (30..600), without a multiplier.
@export_range(0, 600, 5) var speed_override := 0.0:
	set(value): speed_override = value; emit_changed()

func to_data(index: int) -> Dictionary:
	return {"id": "event_%d" % index, "type": custom_type if vehicle_type == "custom" else vehicle_type,
		"time": spawn_time, "speed": speed_override}
