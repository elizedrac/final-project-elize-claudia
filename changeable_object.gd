class_name ChangeableObject
extends MeshInstance3D
## A box that changes color and/or size instantly when on_look_away() is called.

@export var change_color: bool = true
@export var change_size: bool = true
@export var min_scale: float = 0.5
@export var max_scale: float = 1.5
## Seconds the object must be out of view before it changes (used by gaze hookup).
@export var min_hidden_time: float = 0.5

var _material: StandardMaterial3D


func _ready() -> void:
	add_to_group(&"changeable")
	# Own material per instance, so instances never share one.
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color.from_hsv(randf(), 0.8, 0.9)
	material_override = _material


func on_look_away() -> void:
	if change_color:
		_material.albedo_color = Color.from_hsv(randf(), 0.8, 0.9)
	if change_size:
		scale = Vector3.ONE * randf_range(min_scale, max_scale)


## Debug: space triggers the change on every object, for testing without a headset.
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_SPACE:
		on_look_away()
