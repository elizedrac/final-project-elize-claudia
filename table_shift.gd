extends StaticBody3D
## Ball table that jumps to a slightly different spot while the player is not
## looking at it. Balls resting on it move with it, and their respawn spots
## follow, so the next throw starts from a shifted position.

## Seconds out of view before it shifts.
@export var min_hidden_time: float = 0.5
## How far it may shift from its starting spot, in meters. X is left/right
## (the range leans away from the player so it never moves into them), Z is
## forward/back.
@export var shift_x: Vector2 = Vector2(-0.05, 0.15)
@export var shift_z: Vector2 = Vector2(-0.15, 0.15)
## Each shift moves at least this far from the current spot.
@export var min_shift: float = 0.05
## Table top size, used to find balls resting on it.
@export var top_size: Vector2 = Vector2(0.5, 0.4)

var _home: Vector3
var _hidden_timer: Timer


func _ready() -> void:
	_home = global_position
	_hidden_timer = Timer.new()
	_hidden_timer.one_shot = true
	_hidden_timer.timeout.connect(shift)
	add_child(_hidden_timer)


## Called by GazeDetector when the table leaves the gaze cone.
func on_gaze_exited() -> void:
	if not _hidden_timer.is_inside_tree():
		return  # scene is closing
	_hidden_timer.start(maxf(min_hidden_time, 0.01))


## Called by GazeDetector when the table enters the gaze cone. Never shifts it.
func on_gaze_entered() -> void:
	_hidden_timer.stop()


## Moves the table to a new random spot, carrying the balls on it.
func shift() -> void:
	var target: Vector3 = global_position
	while Vector2(target.x - global_position.x, target.z - global_position.z).length() < min_shift:
		target = _home + Vector3(randf_range(shift_x.x, shift_x.y), 0.0, randf_range(shift_z.x, shift_z.y))
	var delta: Vector3 = target - global_position

	for node: Node in get_tree().get_nodes_in_group(&"balls"):
		var ball := node as XRToolsPickable
		if ball == null:
			continue
		var respawn: Node = ball.get_node_or_null(^"Respawn")
		if respawn != null and respawn.has_method(&"shift_spawn"):
			respawn.call(&"shift_spawn", delta)
		if not ball.is_picked_up() and _is_on_top(ball.global_position):
			var moved: Transform3D = ball.global_transform
			moved.origin += delta
			PhysicsServer3D.body_set_state(ball.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, moved)
			ball.global_transform = moved

	global_position = target


func _is_on_top(point: Vector3) -> bool:
	var local: Vector3 = point - global_position
	return absf(local.x) <= top_size.x * 0.5 + 0.05 \
		and absf(local.z) <= top_size.y * 0.5 + 0.05 \
		and local.y > 0.0 and local.y < 1.0


## Debug: space shifts it even while in view, so you can watch it.
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_SPACE:
		shift()
