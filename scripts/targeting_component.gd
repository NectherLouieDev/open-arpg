extends Node
## Finds approachable targets and moves the owning actor into interaction range.
class_name TargetingComponent

signal target_reached(target: Node3D)
signal target_lost

@export var approach_group: StringName = &"approachables"
@export var arrival_tolerance := 0.35

var movement: MovementComponent
var body: CharacterBody3D
var current_target: Node3D = null

var _current_approachable: ApproachableComponent
var _target_active := false
var _attack_target_active := false
var _attack_range := 0.0
var _attack_stop_range := 0.0
var _last_attack_destination := Vector3.ZERO
var _has_attack_destination := false

func resolve_click(click_hit: Variant, fallback_ground_point: Vector3) -> void:
	clear_target()
	if not is_instance_valid(movement) or not is_instance_valid(body):
		return
	var approachable: ApproachableComponent
	var hit_node: Node
	if click_hit is Dictionary:
		hit_node = click_hit.get("hit") as Node
		approachable = click_hit.get("approachable") as ApproachableComponent
		if not is_instance_valid(approachable):
			approachable = _find_group_approachable(hit_node)
	if is_instance_valid(approachable):
		var target_node := approachable.get_parent() as Node3D
		if is_instance_valid(target_node):
			current_target = target_node
			_current_approachable = approachable
			_target_active = true
			movement.set_move_target(approachable.get_approach_position(body.global_position))
			return
	movement.set_move_target(fallback_ground_point)

func set_attack_target(target: Node3D, attack_range: float) -> void:
	clear_target()
	if not is_instance_valid(target) or not target.is_in_group("enemies"):
		return
	if not is_instance_valid(movement) or not is_instance_valid(body):
		return
	current_target = target
	_target_active = true
	_attack_target_active = true
	_attack_range = maxf(0.1, attack_range)
	_attack_stop_range = maxf(0.1, _attack_range - 0.3)
	_has_attack_destination = false
	_update_attack_approach()

func clear_target() -> void:
	if not _target_active:
		return
	_target_active = false
	_attack_target_active = false
	_has_attack_destination = false
	current_target = null
	_current_approachable = null
	target_lost.emit()

func is_attack_approaching() -> bool:
	return _attack_target_active

func _physics_process(_delta: float) -> void:
	if not _target_active:
		return
	if _attack_target_active:
		_update_attack_approach()
		return
	if not is_instance_valid(current_target) or not is_instance_valid(_current_approachable):
		_lose_target_and_stop()
		return
	if not is_instance_valid(movement) or not is_instance_valid(body):
		_lose_target_and_stop()
		return

	var to_target := current_target.global_position - body.global_position
	to_target.y = 0.0
	var arrival_distance := _current_approachable.get_interaction_radius() + _current_approachable.approach_offset + arrival_tolerance
	if to_target.length() <= arrival_distance and not movement.has_move_target():
		var reached_target := current_target
		movement.set_facing_direction(to_target)
		_target_active = false
		current_target = null
		_current_approachable = null
		target_reached.emit(reached_target)

func _update_attack_approach() -> void:
	if not is_instance_valid(current_target) or not current_target.is_inside_tree() or not current_target.is_in_group("enemies"):
		_lose_target_and_stop()
		return
	if not is_instance_valid(movement) or not is_instance_valid(body):
		_lose_target_and_stop()
		return
	var target_stats := current_target.get_node_or_null("StatComponent") as StatComponent
	if is_instance_valid(target_stats) and target_stats.health <= 0.0:
		_lose_target_and_stop()
		return
	var to_target := current_target.global_position - body.global_position
	to_target.y = 0.0
	var distance := to_target.length()
	if distance <= _attack_range:
		if movement.has_move_target():
			movement.clear_move_target()
		movement.set_facing_direction(to_target)
		_has_attack_destination = false
		return
	if distance <= 0.001:
		movement.clear_move_target()
		return
	var destination := current_target.global_position - to_target.normalized() * _attack_stop_range
	destination.y = body.global_position.y
	if not _has_attack_destination or _last_attack_destination.distance_squared_to(destination) > 0.04:
		movement.set_move_target(destination)
		_last_attack_destination = destination
		_has_attack_destination = true

func _lose_target_and_stop() -> void:
	if is_instance_valid(movement):
		movement.clear_move_target()
	clear_target()

func _find_group_approachable(hit_node: Node) -> ApproachableComponent:
	var ancestor := hit_node
	while is_instance_valid(ancestor):
		for candidate in get_tree().get_nodes_in_group(approach_group):
			if not is_instance_valid(candidate) or not candidate is ApproachableComponent:
				continue
			var approachable := candidate as ApproachableComponent
			if approachable.get_parent() == ancestor:
				return approachable
		ancestor = ancestor.get_parent()
	return null
