class_name ShiftingTarget
extends Node3D
## Target that shifts once when the player aims at it with a ball in hand.
##
## 1. Holding a ball and looking at the target for dwell_time seconds shifts it
##    shift_distance in shift_direction (as seen by the player).
## 2. Looking away before dwell_time cancels the countdown.
## 3. Looking away after the shift, without throwing, resets it immediately.
## 4. Throwing (releasing the ball) after the shift keeps it shifted for
##    hold_after_throw seconds, even if the player looks away, then resets it.

enum Direction { LEFT, RIGHT, UP, DOWN }
enum State { IDLE, SHIFTED, THROWN }

## Which way the target moves, from the player's point of view.
@export var shift_direction: Direction = Direction.LEFT
## How far it moves each time, in meters.
@export var shift_distance: float = 0.25
## Seconds of aiming (ball in hand, looking at it) before it shifts.
@export var dwell_time: float = 1.5
## Seconds it stays shifted after a throw before resetting.
@export var hold_after_throw: float = 3.0
## How far from the edge of the board your view center may be and still count
## as "looking at it", in degrees. Narrower than the gaze cone, so looking
## between two targets doesn't count for both.
@export_range(1.0, 55.0, 1.0) var look_angle: float = 12.0
## Extra degrees allowed once aiming has started, so small head movements, or
## the shift itself, don't count as looking away.
@export_range(0.0, 30.0, 1.0) var keep_look_margin: float = 15.0
## Farthest the player can stand from the target and still trigger a shift,
## in meters. About the distance from the ball table to a target, so standing
## farther back than the balls doesn't count.
@export var max_distance: float = 7.0
## Board radius in meters, used so a close (bigger-looking) target is easier
## to keep looking at.
const BOARD_RADIUS: float = 0.53
## Print state changes to the Output panel.
@export var debug_print: bool = true
## Desktop testing: holding B counts as holding a ball, releasing B as a throw.
@export var debug_ball_key: bool = true

var _home: Vector3
var _state: State = State.IDLE
var _dwell: float = 0.0
var _hold: float = 0.0
var _in_gaze_cone: bool = false
var _was_holding: bool = false
var _camera: XRCamera3D
var _pickups: Array[XRToolsFunctionPickup] = []


func _ready() -> void:
	_home = position
	for node: Node in get_tree().root.find_children("*", "XRToolsFunctionPickup", true, false):
		_pickups.append(node as XRToolsFunctionPickup)
	var cameras: Array[Node] = get_tree().root.find_children("*", "XRCamera3D", true, false)
	if not cameras.is_empty():
		_camera = cameras[0] as XRCamera3D


## Called by GazeDetector when the target enters the gaze cone.
func on_gaze_entered() -> void:
	_in_gaze_cone = true


## Called by GazeDetector when the target leaves the gaze cone.
func on_gaze_exited() -> void:
	_in_gaze_cone = false


func _process(delta: float) -> void:
	var holding: bool = is_holding_ball() \
		or (debug_ball_key and Input.is_physical_key_pressed(KEY_B))
	var threw: bool = _was_holding and not holding
	_was_holding = holding
	var looking: bool = is_looked_at()

	match _state:
		State.IDLE:
			if holding and looking:
				if _dwell == 0.0:
					_log("aiming, shifting in %.1fs" % dwell_time)
				_dwell += delta
				if _dwell >= dwell_time:
					_shift()
			elif _dwell > 0.0:
				_dwell = 0.0  # looked away or no ball: cancel the countdown
				_log("countdown cancelled")
		State.SHIFTED:
			if threw:
				_state = State.THROWN
				_hold = hold_after_throw
				_log("thrown, holding %.1fs" % hold_after_throw)
			elif not looking:
				_reset("looked away before throwing")
		State.THROWN:
			_hold -= delta
			if _hold <= 0.0:
				_reset("hold after throw finished")


## True if either hand is holding a pickable object (the balls).
func is_holding_ball() -> bool:
	for pickup: XRToolsFunctionPickup in _pickups:
		if is_instance_valid(pickup.picked_up_object) and pickup.picked_up_object is XRToolsPickable:
			return true
	return false


## True if the target is in the gaze cone and near the center of the view.
## Measured to the board's edge, against both its home and current position,
## with a wider allowance once aiming has started.
func is_looked_at() -> bool:
	if not _in_gaze_cone or _camera == null:
		return false
	var limit: float = look_angle
	var reach: float = max_distance
	if _state == State.SHIFTED or _dwell > 0.0:
		limit += keep_look_margin
		reach += 1.0  # small allowance so stepping back slightly doesn't reset it
	var home_global: Vector3 = get_parent_node_3d().to_global(_home) if get_parent_node_3d() else _home
	if _camera.global_position.distance_to(home_global) > reach:
		return false
	return _angle_from_view(global_position) <= limit or _angle_from_view(home_global) <= limit


## Degrees between the view center and the nearest edge of a board centered at
## point (0 if the view center is on the board).
func _angle_from_view(point: Vector3) -> float:
	var offset: Vector3 = point - _camera.global_position
	var distance: float = maxf(offset.length(), 0.01)
	var to_center: float = rad_to_deg((-_camera.global_basis.z).angle_to(offset))
	var radius: float = rad_to_deg(atan(BOARD_RADIUS * scale.x / distance))
	return maxf(to_center - radius, 0.0)


## Offset in the target's own axes. The target faces the player, so its +X is
## the player's right and +Y is up.
func shift_offset() -> Vector3:
	var local: Vector3
	match shift_direction:
		Direction.LEFT:
			local = Vector3.LEFT
		Direction.RIGHT:
			local = Vector3.RIGHT
		Direction.UP:
			local = Vector3.UP
		_:
			local = Vector3.DOWN
	return transform.basis.orthonormalized() * local * shift_distance


func _shift() -> void:
	position = _home + shift_offset()
	_state = State.SHIFTED
	_dwell = 0.0
	_log("shifted %s %.2fm" % [Direction.keys()[shift_direction], shift_distance])


func _reset(reason: String) -> void:
	position = _home
	_state = State.IDLE
	_dwell = 0.0
	_log("reset (%s)" % reason)


func get_state_name() -> String:
	return State.keys()[_state]


func _log(message: String) -> void:
	if debug_print:
		print("%s: %s" % [name, message])
