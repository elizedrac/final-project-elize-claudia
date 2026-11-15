class_name GazeDetector
extends Node
## Attaches a cone-shaped Area3D to the XR camera at runtime, so the player rig
## scene stays untouched. Reports which gaze targets enter and leave the cone.

signal gaze_entered(target: Node3D)
signal gaze_exited(target: Node3D)

## Physics layer 10. Gaze targets put their Area3D on this layer.
const GAZE_LAYER: int = 1 << 9

## Half-angle of the cone in degrees. 55 covers roughly the whole headset view,
## so anything outside it is truly off-screen.
@export_range(5.0, 80.0, 1.0) var half_angle_degrees: float = 55.0
## Length of the cone in meters.
@export var length: float = 10.0
## Print enter/exit events to the console.
@export var debug_print: bool = false

var area: Area3D


func _ready() -> void:
	var camera: XRCamera3D = _find_camera()
	if camera == null:
		push_warning("GazeDetector: no XRCamera3D found, gaze detection is off.")
		return

	area = Area3D.new()
	area.name = "GazeCone"
	area.collision_layer = 0
	area.collision_mask = GAZE_LAYER
	area.monitorable = false

	var shape_node := CollisionShape3D.new()
	shape_node.shape = _build_cone()
	area.add_child(shape_node)

	area.area_entered.connect(_on_area_entered)
	area.area_exited.connect(_on_area_exited)
	camera.add_child.call_deferred(area)


func _find_camera() -> XRCamera3D:
	var found: Array[Node] = get_tree().root.find_children("*", "XRCamera3D", true, false)
	if found.is_empty():
		return null
	return found[0] as XRCamera3D


## Cone with its tip at the camera, opening along -Z (the camera's forward).
func _build_cone() -> ConvexPolygonShape3D:
	var radius: float = length * tan(deg_to_rad(half_angle_degrees))
	var points := PackedVector3Array([Vector3.ZERO])
	var segments: int = 16
	for i: int in segments:
		var angle: float = TAU * float(i) / float(segments)
		points.append(Vector3(cos(angle) * radius, sin(angle) * radius, -length))
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	return shape


func _on_area_entered(other: Area3D) -> void:
	var target := other.get_parent() as Node3D
	if target == null:
		return
	if debug_print:
		print("gaze entered: ", target.name)
	gaze_entered.emit(target)


func _on_area_exited(other: Area3D) -> void:
	var target := other.get_parent() as Node3D
	if target == null:
		return
	if debug_print:
		print("gaze exited: ", target.name)
	gaze_exited.emit(target)
