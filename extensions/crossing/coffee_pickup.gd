extends Node
## Optional example: add a Node with this script as a child of CampusLevel.
## Place an item with Item Type = coffee and Properties = {"energy": 25}.

func _ready() -> void:
	get_parent().runtime_ready.connect(_on_runtime_ready)

func _on_runtime_ready(controller: Node) -> void:
	controller.hooks.register_item_handler("coffee", func(item: Dictionary) -> void:
		var amount: Variant = item.properties.get("energy", 25)
		if amount is int or amount is float:
			controller.hooks.add_variable("energy", float(amount))
			controller.hooks.custom_event.emit("coffee_collected", item))
