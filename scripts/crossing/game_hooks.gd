extends Node
## Public extension surface. The runtime owns variables; the editor stores initial values.

signal run_started(level: Dictionary)
signal run_finished(elapsed: float, variables: Dictionary)
signal item_collected(item: Dictionary)
signal vehicle_hit(vehicle: Dictionary)
signal variable_changed(key: String, value: Variant)
signal custom_event(event_name: String, payload: Dictionary)

var variables: Dictionary = {}
var item_handlers: Dictionary = {}
var vehicle_types: Dictionary = {
	"bicycle": {"half_size": Vector2(23, 10), "color": Color("e4bd65"), "speed_multiplier": 1.0},
	"scooter": {"half_size": Vector2(21, 9), "color": Color("79c9ca"), "speed_multiplier": 1.5}
}

func _init() -> void:
	register_item_handler("token", func(item: Dictionary) -> void:
		add_variable("tokens", float(item.properties.get("value", 1))))
	register_item_handler("shield", func(item: Dictionary) -> void:
		add_variable("shields", float(item.properties.get("charges", 1))))

func register_item_handler(type_id: String, handler: Callable) -> void:
	item_handlers[type_id] = handler

func register_vehicle_type(type_id: String, half_size: Vector2, color: Color, speed_multiplier := 1.0) -> void:
	vehicle_types[type_id] = {"half_size": half_size, "color": color, "speed_multiplier": speed_multiplier}

func begin(level: Dictionary) -> void:
	variables = level.variables.duplicate(true)
	run_started.emit(level.duplicate(true))

func set_variable(key: String, value: Variant) -> void:
	variables[key] = value
	variable_changed.emit(key, value)

func add_variable(key: String, amount: float) -> void:
	var current: Variant = variables.get(key, 0)
	if current is int or current is float:
		set_variable(key, float(current) + amount)

func collect(item: Dictionary) -> void:
	var snapshot := item.duplicate(true)
	if item_handlers.has(str(item.type)):
		item_handlers[str(item.type)].call(snapshot)
	item_collected.emit(snapshot)
