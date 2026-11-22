extends RefCounted

## Mouse dragging and drop geometry in each Control's coordinate system.
signal dropped(target: Control)

var card: Control
var _grab_offset := Vector2.ZERO


func begin(target: Control, local_grab: Vector2) -> void:
	cancel()
	card = target
	_grab_offset = card.get_transform() * local_grab - card.position
	card.z_index = 20


func handle_input(event: InputEvent) -> bool:
	if not is_instance_valid(card):
		card = null
		return false
	if event is InputEventMouseMotion:
		# A release during pause or outside the window may never reach this node.
		# Keep the card at its last position and clear the stale grab on resume.
		if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			cancel(false)
			return false
		var parent := card.get_parent() as CanvasItem
		var local_mouse: Vector2 = parent.get_global_transform_with_canvas().affine_inverse() * event.position
		card.position = local_mouse - _grab_offset
		return true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		finish()
		return true
	return false


func finish() -> void:
	if not is_instance_valid(card):
		card = null
		return
	var target := card
	card = null
	target.z_index = 1
	dropped.emit(target)


func cancel(return_to_origin: bool = true) -> void:
	if is_instance_valid(card):
		if return_to_origin and card.has_meta("origin"):
			card.position = card.get_meta("origin")
		card.z_index = 1
	card = null


static func contains_center(target: Control, zone: Control) -> bool:
	var center := target.get_global_transform() * (target.size * 0.5)
	var local_center := zone.get_global_transform().affine_inverse() * center
	return Rect2(Vector2.ZERO, zone.size).has_point(local_center)


static func center_on(target: Control, zone: Control) -> void:
	var center := zone.get_global_transform() * (zone.size * 0.5)
	var parent := target.get_parent() as CanvasItem
	var local_center := parent.get_global_transform().affine_inverse() * center
	var center_offset := target.get_transform() * (target.size * 0.5) - target.position
	target.position = local_center - center_offset
