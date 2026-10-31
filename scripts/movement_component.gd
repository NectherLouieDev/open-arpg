extends Node
## Applies movement, facing, dash, and hit-reaction intent to a CharacterBody3D.
class_name MovementComponent

signal dash_started
signal dash_finished

@export var move_speed := 7.0
@export var click_arrival_distance := 0.3
@export var dash_speed := 18.0
@export var dash_duration := 0.18
@export var dash_cooldown := 0.75
@export var invulnerability_duration := 0.22
@export var dash_anima_cost := 25.0
@export var hit_stagger_duration := 0.12
@export var hit_knockback_speed := 5.5

var stats: StatComponent
var attributes: AttributeComponent
var body: CharacterBody3D

var velocity := Vector3.ZERO
var _move_target := Vector3.ZERO
var _has_move_target := false
var _move_intent := Vector3.ZERO
var _dash_direction := Vector3.ZERO
var _dash_time_left := 0.0
var _dash_cooldown_left := 0.0
var _invulnerability_left := 0.0
var _facing := Vector3.FORWARD
var _stagger_time_left := 0.0
var _knockback_velocity := Vector3.ZERO

func set_move_intent(world_direction: Vector3) -> void:
	_move_intent = Vector3(world_direction.x, 0.0, world_direction.z)
	if _move_intent.length_squared() > 0.001:
		_has_move_target = false
		_facing = _move_intent.normalized()

func set_facing_direction(world_direction: Vector3) -> void:
	world_direction.y = 0.0
	if world_direction.length_squared() > 0.001:
		_facing = world_direction.normalized()

func set_move_target(world_pos: Vector3) -> void:
	_move_target = world_pos
	_move_target.y = 0.0
	_has_move_target = true
	_move_intent = Vector3.ZERO
	if is_instance_valid(body):
		var direction := _move_target - body.global_position
		direction.y = 0.0
		if direction.length_squared() > 0.001:
			_facing = direction.normalized()

func clear_move_target() -> void:
	_has_move_target = false
	_move_target = body.global_position if is_instance_valid(body) else Vector3.ZERO
	_move_intent = Vector3.ZERO
	velocity = Vector3.ZERO
	if is_instance_valid(body):
		body.velocity = Vector3.ZERO

func request_dash() -> void:
	if not is_instance_valid(body) or not is_instance_valid(stats):
		return
	if _dash_cooldown_left > 0.0 or _dash_time_left > 0.0 or stats.health <= 0.0:
		return
	var dash_cost_multiplier := attributes.get_dash_cost_multiplier() if is_instance_valid(attributes) else 1.0
	if not stats.spend_anima(dash_anima_cost * dash_cost_multiplier):
		return
	_dash_direction = Vector3(velocity.x, 0.0, velocity.z).normalized() if Vector2(velocity.x, velocity.z).length_squared() > 0.04 else get_facing()
	_dash_time_left = dash_duration
	_dash_cooldown_left = dash_cooldown
	_invulnerability_left = invulnerability_duration
	dash_started.emit()
	_log_debug("Dash started · iframes %.2fs" % invulnerability_duration)

func tick(delta: float) -> void:
	if not is_instance_valid(body) or not is_instance_valid(stats):
		return
	_dash_cooldown_left = maxf(0.0, _dash_cooldown_left - delta)
	_invulnerability_left = maxf(0.0, _invulnerability_left - delta)
	if stats.health <= 0.0:
		velocity = Vector3.ZERO
		body.velocity = Vector3.ZERO
		return

	if _dash_time_left > 0.0:
		_dash_time_left = maxf(0.0, _dash_time_left - delta)
		velocity = _dash_direction * dash_speed
		body.velocity = velocity
		body.move_and_slide()
		velocity = body.velocity
		if _dash_time_left <= 0.0:
			dash_finished.emit()
		return
	if _stagger_time_left > 0.0:
		_stagger_time_left = maxf(0.0, _stagger_time_left - delta)
		_knockback_velocity = _knockback_velocity.move_toward(Vector3.ZERO, hit_knockback_speed * 5.0 * delta)
		velocity = _knockback_velocity
		body.velocity = velocity
		body.move_and_slide()
		velocity = body.velocity
		return

	var desired_velocity := Vector3.ZERO
	var move_direction := Vector3.ZERO
	if _move_intent.length_squared() > 0.001:
		move_direction = _move_intent.normalized()
		_has_move_target = false
	elif _has_move_target:
		var to_target := _move_target - body.global_position
		to_target.y = 0.0
		if to_target.length() <= click_arrival_distance:
			_has_move_target = false
		else:
			move_direction = to_target.normalized()

	if move_direction.length_squared() > 0.001:
		var speed_multiplier := attributes.get_move_speed_multiplier() if is_instance_valid(attributes) else 1.0
		desired_velocity = move_direction * move_speed * speed_multiplier
		_facing = move_direction
	velocity.x = move_toward(velocity.x, desired_velocity.x, move_speed * 10.0 * delta)
	velocity.z = move_toward(velocity.z, desired_velocity.z, move_speed * 10.0 * delta)
	velocity.y = 0.0
	body.velocity = velocity
	body.move_and_slide()
	velocity = body.velocity

func is_dashing() -> bool:
	return _dash_time_left > 0.0

func is_invulnerable() -> bool:
	return _invulnerability_left > 0.0

func get_velocity() -> Vector3:
	return velocity

func has_move_target() -> bool:
	return _has_move_target

func get_facing() -> Vector3:
	return _facing

func get_dash_cooldown_left() -> float:
	return _dash_cooldown_left

func apply_hit_reaction(source_position: Vector3, knockback_multiplier: float = 1.0, stagger_duration: float = -1.0) -> void:
	if not is_instance_valid(body):
		return
	var away := body.global_position - source_position
	away.y = 0.0
	if away.length_squared() < 0.001:
		away = -get_facing()
	_stagger_time_left = maxf(_stagger_time_left, hit_stagger_duration if stagger_duration < 0.0 else stagger_duration)
	_knockback_velocity = away.normalized() * hit_knockback_speed * maxf(0.0, knockback_multiplier)

func _log_debug(message: String) -> void:
	var hud := get_tree().get_first_node_in_group("debug_hud")
	if hud and hud.has_method("log_event"):
		hud.call("log_event", message)
