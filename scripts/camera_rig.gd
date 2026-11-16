extends Node3D
## Follows the player with a low-angle isometric perspective camera and projects clicks to ground.
class_name CameraRig

@export var camera_offset := Vector3(16.0, 18.0, 16.0)
@export_range(20.0, 75.0, 1.0) var perspective_fov := 45.0

@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	if not is_instance_valid(camera):
		return
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = perspective_fov
	camera.top_level = true

func follow(target_global_pos: Vector3) -> void:
	if not is_instance_valid(camera):
		return
	camera.global_position = target_global_pos + camera_offset
	camera.look_at(target_global_pos, Vector3.UP)

func project_click_to_ground(screen_pos: Vector2) -> Variant:
	if not is_instance_valid(camera):
		return null
	var origin := camera.project_ray_origin(screen_pos)
	var direction := camera.project_ray_normal(screen_pos)
	if is_zero_approx(direction.y):
		return null
	var distance_to_ground := -origin.y / direction.y
	if distance_to_ground < 0.0:
		return null
	var ground_position := origin + direction * distance_to_ground
	ground_position.y = 0.0
	return ground_position
