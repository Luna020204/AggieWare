class_name Accessibility
extends RefCounted
## Shared accessibility settings and ownership of an active round's game speed.

const TIMER_ASSIST_LEVELS: Array[float] = [1.0, 1.25, 1.5]
const TIMER_ASSIST_NAMES: Array[String] = ["Off", "+25% time", "+50% time"]

static var _active := false
static var _owner_id := 0
static var _base_speed := 1.0
static var _restore_speed := 1.0


static func timer_assist() -> float:
	var value: Variant = _setting(&"timer_assist", 1.0)
	if not (value is float or value is int) or not is_finite(float(value)):
		return 1.0
	return clampf(float(value), 1.0, 1.5)


static func result_cues_enabled() -> bool:
	return bool(_setting(&"result_cues", true))


static func _setting(setting_name: StringName, fallback: Variant) -> Variant:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node_or_null("GameState") if tree != null else null
	return state.call("get_setting", setting_name, fallback) if state != null else fallback


static func microgame_time_scale(base_speed: float = 1.0) -> float:
	return maxf(base_speed, 0.01) / timer_assist()


## Called by MicrogameBase only after its introduction has finished.
static func begin_microgame(base_speed: float = 1.0, owner: Node = null) -> void:
	var requested_owner := owner.get_instance_id() if owner != null else 0
	if _active and _owner_id != requested_owner:
		end_microgame()
	if not _active:
		_restore_speed = Engine.time_scale
	_active = true
	_owner_id = requested_owner
	_base_speed = maxf(base_speed, 0.01)
	refresh_microgame_speed()


static func refresh_microgame_speed() -> void:
	if _active:
		Engine.time_scale = microgame_time_scale(_base_speed)


## Stale cleanup cannot restore the clock while a newer round owns it.
static func end_microgame(owner: Node = null) -> void:
	if not _active or (owner != null and owner.get_instance_id() != _owner_id):
		return
	Engine.time_scale = _restore_speed
	_active = false
	_owner_id = 0
	_base_speed = 1.0
