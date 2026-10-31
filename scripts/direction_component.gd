extends Node
## Converts world-space facing into a camera-relative sprite direction.
## Handles horizontal mirroring and atlas regions for static directional sprites.
class_name DirectionComponent

var body_visual: SpriteBase3D
var current_direction := "down"

func initialize() -> void:
	if is_instance_valid(body_visual):
		body_visual.billboard = BaseMaterial3D.BILLBOARD_ENABLED

func update_direction(facing: Vector3) -> String:
	## Updates the sprite's direction and returns the direction key for animation lookup.
	if not is_instance_valid(body_visual) or not is_instance_valid(get_viewport().get_camera_3d()):
		return current_direction
	var camera := get_viewport().get_camera_3d()
	var toward_camera := camera.global_position - body_visual.global_position
	toward_camera.y = 0.0
	var direction := Vector3(facing.x, 0.0, facing.z).normalized()
	if direction.length_squared() < 0.001 or toward_camera.length_squared() < 0.001:
		return current_direction
	toward_camera = toward_camera.normalized()
	var camera_right := camera.global_basis.x
	camera_right.y = 0.0
	camera_right = camera_right.normalized()
	var candidates: Array[Vector3] = [toward_camera, -toward_camera, camera_right, -camera_right]
	var names: Array[String] = ["down", "up", "right", "left"]
	var best := 0
	var alignment := direction.dot(candidates[0])
	for index in range(1, candidates.size()):
		var candidate_alignment := direction.dot(candidates[index])
		if candidate_alignment > alignment:
			alignment = candidate_alignment
			best = index
	current_direction = names[best]
	if body_visual is Sprite3D:
		var sprite := body_visual as Sprite3D
		var depth_dot := direction.dot(toward_camera)
		var side_dot := direction.dot(camera_right)
		var source_cell := 0
		if depth_dot < -0.72:
			source_cell = 2
		elif absf(depth_dot) <= 0.72:
			source_cell = 1
		sprite.flip_h = source_cell == 1 and side_dot < 0.0
		sprite.region_rect = Rect2(source_cell * 128, 0, 128, 192)
	return current_direction
