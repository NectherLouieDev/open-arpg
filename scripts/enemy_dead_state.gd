extends EnemyState
## Spawns configured loot, fades the enemy, and removes it after a delay.
class_name EnemyDeadState

var _cleanup_left := 0.0
var _initial_scale := Vector3.ONE
var _initial_tint := Color.WHITE

func enter(_previous_state: StringName) -> void:
	_cleanup_left = manager.ai.definition.death_cleanup_delay
	manager.ai.stop_moving()
	manager.ai.hide_attack_telegraph()
	manager.ai.drop_loot()
	if is_instance_valid(manager.ai.body_visual):
		_initial_scale = manager.ai.body_visual.scale
		_initial_tint = manager.ai.body_visual.modulate

func update(delta: float) -> StringName:
	_cleanup_left = maxf(0.0, _cleanup_left - delta)
	var duration := maxf(0.01, manager.ai.definition.death_cleanup_delay)
	var progress := 1.0 - _cleanup_left / duration
	if is_instance_valid(manager.ai.body_visual):
		manager.ai.body_visual.scale = _initial_scale.lerp(_initial_scale * 0.15, progress)
		var tint := _initial_tint
		tint.a = lerpf(_initial_tint.a, 0.0, progress)
		manager.ai.body_visual.modulate = tint
	if _cleanup_left <= 0.0:
		manager.ai.enemy.queue_free()
	return &""
