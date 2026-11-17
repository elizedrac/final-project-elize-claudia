extends Node
## Child of a pickable ball. Puts the ball back where it started if it falls
## off the world, or 10 seconds after it was thrown.

## Respawn if the ball drops below this height.
@export var respawn_below_y: float = -3.0
## Seconds after being thrown before it returns to its spot.
@export var respawn_after: float = 10.0

var _ball: XRToolsPickable
var _spawn: Transform3D
var _since_release: float = -1.0


func _ready() -> void:
	_ball = get_parent() as XRToolsPickable
	_ball.add_to_group(&"balls")
	_spawn = _ball.global_transform
	_ball.picked_up.connect(_on_picked_up)
	_ball.released.connect(_on_released)


func _physics_process(delta: float) -> void:
	if _ball.is_picked_up():
		return
	if _ball.global_position.y < respawn_below_y:
		_respawn()
		return
	if _since_release >= 0.0:
		_since_release += delta
		if _since_release >= respawn_after:
			_respawn()


## Called by the ball table when it shifts, so the ball returns to its new spot.
func shift_spawn(delta: Vector3) -> void:
	_spawn.origin += delta


func _respawn() -> void:
	_since_release = -1.0
	_ball.linear_velocity = Vector3.ZERO
	_ball.angular_velocity = Vector3.ZERO
	PhysicsServer3D.body_set_state(_ball.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, _spawn)
	_ball.global_transform = _spawn


func _on_picked_up(_pickable: Variant) -> void:
	_since_release = -1.0


func _on_released(_pickable: Variant, _by: Variant) -> void:
	_since_release = 0.0
