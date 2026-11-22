@tool
extends Node2D
class_name CrossingLevelPiece
## Drag in the 2D viewport; positions snap to 40-pixel cells.

@export_enum("start", "goal", "planter", "bench", "barrier", "item") var kind := "planter"
@export var item_type := "token"
@export var properties: Dictionary = {"value": 1}

func _ready() -> void:
	set_process(Engine.is_editor_hint())

func _process(_delta: float) -> void:
	position = position.snapped(Vector2(40, 40))

func cell() -> Array:
	return [roundi(position.x / 40), roundi(position.y / 40)]

func to_data() -> Dictionary:
	if kind == "item":
		return {"id": str(name), "cell": cell(), "type": item_type, "properties": properties.duplicate(true)}
	return {"id": str(name), "cell": cell(), "kind": kind}
