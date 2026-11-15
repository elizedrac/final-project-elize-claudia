class_name ChangeableObject
extends MeshInstance3D
## A box that changes color and/or size instantly when on_look_away() is called.

@export var change_color: bool = true
@export var change_size: bool = true
@export var min_scale: float = 0.5
@export var max_scale: float = 1.5
## Seconds the object must be out of view before it changes (used by gaze hookup).
@export var min_hidden_time: float = 0.5

const MIN_HUE_DISTANCE: float = 0.15

var _material: StandardMaterial3D
var _base_scale: Vector3
var _hidden_timer: Timer


func _ready() -> void:
	add_to_group(&"changeable")
	_base_scale = scale
	# Own material per instance, so instances never share one.
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color.from_hsv(randf(), 0.8, 0.9)
	material_override = _material

	# Fires once the object has been out of view for min_hidden_time.
	_hidden_timer = Timer.new()
	_hidden_timer.one_shot = true
	_hidden_timer.timeout.connect(on_look_away)
	add_child(_hidden_timer)


## Called by GazeDetector when this object leaves the gaze cone.
func on_gaze_exited() -> void:
	_hidden_timer.start(maxf(min_hidden_time, 0.01))


## Called by GazeDetector when this object enters the gaze cone. Never changes
## anything: it only cancels a change that has not happened yet.
func on_gaze_entered() -> void:
	_hidden_timer.stop()


func on_look_away() -> void:
	if change_color:
		_material.albedo_color = _pick_new_color(_material.albedo_color)
	if change_size:
		_apply_scale(randf_range(min_scale, max_scale))


## Random color whose hue is at least MIN_HUE_DISTANCE from the current one.
func _pick_new_color(current: Color) -> Color:
	var hue: float = randf()
	while _hue_distance(hue, current.h) < MIN_HUE_DISTANCE:
		hue = randf()
	return Color.from_hsv(hue, 0.8, 0.9)


## Hue is circular, so 0.95 and 0.05 are only 0.1 apart.
func _hue_distance(a: float, b: float) -> float:
	var d: float = absf(a - b)
	return minf(d, 1.0 - d)


## Scales uniformly while keeping the bottom of the mesh at the same height.
func _apply_scale(factor: float) -> void:
	var bottom_offset: float = get_aabb().position.y
	var base_y: float = position.y + bottom_offset * scale.y
	scale = _base_scale * factor
	position.y = base_y - bottom_offset * scale.y


## Debug: space triggers the change on every object, for testing without a headset.
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_SPACE:
		on_look_away()
