class_name ChangeableObject
extends MeshInstance3D
## An object that instantly changes shape, color and/or size when
## on_look_away() is called. It starts as a random shape from SHAPE_PATHS.

@export var change_color: bool = true
@export var change_size: bool = true
@export var change_shape: bool = true
@export var min_scale: float = 0.5
@export var max_scale: float = 1.5
## Seconds the object must be out of view before it changes (used by gaze hookup).
@export var min_hidden_time: float = 0.5

const MIN_HUE_DISTANCE: float = 0.15
## Shapes made in Blender (perception_shapes.blend), each fits a 0.7 m cube.
const SHAPE_PATHS: Array[String] = [
	"res://shapes/twisted_tower.glb",
	"res://shapes/saturn.glb",
	"res://shapes/mushroom.glb",
	"res://shapes/spinning_top.glb",
	"res://shapes/ziggurat.glb",
	"res://shapes/geodesic_cage.glb",
]

## Meshes loaded once and shared by every object.
static var _shape_meshes: Array[Mesh] = []

var _material: StandardMaterial3D
var _base_scale: Vector3
var _hidden_timer: Timer


func _ready() -> void:
	add_to_group(&"changeable")
	_base_scale = scale
	_load_shapes()
	# Replace the placeholder box with a random shape, keeping its bottom in place.
	var bottom: float = _bottom_y()
	mesh = _shape_meshes.pick_random()
	_set_bottom_y(bottom)
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
	if not _hidden_timer.is_inside_tree():
		return  # scene is closing
	_hidden_timer.start(maxf(min_hidden_time, 0.01))


## Called by GazeDetector when this object enters the gaze cone. Never changes
## anything: it only cancels a change that has not happened yet.
func on_gaze_entered() -> void:
	_hidden_timer.stop()


func on_look_away() -> void:
	var bottom: float = _bottom_y()
	if change_shape:
		mesh = _pick_new_shape(mesh)
	if change_color:
		_material.albedo_color = _pick_new_color(_material.albedo_color)
	if change_size:
		scale = _base_scale * randf_range(min_scale, max_scale)
	_set_bottom_y(bottom)


## Random shape that is never the current one.
func _pick_new_shape(current: Mesh) -> Mesh:
	var options: Array[Mesh] = _shape_meshes.filter(func(m: Mesh) -> bool: return m != current)
	return options.pick_random() if not options.is_empty() else current


static func _load_shapes() -> void:
	if not _shape_meshes.is_empty():
		return
	for path: String in SHAPE_PATHS:
		var scene: Node = (load(path) as PackedScene).instantiate()
		var found: Array[Node] = scene.find_children("*", "MeshInstance3D", true, false)
		if not found.is_empty():
			_shape_meshes.append((found[0] as MeshInstance3D).mesh)
		scene.free()


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


## World height of the bottom of the current mesh.
func _bottom_y() -> float:
	return position.y + get_aabb().position.y * scale.y


## Moves the object up or down so the bottom of its mesh sits at this height,
## so shape and size changes never sink into or float off its surface.
func _set_bottom_y(bottom: float) -> void:
	position.y = bottom - get_aabb().position.y * scale.y


## Debug: space triggers the change on every object, for testing without a headset.
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_SPACE:
		on_look_away()
