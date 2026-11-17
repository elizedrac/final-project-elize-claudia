class_name MovingTarget
extends Node3D
## Target that slowly slides sideways and grows or shrinks while the player is
## not looking at it. It freezes the moment it comes back into view, and
## flashes when a ball hits it.

signal hit(ball: Node3D)

## Seconds out of view before it starts changing.
@export var min_hidden_time: float = 0.5
## Max sideways distance from its starting spot, in meters.
@export var max_offset: float = 0.75
## Size range relative to its starting size.
@export var min_size: float = 0.85
@export var max_size: float = 1.2
## Slide speed in meters per second.
@export var move_speed: float = 0.15
## Grow/shrink speed, as a fraction of its starting size per second.
@export var grow_speed: float = 0.05
## How long the hit flash lasts, in seconds.
@export var flash_time: float = 0.15

var _home: Vector3
var _base_scale: Vector3
var _offset: float = 0.0
var _size: float = 1.0
var _goal_offset: float = 0.0
var _goal_size: float = 1.0
var _changing: bool = false
var _hidden_timer: Timer
var _flash_timer: Timer
var _flash_material: StandardMaterial3D
var _meshes: Array[MeshInstance3D] = []

@onready var _hit_zone: Area3D = $HitZone


func _ready() -> void:
	_home = position
	_base_scale = scale

	_hidden_timer = Timer.new()
	_hidden_timer.one_shot = true
	_hidden_timer.timeout.connect(_start_change)
	add_child(_hidden_timer)

	_flash_material = StandardMaterial3D.new()
	_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_material.albedo_color = Color(1, 1, 1, 0.7)
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		_meshes.append(node as MeshInstance3D)

	_flash_timer = Timer.new()
	_flash_timer.one_shot = true
	_flash_timer.timeout.connect(_set_flash.bind(false))
	add_child(_flash_timer)

	_hit_zone.body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if not _changing:
		return
	_offset = move_toward(_offset, _goal_offset, move_speed * delta)
	_size = move_toward(_size, _goal_size, grow_speed * delta)
	# Slide along the target's own left/right axis. The origin is at its feet,
	# so scaling keeps it standing on the floor.
	position = _home + transform.basis.x.normalized() * _offset
	scale = _base_scale * _size
	if is_equal_approx(_offset, _goal_offset) and is_equal_approx(_size, _goal_size):
		_changing = false


## Called by GazeDetector when the target leaves the gaze cone.
func on_gaze_exited() -> void:
	if not _hidden_timer.is_inside_tree():
		return  # scene is closing
	_hidden_timer.start(maxf(min_hidden_time, 0.01))


## Called by GazeDetector when the target enters the gaze cone. Freezes it.
func on_gaze_entered() -> void:
	_hidden_timer.stop()
	_changing = false


## Picks a new spot and size that differ noticeably from the current ones.
func _start_change() -> void:
	_goal_offset = randf_range(-max_offset, max_offset)
	while absf(_goal_offset - _offset) < max_offset * 0.4:
		_goal_offset = randf_range(-max_offset, max_offset)
	_goal_size = randf_range(min_size, max_size)
	while absf(_goal_size - _size) < (max_size - min_size) * 0.3:
		_goal_size = randf_range(min_size, max_size)
	_changing = true


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group(&"balls"):
		return
	_set_flash(true)
	_flash_timer.start(flash_time)
	hit.emit(body)


func _set_flash(on: bool) -> void:
	for mesh: MeshInstance3D in _meshes:
		mesh.material_overlay = _flash_material if on else null


## Debug: space starts a change even while in view, so you can watch it.
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_SPACE:
		_start_change()
