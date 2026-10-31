extends Node
## Translates gamepad and mouse/keyboard input into movement, targeting, and skill intent.
class_name PlayerController

var camera_rig: CameraRig
var movement: MovementComponent
var targeting: TargetingComponent
var skill: SkillComponent
var combat: CombatComponent

@export_flags_3d_physics var clickable_layer_mask: int = 1

var _enabled := true
var _last_input_was_controller := false

func _unhandled_input(event: InputEvent) -> void:
	if not _enabled:
		return
	if event.is_action_pressed("move_click"):
		if not is_instance_valid(camera_rig) or not is_instance_valid(camera_rig.camera) or not is_instance_valid(targeting):
			return
		_resolve_move_click(event.position)
		_last_input_was_controller = false
	elif event is InputEventJoypadButton:
		_last_input_was_controller = true
	elif event is InputEventJoypadMotion and (event.axis == JOY_AXIS_LEFT_X or event.axis == JOY_AXIS_LEFT_Y or event.axis == JOY_AXIS_TRIGGER_LEFT or event.axis == JOY_AXIS_TRIGGER_RIGHT) and absf(event.axis_value) > 0.25:
		_last_input_was_controller = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(skill):
		skill.cancel_targeting()

func poll_input() -> void:
	if not _enabled or not is_instance_valid(movement):
		return
	var move_stick := Input.get_vector("move_stick_left", "move_stick_right", "move_stick_up", "move_stick_down")
	var world_move_direction := _camera_relative_move_direction(move_stick)
	movement.set_move_intent(world_move_direction)
	if move_stick.length_squared() > 0.001 and is_instance_valid(targeting):
		targeting.clear_target()
	if move_stick.length_squared() > 0.001:
		_last_input_was_controller = true

	if not is_instance_valid(skill):
		if Input.is_action_just_pressed("dash"):
			movement.request_dash()
		return

	var cancel_pressed := Input.is_action_just_pressed("skill_cancel")
	if skill.is_targeting():
		if cancel_pressed:
			skill.cancel_targeting()
			return
		var active_slot := skill.get_targeting_slot()
		if Input.is_action_just_released("skill_%d" % active_slot):
			skill.confirm_targeting(movement.get_facing())
		return

	if Input.is_action_just_pressed("dash"):
		movement.request_dash()
		return
	for slot_index in range(1, 7):
		var skill_action := "skill_%d" % slot_index
		if Input.is_action_just_pressed(skill_action):
			if skill.begin_targeting(slot_index) and Input.is_action_just_released(skill_action):
				skill.confirm_targeting(movement.get_facing())
			return

func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not enabled:
		if is_instance_valid(skill):
			skill.cancel_targeting()
		if is_instance_valid(movement):
			if is_instance_valid(targeting):
				targeting.clear_target()
			movement.clear_move_target()

func is_enabled() -> bool:
	return _enabled

func is_controller_input() -> bool:
	return _last_input_was_controller

func _camera_relative_move_direction(stick: Vector2) -> Vector3:
	if stick.length_squared() <= 0.001:
		return Vector3.ZERO
	var right := Vector3.RIGHT
	var forward := Vector3.FORWARD
	if is_instance_valid(camera_rig) and is_instance_valid(camera_rig.camera):
		right = camera_rig.camera.global_basis.x
		forward = camera_rig.camera.global_basis.z
	right.y = 0.0
	forward.y = 0.0
	return (right.normalized() * stick.x + forward.normalized() * stick.y).normalized()

func _resolve_move_click(screen_position: Vector2) -> void:
	var camera := camera_rig.camera
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 1000.0, clickable_layer_mask)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var excluded_rids: Array[RID] = []
	if is_instance_valid(targeting.body):
		excluded_rids.append(targeting.body.get_rid())
	query.exclude = excluded_rids
	var hit_result: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(query)
	var fallback: Variant = camera_rig.project_click_to_ground(screen_position)
	var fallback_ground_point := Vector3.ZERO
	if fallback is Vector3:
		fallback_ground_point = fallback
	elif is_instance_valid(targeting.body):
		fallback_ground_point = targeting.body.global_position
	if hit_result.is_empty():
		targeting.resolve_click(null, fallback_ground_point)
		return
	var collider := hit_result.get("collider") as Node
	var enemy := _find_group_member(collider, &"enemies") as Node3D
	if is_instance_valid(enemy) and is_instance_valid(combat):
		if is_instance_valid(skill) and skill.is_targeting():
			skill.cancel_targeting()
		targeting.set_attack_target(enemy, combat.get_attack_range())
		return
	var approachable := _find_approachable(collider)
	targeting.resolve_click({"hit": collider, "approachable": approachable}, fallback_ground_point)

func _find_approachable(node: Node) -> ApproachableComponent:
	var current := node
	while is_instance_valid(current):
		if current is ApproachableComponent:
			return current as ApproachableComponent
		for child in current.get_children():
			if child is ApproachableComponent:
				return child as ApproachableComponent
		current = current.get_parent()
	return null

func _find_group_member(node: Node, group: StringName) -> Node:
	var current := node
	while is_instance_valid(current):
		if current.is_in_group(group):
			return current
		current = current.get_parent()
	return null
